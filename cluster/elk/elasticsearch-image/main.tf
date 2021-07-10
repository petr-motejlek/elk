variable "image_registry_url" {}
variable "image_name" {}
locals {
  image_registry_url = var.image_registry_url
  image_name         = var.image_name
}

locals {
  docker_context_path     = abspath("${path.module}/docker")
  docker_context_zip_path = "${path.root}/.terraform/${path.module}/docker.zip"
}

data "archive_file" "context" {
  type        = "zip"
  output_path = local.docker_context_zip_path
  source_dir  = local.docker_context_path
}

resource "docker_image" "elasticsearch" {
  name = "${local.image_registry_url}/${local.image_name}"

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

locals {
  image_url = "${docker_registry_image.elasticsearch.name}@${docker_registry_image.elasticsearch.sha256_digest}"
}

output "image_url" {
  value = local.image_url
}