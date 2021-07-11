variable "namespace_name" {}
variable "storage_class_name" {}
variable "release_name" {}
locals {
  namespace_name     = var.namespace_name
  storage_class_name = var.storage_class_name
  release_name       = var.release_name
}

variable "elasticsearch_replicas_count" {
  type = number
}
variable "elasticsearch_service_name" {}
variable "elasticsearch_service_port" {}
variable "elasticsearch_image_url" {}
locals {
  elasticsearch_service_name   = var.elasticsearch_service_name
  elasticsearch_service_port   = var.elasticsearch_service_port
  elasticsearch_replicas_count = max(3, var.elasticsearch_replicas_count)
  elasticsearch_image_url      = var.elasticsearch_image_url
}

variable "kibana_service_name" {}
variable "kibana_service_port" { type = number }
variable "kibana_image_url" {}
locals {
  kibana_service_name = var.kibana_service_name
  kibana_service_port = var.kibana_service_port
  kibana_image_url    = var.kibana_image_url
}

variable "logstash_service_name" {}
variable "logstash_service_port" { type = number }
variable "logstash_image_url" {}
locals {
  logstash_service_name = var.logstash_service_name
  logstash_service_port = var.logstash_service_port
  logstash_image_url    = var.logstash_image_url
}

resource "helm_release" "elk" {
  name = local.release_name

  chart = abspath("${path.module}/elk")

  namespace = local.namespace_name

  values = [
    yamlencode({
      elasticsearch = {
        servicePort      = local.elasticsearch_service_port
        serviceName      = local.elasticsearch_service_name
        replicasCount    = local.elasticsearch_replicas_count
        imageUrl         = local.elasticsearch_image_url
        storageClassName = local.storage_class_name
      }

      kibana = {
        serviceName      = local.kibana_service_name
        servicePort      = local.kibana_service_port
        imageUrl         = local.kibana_image_url
        storageClassName = local.storage_class_name
      }

      logstash = {
        serviceName      = local.logstash_service_name
        servicePort      = local.logstash_service_port
        imageUrl         = local.logstash_image_url
        storageClassName = local.storage_class_name
      }
    })
  ]
}