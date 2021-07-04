variable "ca-private_key-pem" {}
variable "ca-private_key-algorithm" {}
variable "ca-public_key-pem" {}
locals {
  ca-private_key-pem       = var.ca-private_key-pem
  ca-private_key-algorithm = var.ca-private_key-algorithm
  ca-public_key-pem        = var.ca-public_key-pem
}

variable "storage_class-name" {}
locals {
  storage_class-name = var.storage_class-name
}

variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

variable "cert-valid-hours" {
  type = number
}
locals {
  cert-valid-hours = var.cert-valid-hours
}

resource "kubernetes_namespace" "registry" {
  metadata {
    name = local.namespace-name
  }
}

resource "tls_private_key" "registry" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

variable "common_name" {}
locals {
  common_name = var.common_name
}

resource "tls_cert_request" "registry" {
  key_algorithm   = tls_private_key.registry.algorithm
  private_key_pem = tls_private_key.registry.private_key_pem

  subject {
    common_name = local.common_name
  }

  dns_names = [
  local.common_name]
}

resource "tls_locally_signed_cert" "registry" {
  cert_request_pem   = tls_cert_request.registry.cert_request_pem
  ca_key_algorithm   = local.ca-private_key-algorithm
  ca_private_key_pem = local.ca-private_key-pem
  ca_cert_pem        = local.ca-public_key-pem

  validity_period_hours = local.cert-valid-hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "kubernetes_secret" "registry-tls" {
  metadata {
    name      = "registry-tls"
    namespace = kubernetes_namespace.registry.metadata[0].name
  }
  data = {
    key = tls_private_key.registry.private_key_pem
    crt = tls_locally_signed_cert.registry.cert_pem
  }
}

resource "kubernetes_stateful_set" "registry" {
  timeouts {
    create = "30m"
  }

  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry"
    }
  }
  spec {
    service_name = kubernetes_service.registry.metadata.0.name
    replicas     = 1
    selector {
      match_labels = kubernetes_service.registry.spec.0.selector
    }

    template {
      metadata {
        labels = kubernetes_service.registry.spec.0.selector
      }
      spec {
        container {
          image = "registry:2"
          name  = "registry"
          env {
            name  = "REGISTRY_HTTP_TLS_CERTIFICATE"
            value = "/run/secrets/registry-tls/crt"
          }
          env {
            name  = "REGISTRY_HTTP_TLS_KEY"
            value = "/run/secrets/registry-tls/key"
          }
          env {
            name  = "REGISTRY_TLS_HASH"
            value = md5(yamlencode(kubernetes_secret.registry-tls.data))
          }
          volume_mount {
            name       = "registry-vol"
            mount_path = "/var/lib/registry"
          }
          volume_mount {
            name       = "registry-tls"
            mount_path = "/run/secrets/registry-tls"
          }
          resources {
            requests = {
              cpu = "0.25"
            }
            limits = {
              cpu = "0.25"
            }
          }
        }
        volume {
          name = "registry-tls"
          secret {
            default_mode = "0600"
            secret_name  = "registry-tls"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "registry-vol"
      }
      spec {
        access_modes = [
        "ReadWriteOnce"]
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
variable "service-port" {
  type = number
}
locals {
  service-name = var.service-name
  service-port = var.service-port
}

resource "kubernetes_service" "registry" {
  metadata {
    name      = local.service-name
    namespace = kubernetes_namespace.registry.metadata[0].name
  }
  spec {
    selector = {
      app = "registry"
    }
    type = "LoadBalancer"
    port {
      port        = local.service-port
      target_port = 5000
    }
  }
}

