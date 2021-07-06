variable "namespace_name" {}
locals {
  namespace_name = var.namespace_name
}

variable "pool_names" {
  type = list(string)
}
variable "pool_ranges" {
  type = list(string)
}
locals {
  pools = [for idx, name in var.pool_names : {
    name  = name
    range = var.pool_ranges[idx]
  }]
}

resource "kubernetes_namespace" "metallb" {
  metadata {
    name = var.namespace_name
  }
}

variable "release_name" {}
locals {
  release_name = var.release_name
}

variable "chart_url" {}
locals {
  chart_url = var.chart_url
}

resource "helm_release" "metallb" {
  name      = local.release_name
  chart     = local.chart_url
  namespace = kubernetes_namespace.metallb.metadata[0].name
  values = [
    yamlencode({
      configInline = {
        address-pools = [for pool in local.pools : {
          name      = pool.name
          protocol  = "layer2"
          addresses = [pool.range]
        }]
      }
    })
  ]
}