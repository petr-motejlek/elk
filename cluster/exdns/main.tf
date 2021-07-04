variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

resource "kubernetes_namespace" "exdns" {
  metadata {
    name = local.namespace-name
  }
}

variable "release-name" {}
variable "chart-repository" {}
variable "chart-name" {}
variable "domain" {}
variable "ip" {}
locals {
  release-name     = var.release-name
  chart-repository = var.chart-repository
  chart-name       = var.chart-name
  domain           = var.domain
  ip               = var.ip
}

resource "helm_release" "exdns" {
  name = local.release-name

  repository = local.chart-repository
  chart      = local.chart-name

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

