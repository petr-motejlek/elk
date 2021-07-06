variable "namespace_name" {}
locals {
  namespace_name = var.namespace_name
}

variable "image_registry_url" {}
variable "image_name" {}
locals {
  image_registry_url = var.image_registry_url
  image_name         = var.image_name
}

variable "storage_class_name" {}
locals {
  storage_class_name = var.storage_class_name
}

locals {
  docker_context_path     = abspath("${path.module}/docker")
  docker_context_zip_path = "${local.docker_context_path}.zip"
}

data "archive_file" "context" {
  type        = "zip"
  output_path = local.docker_context_zip_path
  source_dir  = local.docker_context_path
}

resource "docker_image" "elasticsearch" {
  name = "${local.image_registry_url}/${local.image_name}:${data.archive_file.context.output_md5}"

  build {
    path = local.docker_context_path
    label = {
      md5 = data.archive_file.context.output_md5
    }
  }
}

resource "docker_registry_image" "elasticsearch" {
  name = docker_image.elasticsearch.name

  keep_remotely = true
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

locals {
  image_url = "${docker_registry_image.elasticsearch.name}@${docker_registry_image.elasticsearch.sha256_digest}"
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