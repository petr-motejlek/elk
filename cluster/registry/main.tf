variable "namespace_name" {}
locals {
  namespace_name = var.namespace_name
}

resource "kubernetes_namespace" "registry" {
  metadata {
    name = local.namespace_name
  }
}

variable "storage_class_name" {}
locals {
  storage_class_name = var.storage_class_name
}

variable "service_name" {}
variable "service_port" {
  type = number
}
locals {
  service_name = var.service_name
  service_port = var.service_port
}

variable "release_name" {}
locals {
  release_name = var.release_name
}

locals {
  image_url = "registry:2"
}

variable "tls_key_pem" {}
variable "tls_crt_pem" {}
locals {
  tls_key_pem = var.tls_key_pem
  tls_crt_pem = var.tls_crt_pem
}

resource "helm_release" "registry" {
  name = local.release_name

  chart = abspath("${path.module}/registry-chart")

  namespace = local.namespace_name

  values = [
    yamlencode({
      serviceName      = local.service_name
      servicePort      = local.service_port
      imageUrl         = local.image_url
      storageClassName = local.storage_class_name
      tlsKeyPem        = local.tls_key_pem
      tlsCrtPem        = local.tls_crt_pem
    })
  ]
}