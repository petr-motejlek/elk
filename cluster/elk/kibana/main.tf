variable "namespace" {}
variable "storage_class" {}

data "archive_file" "context" {
  type        = "zip"
  output_path = "${path.module}/docker.zip"
  source_dir  = "${path.module}/docker"
}

resource "docker_image" "kibana" {
  name = "registry.registry.cls.local/kibana:${data.archive_file.context.output_md5}"

  build {
    path = "${path.module}/docker"
    label = {
      md5 = data.archive_file.context.output_md5
    }
  }
}

resource "docker_registry_image" "kibana" {
  name = docker_image.kibana.name

  keep_remotely = true
}

resource "kubernetes_service" "kibana-headless" {
  metadata {
    name = "kibana-headless"
    labels = {
      app = "kibana"
    }
    namespace = var.namespace
  }
  spec {
    port {
      port = "5601"
      name = "http"
    }
    cluster_ip                  = "None"
    publish_not_ready_addresses = true
    selector = {
      app = "kibana"
    }
  }
}

resource "kubernetes_stateful_set" "kibana" {
  metadata {
    name      = "kibana"
    namespace = var.namespace
  }
  spec {
    selector {
      match_labels = {
        app = "kibana"
      }
    }
    service_name = kubernetes_service.kibana-headless.metadata[0].name
    replicas     = 1
    template {
      metadata {
        labels = {
          app = "kibana"
        }
      }
      spec {
        security_context {
          fs_group     = 106
          run_as_user  = 105
          run_as_group = 106
        }
        container {
          name  = "kibana"
          image = "${docker_registry_image.kibana.name}@${docker_registry_image.kibana.sha256_digest}"
          port {
            container_port = 5601
            name           = "http"
          }
          volume_mount {
            name       = "kibana-data"
            mount_path = "/var/lib/kibana"
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
        name = "kibana-data"
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

resource "kubernetes_service" "kibana" {
  metadata {
    name = "kibana"
    labels = {

      app = "kibana"
    }
    namespace = var.namespace
  }
  spec {
    port {
      port = "5601"
      name = "http"
    }
    type = "LoadBalancer"
    selector = {
      app = "kibana"
    }
  }
}

