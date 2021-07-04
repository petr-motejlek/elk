resource "kubernetes_namespace" "longhorn" {
  metadata {
    name = "longhorn-system"
  }
}

resource "helm_release" "longhorn" {
  name = "longhorn"

  # repository = "https://charts.longhorn.io"
  # chart      = "longhorn"

  chart = "${path.module}/chart"

  namespace = kubernetes_namespace.longhorn.metadata[0].name

  values = [
    yamlencode({
      persistence = {
        defaultClassReplicaCount = 1
      }
      defaultSettings = {
        defaultReplicaCount                  = 1
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
    name = "longhorn"
  }
}

output "storage_class" {
  value = data.kubernetes_storage_class.longhorn.metadata.0.name
}
