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

variable "service-name" {}
variable "service-port" { type = number }
locals {
  service-name = var.service-name
  service-port = var.service-port
}

variable "release-name" {}
locals {
  release-name = var.release-name
}

locals {
  image-url = "${docker_registry_image.logstash.name}@${docker_registry_image.logstash.sha256_digest}"
}

resource "helm_release" "logstash" {
  name = local.release-name

  chart = abspath("${path.module}/logstash-chart")

  namespace = local.namespace-name

  values = [
    yamlencode({
      serviceName      = local.service-name
      servicePort      = local.service-port
      imageUrl         = local.image-url
      storageClassName = local.storage_class-name
    })
  ]
}