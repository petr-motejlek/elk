provider "helm" {
  kubernetes {
    config_path = module.k8s.kubeconfig_path
  }
}
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

module "metallb" {
  depends_on = [
  module.k8s]
  source = "./metallb"
}

module "exdns" {
  depends_on = [
  module.metallb]
  source = "./exdns"
}

module "longhorn" {
  depends_on = [
  module.metallb]
  source = "./longhorn"
}