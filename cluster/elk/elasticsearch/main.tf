variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

variable "image-registry-url" {}
variable "image-name" {}
locals {
  image-registry-url = var.image-registry-url
  image-name         = var.image-name
}

variable "storage_class-name" {}
locals {
  storage_class-name = var.storage_class-name
}

locals {
  docker-context-path     = abspath("${path.module}/docker")
  docker-context-zip-path = "${local.docker-context-path}.zip"
}

data "archive_file" "context" {
  type        = "zip"
  output_path = local.docker-context-zip-path
  source_dir  = local.docker-context-path
}

resource "docker_image" "elasticsearch" {
  name = "${local.image-registry-url}/${local.image-name}:${data.archive_file.context.output_md5}"

  build {
    path = local.docker-context-path
    label = {
      md5 = data.archive_file.context.output_md5
    }
  }
}

resource "docker_registry_image" "elasticsearch" {
  name = docker_image.elasticsearch.name

  keep_remotely = true
}

variable "replicas-count" {
  type = number
}
locals {
  replicas-count = max(3, var.replicas-count)
}

resource "kubernetes_service" "elasticsearch-headless" {
  metadata {
    name = "elasticsearch-headless"
    labels = {
      app = "elasticsearch"
    }
    namespace = local.namespace-name
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
    namespace = local.namespace-name
  }
  spec {
    selector {
      match_labels = {
        app = "elasticsearch"
      }
    }
    service_name = kubernetes_service.elasticsearch-headless.metadata[0].name
    replicas     = local.replicas-count
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
            value = kubernetes_service.elasticsearch-headless.metadata[0].name
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
        storage_class_name = local.storage_class-name
        resources {
          requests = {
            storage = "8Gi"
          }
        }
      }
    }
  }
}

variable "service-port" {
  type = number
}
variable "service-name" {}
locals {
  service-port = var.service-port
  service-name = var.service-name
}

resource "kubernetes_service" "elasticsearch" {
  metadata {
    name = local.service-name
    labels = {

      app = "elasticsearch"
    }
    namespace = local.namespace-name
  }
  spec {
    port {
      port        = local.service-port
      target_port = "9200"
      name        = "http"
    }
    type = "ClusterIP"
    selector = {
      app = "elasticsearch"
    }
  }
}

