variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

resource "kubernetes_namespace" "registry" {
  metadata {
    name = local.namespace-name
  }
}

variable "storage_class-name" {}
locals {
  storage_class-name = var.storage_class-name
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

variable "tls_key_pem" {}
variable "tls_crt_pem" {}
locals {
  tls_key_pem = var.tls_key_pem
  tls_crt_pem = var.tls_crt_pem
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
      tlsKeyPem        = local.tls_key_pem
      tlsCrtPem        = local.tls_crt_pem
    })
  ]
}