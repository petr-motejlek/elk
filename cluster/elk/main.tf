variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

resource "kubernetes_namespace" "elk" {
  metadata {
    name = local.namespace-name
  }
}

variable "storage_class-name" {}
locals {
  storage_class-name = var.storage_class-name
}

variable "elasticsearch-image-registry-url" {}
variable "elasticsearch-image-name" {}
variable "elasticsearch-service-port" {
  type = number
}
variable "elasticsearch-service-name" {}
variable "elasticsearch-replicas-count" {
  type = number
}
variable "elasticsearch-release-name" {}
locals {
  elasticsearch-image-registry-url = var.elasticsearch-image-registry-url
  elasticsearch-image-name         = var.elasticsearch-image-name
  elasticsearch-service-port       = var.elasticsearch-service-port
  elasticsearch-service-name       = var.elasticsearch-service-name
  elasticsearch-replicas-count     = var.elasticsearch-replicas-count
  elasticsearch-release-name       = var.elasticsearch-release-name
}

module "elasticsearch" {
  source = "./elasticsearch"

  namespace-name     = kubernetes_namespace.elk.metadata.0.name
  storage_class-name = local.storage_class-name
  image-registry-url = local.elasticsearch-image-registry-url
  image-name         = local.elasticsearch-image-name
  service-name       = local.elasticsearch-service-name
  service-port       = local.elasticsearch-service-port
  replicas-count     = local.elasticsearch-replicas-count
  release-name       = local.elasticsearch-release-name
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
  storage_class-name = local.storage_class-name
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
variable "kibana-release-name" {}
locals {
  kibana-image-registry-url = var.kibana-image-registry-url
  kibana-image-name         = var.kibana-image-name
  kibana-service-name       = var.kibana-service-name
  kibana-service-port       = var.kibana-service-port
  kibana-release-name       = var.kibana-release-name
}

module "kibana" {
  depends_on = [module.elasticsearch]

  source = "./kibana"

  namespace-name     = kubernetes_namespace.elk.metadata.0.name
  storage_class-name = local.storage_class-name
  image-registry-url = local.kibana-image-registry-url
  image-name         = local.kibana-image-name
  service-name       = local.kibana-service-name
  service-port       = local.kibana-service-port
  release-name       = local.kibana-release-name
}
