variable "namespace_name" {}
locals {
  namespace_name = var.namespace_name
}

resource "kubernetes_namespace" "exdns" {
  metadata {
    name = local.namespace_name
  }
}

variable "release_name" {}
variable "chart_repository" {}
variable "chart_name" {}
variable "domain" {}
variable "ip" {}
locals {
  release_name     = var.release_name
  chart_repository = var.chart_repository
  chart_name       = var.chart_name
  domain           = var.domain
  ip               = var.ip
}

resource "helm_release" "exdns" {
  name = local.release_name

  repository = local.chart_repository
  chart      = local.chart_name

  namespace = kubernetes_namespace.exdns.metadata[0].name

  values = [
    yamlencode({
      domain = local.domain
      service = {
        loadBalancerIP = local.ip
      }
    })
  ]
}

