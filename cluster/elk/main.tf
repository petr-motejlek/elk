variable "namespace_name" {}
locals {
  namespace_name = var.namespace_name
}

resource "kubernetes_namespace" "elk" {
  metadata {
    name = local.namespace_name
  }
}

variable "storage_class_name" {}
locals {
  storage_class_name = var.storage_class_name
}

variable "elasticsearch_image_registry_url" {}
variable "elasticsearch_image_name" {}
variable "elasticsearch_service_port" {
  type = number
}
variable "elasticsearch_service_name" {}
variable "elasticsearch_replicas_count" {
  type = number
}
variable "elasticsearch_release_name" {}
locals {
  elasticsearch_image_registry_url = var.elasticsearch_image_registry_url
  elasticsearch_image_name         = var.elasticsearch_image_name
  elasticsearch_service_port       = var.elasticsearch_service_port
  elasticsearch_service_name       = var.elasticsearch_service_name
  elasticsearch_replicas_count     = var.elasticsearch_replicas_count
  elasticsearch_release_name       = var.elasticsearch_release_name
}

module "elasticsearch_image" {
  source = "./elasticsearch-image"

  image_registry_url = local.elasticsearch_image_registry_url
  image_name         = local.elasticsearch_image_name
}

locals {
  elasticsearch_image_url = module.elasticsearch_image.image_url
}

module "elasticsearch" {
  source = "./elasticsearch"

  namespace_name     = kubernetes_namespace.elk.metadata.0.name
  storage_class_name = local.storage_class_name
  service_name       = local.elasticsearch_service_name
  service_port       = local.elasticsearch_service_port
  replicas_count     = local.elasticsearch_replicas_count
  release_name       = local.elasticsearch_release_name
  image_url          = local.elasticsearch_image_url
}

variable "logstash_image_registry_url" {}
variable "logstash_image_name" {}
variable "logstash_service_name" {}
variable "logstash_service_port" {
  type = number
}
variable "logstash_release_name" {}
locals {
  logstash_image_registry_url = var.logstash_image_registry_url
  logstash_image_name         = var.logstash_image_name
  logstash_service_name       = var.logstash_service_name
  logstash_service_port       = var.logstash_service_port
  logstash_release_name       = var.logstash_release_name
}

module "logstash" {
  depends_on = [module.elasticsearch]

  source = "./logstash"

  namespace_name     = kubernetes_namespace.elk.metadata.0.name
  storage_class_name = local.storage_class_name
  image_registry_url = local.logstash_image_registry_url
  image_name         = local.logstash_image_name
  service_name       = local.logstash_service_name
  service_port       = local.logstash_service_port
  release_name       = local.logstash_release_name
}

variable "kibana_image_registry_url" {}
variable "kibana_image_name" {}
variable "kibana_service_name" {}
variable "kibana_service_port" {
  type = number
}
variable "kibana_release_name" {}
locals {
  kibana_image_registry_url = var.kibana_image_registry_url
  kibana_image_name         = var.kibana_image_name
  kibana_service_name       = var.kibana_service_name
  kibana_service_port       = var.kibana_service_port
  kibana_release_name       = var.kibana_release_name
}

module "kibana_image" {
  source = "./kibana-image"

  image_registry_url = local.kibana_image_registry_url
  image_name         = local.kibana_image_name
}

locals {
  kibana_image_url = module.kibana_image.image_url
}

module "kibana" {
  depends_on = [module.elasticsearch]

  source = "./kibana"

  namespace_name     = kubernetes_namespace.elk.metadata.0.name
  storage_class_name = local.storage_class_name
  service_name       = local.kibana_service_name
  service_port       = local.kibana_service_port
  release_name       = local.kibana_release_name
  image_url          = local.kibana_image_url
}