provider "docker" {
  registry_auth {
    address  = "registry.registry.cls.local"
    username = " "
    password = " "
  }
}
provider "helm" {
  kubernetes {
    config_path = module.k8s.kubeconfig-path
  }
}
provider "kubernetes" {
  config_path = module.k8s.kubeconfig-path
}

variable "dockerio_user" {
  sensitive = true
}
variable "dockerio_token" {
  sensitive = true
}
locals {
  dockerio-url   = "docker.io"
  dockerio-user  = var.dockerio_user
  dockerio-token = var.dockerio_token

  internal_registry-url   = "registry.registry.cls.local"
  internal_registry-user  = " "
  internal_registry-token = " "
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

locals {
  k8s-kubeconfig-path = abspath("${path.root}/kubeconfig.yaml")
  k8s-cluster-name    = local.exdns-domain
  k8s-node-names      = ["node0", "node1"]
  k8s-node-ext_ips    = ["192.168.0.10", "192.168.0.11"]
  k8s-node-int_ips = [
    "192.168.255.10",
  "192.168.255.11"]
  k8s-release-name              = "k8s"
  k8s-ca-public_key-remote-path = "/home/vagrant/ca.pem"
}

module "k8s" {
  depends_on = [
  module.ca]
  source = "./k8s"

  cluster-name    = local.k8s-cluster-name
  kubeconfig-path = local.k8s-kubeconfig-path

  registry-urls       = [local.dockerio-url, local.internal_registry-url]
  registry-users      = [local.dockerio-user, " "]
  registry-tokens     = [local.dockerio-token, " "]
  registry-isdefaults = [true, false]

  ca-public_key-hash        = module.ca.public_key-hash
  ca-public_key-path        = module.ca.public_key-path
  ca-public_key-remote-path = local.k8s-ca-public_key-remote-path

  node-names   = local.k8s-node-names
  node-ext_ips = local.k8s-node-ext_ips
  node-int_ips = local.k8s-node-int_ips
}

module "metallb" {
  depends_on = [
  module.k8s]
  source = "./metallb"
}

locals {
  exdns-namespace-name   = "exdns-system"
  exdns-release-name     = "exdns"
  exdns-chart-repository = "https://ori-edge.github.io/k8s_gateway/"
  exdns-chart-name       = "k8s-gateway"
  exdns-domain           = "cls.local"
  exdns-ip               = "192.168.0.32"
}

module "exdns" {
  depends_on = [
  module.metallb]
  source = "./exdns"

  namespace-name   = local.exdns-namespace-name
  chart-name       = local.exdns-chart-name
  chart-repository = local.exdns-chart-repository
  domain           = local.exdns-domain
  ip               = local.exdns-ip
  release-name     = local.exdns-release-name
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
