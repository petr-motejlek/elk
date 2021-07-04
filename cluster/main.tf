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

  internal_registry-url   = local.registry-common_name
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

locals {
  metallb-namespace-name = "metallb-system"
  metallb-release-name   = "metallb"
  metallb-pool-names     = ["default", "exdns"]
  metallb-pool-ranges    = ["192.168.0.20-192.168.0.29", "${local.exdns-ip}-${local.exdns-ip}"]
}

module "metallb" {
  depends_on = [
  module.k8s]
  source = "./metallb"

  namespace-name = local.metallb-namespace-name
  release-name   = local.metallb-release-name

  pool-names  = local.metallb-pool-names
  pool-ranges = local.metallb-pool-ranges
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

locals {
  longhorn-namespace-name     = "longhorn-system"
  longhorn-release-name       = "longhorn"
  longhorn-storage_class-name = "longhorn"
  longhorn-replicas-count     = 1
}

module "longhorn" {
  depends_on = [
  module.metallb]
  source = "./longhorn"

  namespace-name     = local.longhorn-namespace-name
  release-name       = local.longhorn-release-name
  storage_class-name = local.longhorn-storage_class-name
  replicas-count     = local.longhorn-replicas-count
}

locals {
  registry-common_name        = "${local.registry-service-name}.${local.registry-namespace-name}.${local.exdns-domain}"
  registry-namespace-name     = "registry"
  registry-cert-valid-hours   = 24 * 365
  registry-storage_class-name = module.longhorn.storage_class-name
  registry-service-name       = "registry"
  registry-service-port       = 443
}

module "registry" {
  depends_on = [
    module.longhorn,
  module.ca]
  source = "./registry"

  common_name              = local.registry-common_name
  ca-private_key-pem       = module.ca.private_key-pem
  ca-private_key-algorithm = module.ca.private_key-algorithm
  ca-public_key-pem        = module.ca.public_key-pem

  storage_class-name = local.registry-storage_class-name
  namespace-name     = local.registry-namespace-name
  cert-valid-hours   = local.registry-cert-valid-hours
  service-name       = local.registry-service-name
  service-port       = local.registry-service-port
}

variable "elasticsearch-replicas-count" {
  default = 3
  type    = number
}
locals {
  elasticsearch-image-name     = "elasticsearch"
  elasticsearch-service-name   = "elasticsearch"
  elasticsearch-service-port   = 9200
  elasticsearch-replicas-count = var.elasticsearch-replicas-count

  logstash-image-name   = "logstash"
  logstash-service-name = "logstash"
  logstash-service-port = 5042

  kibana-image-name   = "kibana"
  kibana-service-name = "kibana"
  kibana-service-port = 5601
}

module "elk" {
  depends_on = [
  module.registry]
  source = "./elk"

  storage_class = module.longhorn.storage_class-name

  elasticsearch-image-registry-url = local.internal_registry-url
  elasticsearch-image-name         = local.elasticsearch-image-name
  elasticsearch-service-name       = local.elasticsearch-service-name
  elasticsearch-service-port       = local.elasticsearch-service-port
  elasticsearch-replicas-count     = local.elasticsearch-replicas-count

  logstash-image-registry-url = local.internal_registry-url
  logstash-image-name         = local.logstash-image-name
  logstash-service-name       = local.logstash-service-name
  logstash-service-port       = local.logstash-service-port

  kibana-image-registry-url = local.internal_registry-url
  kibana-image-name         = local.kibana-image-name
  kibana-service-name       = local.kibana-service-name
  kibana-service-port       = local.kibana-service-port
}
