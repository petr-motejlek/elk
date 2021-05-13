resource "kubernetes_namespace" "elk" {
  metadata {
    name = "elk"
  }
}

variable "storage_class" {}

module "elasticsearch" {
  source = "./elasticsearch"

  namespace     = kubernetes_namespace.elk.metadata.0.name
  storage_class = var.storage_class
}

module "logstash" {
  depends_on = [module.elasticsearch]

  source = "./logstash"

  namespace     = kubernetes_namespace.elk.metadata.0.name
  storage_class = var.storage_class
}

module "kibana" {
  depends_on = [module.elasticsearch]

  source = "./kibana"

  namespace     = kubernetes_namespace.elk.metadata.0.name
  storage_class = var.storage_class
}
