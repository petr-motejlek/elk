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

locals {
  chart-name = abspath("${path.module}/chart")
}

variable "replicas-count" {
  type = number
}
locals {
  replicas-count = var.replicas-count
}

resource "helm_release" "longhorn" {
  name = local.release-name

  # repository = "https://charts.longhorn.io"
  # chart      = "longhorn"

  chart = local.chart-name

  namespace = kubernetes_namespace.longhorn.metadata[0].name

  values = [
    yamlencode({
      persistence = {
        defaultClassReplicaCount = local.replicas-count
      }
      defaultSettings = {
        defaultReplicaCount                  = local.replicas-count
        allowNodeDrainWithLastHealthyReplica = true
        guaranteedEngineCPU                  = 2
        guaranteedEngineManagerCPU           = 2
        guaranteedReplicaManagerCPU          = 2
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
