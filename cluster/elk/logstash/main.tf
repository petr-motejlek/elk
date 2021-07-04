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

resource "docker_image" "logstash" {
  name = "${local.image-registry-url}/${local.image-name}:${data.archive_file.context.output_md5}"

  build {
    path = local.docker-context-path
    label = {
      md5 = data.archive_file.context.output_md5
    }
  }
}

resource "docker_registry_image" "logstash" {
  name = docker_image.logstash.name

  keep_remotely = true
}

resource "kubernetes_service" "logstash-headless" {
  metadata {
    name = "logstash-headless"
    labels = {
      app = "logstash"
    }
    namespace = local.namespace-name
  }
  spec {
    port {
      port = "9600"
      name = "http"
    }
    cluster_ip = "None"
    selector = {
      app = "logstash"
    }
  }
}

resource "kubernetes_stateful_set" "logstash" {
  metadata {
    name      = "logstash"
    namespace = local.namespace-name
  }
  spec {
    selector {
      match_labels = {
        app = "logstash"
      }
    }
    service_name = kubernetes_service.logstash-headless.metadata[0].name
    replicas     = 1
    template {
      metadata {
        labels = {
          app = "logstash"
        }
      }
      spec {
        security_context {
          fs_group     = 999
          run_as_user  = 999
          run_as_group = 999
        }
        container {
          name  = "logstash"
          image = "${docker_registry_image.logstash.name}@${docker_registry_image.logstash.sha256_digest}"
          port {
            container_port = 9600
            name           = "http"
          }
          port {
            container_port = 5042
            name           = "pipeline"
          }
          volume_mount {
            name       = "logstash-data"
            mount_path = "/var/lib/logstash"
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
        name = "logstash-data"
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

resource "kubernetes_service" "logstash" {
  metadata {
    name = local.service-name
    labels = {

      app = "logstash"
    }
    namespace = local.namespace-name
  }
  spec {
    port {
      port        = local.service-port
      target_port = "5042"
      name        = "http"
    }
    type = "LoadBalancer"
    selector = {
      app = "logstash"
    }
  }
}

