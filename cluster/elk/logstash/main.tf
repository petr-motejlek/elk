variable "namespace" {}
variable "storage_class" {}

data "archive_file" "context" {
  type        = "zip"
  output_path = "${path.module}/docker.zip"
  source_dir  = "${path.module}/docker"
}

resource "docker_image" "logstash" {
  name = "registry.registry.cls.local/logstash:${data.archive_file.context.output_md5}"

  build {
    path = "${path.module}/docker"
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
    namespace = var.namespace
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
    namespace = var.namespace
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

resource "kubernetes_service" "logstash" {
  metadata {
    name = "logstash"
    labels = {

      app = "logstash"
    }
    namespace = var.namespace
  }
  spec {
    port {
      port = "5042"
      name = "http"
    }
    type = "LoadBalancer"
    selector = {
      app = "logstash"
    }
  }
}

