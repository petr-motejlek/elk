variable "ca_private_key_pem" {}
variable "ca_private_key_algorithm" {}
variable "ca_public_key_pem" {}
variable "storage_class" {}

resource "kubernetes_namespace" "registry" {
  metadata {
    name = "registry"
  }
}

resource "tls_private_key" "registry" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "registry" {
  key_algorithm   = tls_private_key.registry.algorithm
  private_key_pem = tls_private_key.registry.private_key_pem

  subject {
    common_name = "registry.registry.cls.local"
  }

  dns_names = [
  "registry.registry.cls.local"]
}

resource "tls_locally_signed_cert" "registry" {
  cert_request_pem   = tls_cert_request.registry.cert_request_pem
  ca_key_algorithm   = var.ca_private_key_algorithm
  ca_private_key_pem = var.ca_private_key_pem
  ca_cert_pem        = var.ca_public_key_pem

  validity_period_hours = 48

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

resource "kubernetes_service" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.registry.metadata[0].name
  }
  spec {
    selector = {
      app = "registry"
    }
    type = "LoadBalancer"
    port {
      port        = 443
      target_port = 5000
    }
  }
}

