variable "namespace_name" {}
locals {
  namespace_name = var.namespace_name
}

variable "storage_class_name" {}
locals {
  storage_class_name = var.storage_class_name
}

variable "replicas_count" {
  type = number
}
locals {
  replicas_count = max(3, var.replicas_count)
}

variable "service_name" {}
variable "service_port" {}
locals {
  service_name = var.service_name
  service_port = var.service_port
}

variable "release_name" {}
locals {
  release_name = var.release_name
}

variable "image_url" {}
locals {
  image_url = var.image_url
}

resource "helm_release" "elasticsearch" {
  name = local.release_name

  chart = abspath("${path.module}/elasticsearch-chart")

  namespace = local.namespace_name

  values = [
    yamlencode({
      serviceName      = local.service_name
      servicePort      = local.service_port
      replicasCount    = local.replicas_count
      imageUrl         = local.image_url
      storageClassName = local.storage_class_name
    })
  ]
}