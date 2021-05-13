module "ca" {
  source = "./ca"
}

module "k8s" {
  depends_on = [
  module.ca]
  source = "./k8s"
}