provider "docker" {
  registry_auth {
    address  = "registry.registry.cls.local"
    username = " "
    password = " "
  }
}
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

locals {
  ca-common_name     = "elk-ca"
  ca-valid-hours     = 24 * 365
  ca-public_key-path = abspath("${path.module}/ca.pem")
}

module "ca" {
  source = "./ca"

  ca-common_name     = local.ca-common_name
  ca-valid-hours     = local.ca-valid-hours
  ca-public_key-path = local.ca-public_key-path
}

module "k8s" {
  depends_on = [
  module.ca]
  source = "./k8s"

  dockerio_user      = var.dockerio_user
  dockerio_token     = var.dockerio_token
  ca_public_key_hash = module.ca.public_key-hash
  ca_public_key_path = module.ca.public_key-path
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

module "registry" {
  depends_on = [
    module.longhorn,
  module.ca]
  source = "./registry"

  ca_private_key_pem       = module.ca.private_key-pem
  ca_private_key_algorithm = module.ca.private_key-algorithm
  ca_public_key_pem        = module.ca.public_key-pem

  storage_class = module.longhorn.storage_class
}

module "elk" {
  depends_on = [
  module.registry]
  source = "./elk"

  storage_class = module.longhorn.storage_class
}
