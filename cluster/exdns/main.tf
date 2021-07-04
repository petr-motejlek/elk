resource "kubernetes_namespace" "exdns" {
  metadata {
    name = "exdns-system"
  }
}

resource "helm_release" "exdns" {
  name = "exdns"

  repository = "https://ori-edge.github.io/k8s_gateway/"
  chart      = "k8s-gateway"

  namespace = kubernetes_namespace.exdns.metadata[0].name

  values = [
    yamlencode({
      domain = "cls.local"
      service = {
        loadBalancerIP = "192.168.0.32"
      }
    })
  ]
}

