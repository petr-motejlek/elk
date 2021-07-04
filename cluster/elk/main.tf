resource "kubernetes_namespace" "elk" {
  metadata {
    name = "elk"
  }
}

variable "storage_class" {}

variable "elasticsearch-image-registry-url" {}
variable "elasticsearch-image-name" {}
variable "elasticsearch-service-port" {
  type = number
}
variable "elasticsearch-service-name" {}
variable "elasticsearch-replicas-count" {
  type = number
}
locals {
  elasticsearch-image-registry-url = var.elasticsearch-image-registry-url
  elasticsearch-image-name         = var.elasticsearch-image-name
  elasticsearch-service-port       = var.elasticsearch-service-port
  elasticsearch-service-name       = var.elasticsearch-service-name
  elasticsearch-replicas-count     = var.elasticsearch-replicas-count
}

module "elasticsearch" {
  source = "./elasticsearch"

  namespace-name     = kubernetes_namespace.elk.metadata.0.name
  storage_class-name = var.storage_class
  image-registry-url = local.elasticsearch-image-registry-url
  image-name         = local.elasticsearch-image-name
  service-name       = local.elasticsearch-service-name
  service-port       = local.elasticsearch-service-port
  replicas-count     = local.elasticsearch-replicas-count
}

variable "logstash-image-registry-url" {}
variable "logstash-image-name" {}
variable "logstash-service-name" {}
variable "logstash-service-port" {
  type = number
}
locals {
  logstash-image-registry-url = var.logstash-image-registry-url
  logstash-image-name         = var.logstash-image-name
  logstash-service-name       = var.logstash-service-name
  logstash-service-port       = var.logstash-service-port
}

module "logstash" {
  depends_on = [module.elasticsearch]

  source = "./logstash"

  namespace-name     = kubernetes_namespace.elk.metadata.0.name
  storage_class-name = var.storage_class
  image-registry-url = local.logstash-image-registry-url
  image-name         = local.logstash-image-name
  service-name       = local.logstash-service-name
  service-port       = local.logstash-service-port
}

variable "kibana-image-registry-url" {}
variable "kibana-image-name" {}
variable "kibana-service-name" {}
variable "kibana-service-port" {
  type = number
}
locals {
  kibana-image-registry-url = var.kibana-image-registry-url
  kibana-image-name         = var.kibana-image-name
  kibana-service-name       = var.kibana-service-name
  kibana-service-port       = var.kibana-service-port
}

module "kibana" {
  depends_on = [module.elasticsearch]

  source = "./kibana"

  namespace-name     = kubernetes_namespace.elk.metadata.0.name
  storage_class-name = var.storage_class
  image-registry-url = local.kibana-image-registry-url
  image-name         = local.kibana-image-name
  service-name       = local.kibana-service-name
  service-port       = local.kibana-service-port
}
