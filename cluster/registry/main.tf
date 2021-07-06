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

variable "service-name" {}
variable "service-port" {
  type = number
}
locals {
  service-name = var.service-name
  service-port = var.service-port
}

variable "release-name" {}
locals {
  release-name = var.release-name
}

locals {
  image-url = "registry:2"
}

resource "helm_release" "registry" {
  name = local.release-name

  chart = abspath("${path.module}/registry-chart")

  namespace = local.namespace-name

  values = [
    yamlencode({
      serviceName      = local.service-name
      servicePort      = local.service-port
      imageUrl         = local.image-url
      storageClassName = local.storage_class-name
      tlsKeyPem        = tls_private_key.registry.private_key_pem
      tlsCrtPem        = tls_locally_signed_cert.registry.cert_pem
    })
  ]
}