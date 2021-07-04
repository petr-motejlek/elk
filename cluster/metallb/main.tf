variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

variable "pool-names" {
  type = list(string)
}
variable "pool-ranges" {
  type = list(string)
}
locals {
  pools = [for idx, name in var.pool-names : {
    name  = name
    range = var.pool-ranges[idx]
  }]
}

resource "kubernetes_namespace" "metallb" {
  metadata {
    name = var.namespace-name
  }
}

variable "release-name" {}
locals {
  release-name = var.release-name
}

variable "chart-url" {}
locals {
  chart-url = var.chart-url
}

resource "helm_release" "metallb" {
  name      = local.release-name
  chart     = local.chart-url
  namespace = kubernetes_namespace.metallb.metadata[0].name
  values = [
    yamlencode({
      configInline = {
        address-pools = [for name, pool in local.pools : {
          name      = name
          protocol  = "layer2"
          addresses = [pool.range]
        }]
      }
    })
  ]
}