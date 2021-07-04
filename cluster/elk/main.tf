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

module "logstash" {
  depends_on = [module.elasticsearch]

  source = "./logstash"

  namespace     = kubernetes_namespace.elk.metadata.0.name
  storage_class = var.storage_class
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
