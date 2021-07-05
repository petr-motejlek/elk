variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

variable "image-registry-url" {}
variable "image-name" {}
locals {
  image-registry-url = var.image-registry-url
  image-name         = var.image-name
}

variable "storage_class-name" {}
locals {
  storage_class-name = var.storage_class-name
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

resource "docker_image" "elasticsearch" {
  name = "${local.image-registry-url}/${local.image-name}:${data.archive_file.context.output_md5}"

  build {
    path = local.docker-context-path
    label = {
      md5 = data.archive_file.context.output_md5
    }
  }
}

resource "docker_registry_image" "elasticsearch" {
  name = docker_image.elasticsearch.name

  keep_remotely = true
}

variable "replicas-count" {
  type = number
}
locals {
  replicas-count = max(3, var.replicas-count)
}

variable "service-name" {}
variable "service-port" {}
locals {
  service-name = var.service-name
  service-port = var.service-port
}

variable "release-name" {}
locals {
  release-name = var.release-name
}

locals {
  image-url = "${docker_registry_image.elasticsearch.name}@${docker_registry_image.elasticsearch.sha256_digest}"
}

resource "helm_release" "elasticsearch" {
  name = local.release-name

  chart = abspath("${path.module}/elasticsearch-chart")

  namespace = local.namespace-name

  values = [
    yamlencode({
      serviceName      = local.service-name
      servicePort      = local.service-port
      replicasCount    = local.replicas-count
      imageUrl         = local.image-url
      storageClassName = local.storage_class-name
    })
  ]
}