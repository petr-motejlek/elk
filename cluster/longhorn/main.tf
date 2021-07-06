variable "namespace_name" {}
locals {
  namespace_name = var.namespace_name
}

resource "kubernetes_namespace" "longhorn" {
  metadata {
    name = local.namespace_name
  }
}

variable "release_name" {}
locals {
  release_name = var.release_name
}

variable "storage_class_name" {}
locals {
  storage_class_name = var.storage_class_name
}

variable "replicas_count" {
  type = number
}
locals {
  replicas_count = var.replicas_count
}

variable "chart_url" {}
locals {
  chart_url = var.chart_url
}

resource "helm_release" "longhorn" {
  name      = local.release_name
  chart     = local.chart_url
  namespace = kubernetes_namespace.longhorn.metadata[0].name
  values = [
    yamlencode({
      persistence = {
        defaultClassReplicaCount = local.replicas_count
      }
      defaultSettings = {
        defaultReplicaCount                  = local.replicas_count
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
    name = local.storage_class_name
  }
}

output "storage_class_name" {
  value = data.kubernetes_storage_class.longhorn.metadata.0.name
}