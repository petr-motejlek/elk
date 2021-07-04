variable "namespace-name" {}
locals {
  namespace-name = var.namespace-name
}

resource "kubernetes_namespace" "longhorn" {
  metadata {
    name = local.namespace-name
  }
}

variable "release-name" {}
locals {
  release-name = var.release-name
}

variable "storage_class-name" {}
locals {
  storage_class-name = var.storage_class-name
}

variable "replicas-count" {
  type = number
}
locals {
  replicas-count = var.replicas-count
}

variable "chart-url" {}
locals {
  chart-url = var.chart-url
}

resource "helm_release" "longhorn" {
  name      = local.release-name
  chart     = local.chart-url
  namespace = kubernetes_namespace.longhorn.metadata[0].name
  values = [
    yamlencode({
      persistence = {
        defaultClassReplicaCount = local.replicas-count
      }
      defaultSettings = {
        defaultReplicaCount                  = local.replicas-count
        allowNodeDrainWithLastHealthyReplica = true
        guaranteedEngineCPU                  = "250m"
        guaranteedEngineManagerCPU           = "250m"
        guaranteedReplicaManagerCPU          = "250m"
      }
    })
  ]
}

data "kubernetes_storage_class" "longhorn" {
  depends_on = [
  helm_release.longhorn]

  metadata {
    name = local.storage_class-name
  }
}

output "storage_class-name" {
  value = data.kubernetes_storage_class.longhorn.metadata.0.name
}