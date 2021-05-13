provider "kubernetes" {
  config_path = module.k8s.kubeconfig_path
}

variable "dockerio_user" {
  sensitive = true
}
variable "dockerio_token" {
  sensitive = true
}

module "ca" {
  source = "./ca"
}

module "k8s" {
  depends_on = [
  module.ca]
  source = "./k8s"

  dockerio_user  = var.dockerio_user
  dockerio_token = var.dockerio_token
}