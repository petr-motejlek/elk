variable "namespace" {}
variable "storage_class" {}

data "archive_file" "context" {
  type        = "zip"
  output_path = "${path.module}/docker.zip"
  source_dir  = "${path.module}/docker"
}

resource "docker_image" "elasticsearch" {
  name = "registry.registry.cls.local/elasticsearch:${data.archive_file.context.output_md5}"

  build {
    path = "${path.module}/docker"
    label = {
      md5 = data.archive_file.context.output_md5
    }
  }
}

resource "docker_registry_image" "elasticsearch" {
  name = docker_image.elasticsearch.name

  keep_remotely = true
}

resource "kubernetes_service" "elasticsearch-headless" {
  metadata {
    name = "elasticsearch-headless"
    labels = {
      app = "elasticsearch"
    }
    namespace = var.namespace
    annotations = {
      "service.alpha.kubernetes.io/tolerate-unready-endpoints" : "true"
    }
  }
  spec {
    port {
      port = "9200"
      name = "http"
    }
    port {
      port = "9300"
      name = "transport"
    }
    cluster_ip                  = "None"
    publish_not_ready_addresses = true
    selector = {
      app = "elasticsearch"
    }
  }
}

resource "kubernetes_stateful_set" "elasticsearch" {
  metadata {
    name      = "elasticsearch"
    namespace = var.namespace
  }
  spec {
    selector {
      match_labels = {
        app = "elasticsearch"
      }
    }
    service_name = kubernetes_service.elasticsearch-headless.metadata[0].name
    replicas     = 3
    template {
      metadata {
        labels = {
          app = "elasticsearch"
        }
      }
      spec {
        security_context {
          fs_group     = 106
          run_as_user  = 105
          run_as_group = 106
        }
        container {
          name  = "elasticsearch"
          image = "${docker_registry_image.elasticsearch.name}@${docker_registry_image.elasticsearch.sha256_digest}"
          port {
            container_port = 9200
            name           = "http"
          }
          port {
            container_port = 9300
            name           = "transport"
          }
          volume_mount {
            name       = "elasticsearch-data"
            mount_path = "/var/lib/elasticsearch"
          }
          env {
            name = "NODE__NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name  = "NETWORK__HOST"
            value = "0.0.0.0"
          }
          env {
            name  = "DISCOVERY__SEED_HOSTS"
            value = "elasticsearch-headless"
          }
          env {
            name  = "CLUSTER__INITIAL_MASTER_NODES"
            value = "elasticsearch-0,elasticsearch-1,elasticsearch-2"
          }
          resources {
            requests = {
              memory = "2Gi"
            }
            limits = {
              memory = "2Gi"
            }
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "elasticsearch-data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
        resources {
          requests = {
            storage = "8Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "elasticsearch" {
  metadata {
    name = "elasticsearch"
    labels = {

      app = "elasticsearch"
    }
    namespace = var.namespace
  }
  spec {
    port {
      port = "9200"
      name = "http"
    }
    type = "ClusterIP"
    selector = {
      app = "elasticsearch"
    }
  }
}

