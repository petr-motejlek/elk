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
    <<-EOT
      persistence:
        defaultClassReplicaCount: 1
      defaultSettings:
        defaultReplicaCount: 1
        allowNodeDrainWithLastHealthyReplica: true
        guaranteedEngineCPU: 1
        guaranteedEngineManagerCPU: 1
        guaranteedReplicaManagerCPU: 1
    EOT
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
