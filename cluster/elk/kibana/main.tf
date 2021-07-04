variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

variable "storage_class-name" {}
locals {
  storage_class-name = var.storage_class-name
}

variable "image-registry-url" {}
variable "image-name" {}
locals {
  image-registry-url = var.image-registry-url
  image-name         = var.image-name
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

resource "docker_image" "kibana" {
  name = "${local.image-registry-url}/${local.image-name}:${data.archive_file.context.output_md5}"

  build {
    path = local.docker-context-path
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
    namespace = local.namespace-name
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
    namespace = local.namespace-name
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

variable "service-name" {}
variable "service-port" { type = number }
locals {
  service-name = var.service-name
  service-port = var.service-port
}

resource "kubernetes_service" "kibana" {
  metadata {
    name = local.service-name
    labels = {

      app = "kibana"
    }
    namespace = local.namespace-name
  }
  spec {
    port {
      port        = local.service-port
      target_port = "5601"
      name        = "http"
    }
    type = "LoadBalancer"
    selector = {
      app = "kibana"
    }
  }
}

