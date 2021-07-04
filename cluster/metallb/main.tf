resource "kubernetes_namespace" "metallb" {
  metadata {
    name = "metallb-system"
  }
}

resource "helm_release" "metallb" {
  name = "metallb"

  // repository = "https://charts.bitnami.com/bitnami/"
  // chart      = "metallb"
  chart = "${path.module}/chart"

  namespace = kubernetes_namespace.metallb.metadata[0].name

  values = [
    yamlencode({
      configInline = {
        address-pools = [
          {
            name      = "default"
            protocol  = "layer2"
            addresses = ["192.168.0.20-192.168.0.29"]
          },
          {
            name      = "exdns"
            protocol  = "layer2"
            addresses = ["192.168.0.32-192.168.0.32"]
          }
        ]
      }
    })
  ]
}
