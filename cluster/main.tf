variable "dockerio_user" {
  sensitive = true
}
variable "dockerio_token" {
  sensitive = true
}
locals {
  dockerio_url   = "docker.io"
  dockerio_user  = var.dockerio_user
  dockerio_token = var.dockerio_token

  internal_registry_url   = local.registry_common_name
  internal_registry_user  = " "
  internal_registry_token = " "
}

locals {
  registry_auths = [
    {
      address  = local.internal_registry_url
      username = local.internal_registry_user
      password = local.internal_registry_token
    },
    {
      address  = local.dockerio_url
      username = local.dockerio_user
      password = local.dockerio_token
    }
  ]
}

provider "docker" {
  dynamic "registry_auth" {
    for_each = local.registry_auths

    content {
      address  = registry_auth.value.address
      username = registry_auth.value.username
      password = registry_auth.value.password
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = local.k8s_ca_crt_pem
    client_certificate     = local.k8s_client_crt_pem
    client_key             = local.k8s_client_key_pem
  }
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = local.k8s_ca_crt_pem
  client_certificate     = local.k8s_client_crt_pem
  client_key             = local.k8s_client_key_pem
}

locals {
  ca_common_name          = "elk-ca"
  ca_valid_hours          = 24 * 365
  ca_public_key_path      = abspath("${path.module}/ca.pem")
  ca_subjects_valid_hours = 24 * 365
}

module "ca" {
  source = "./ca"

  ca_common_name = local.ca_common_name
  ca_valid_hours = local.ca_valid_hours

  subjects_common_names = [local.registry_common_name]
  subjects_valid_hours  = local.ca_subjects_valid_hours
}

locals {
  ca_public_key_pem = module.ca.public_key_pem
}

output "ca_public_key_pem" {
  value = local.ca_public_key_pem
}

locals {
  k8s_cluster_name = local.exdns_domain
  k8s_node_names   = ["node0", "node1"]
  k8s_node_ext_ips = ["192.168.0.10", "192.168.0.11"]
  k8s_node_int_ips = [
    "192.168.255.10",
  "192.168.255.11"]
  k8s_release_name = "k8s"
}

module "k8s" {
  depends_on = [
  module.ca]
  source = "./k8s"

  cluster_name = local.k8s_cluster_name

  registry_urls       = [local.dockerio_url, local.internal_registry_url]
  registry_users      = [local.dockerio_user, " "]
  registry_tokens     = [local.dockerio_token, " "]
  registry_isdefaults = [true, false]

  ca_public_key_pem = local.ca_public_key_pem

  node_names   = local.k8s_node_names
  node_ext_ips = local.k8s_node_ext_ips
  node_int_ips = local.k8s_node_int_ips
}

locals {
  k8s_kubeconfig_yaml = module.k8s.kubeconfig_yaml
  k8s_host            = module.k8s.kubeconfig_host
  k8s_ca_crt_pem      = module.k8s.kubeconfig_ca_crt_pem
  k8s_client_crt_pem  = module.k8s.kubeconfig_client_crt_pem
  k8s_client_key_pem  = module.k8s.kubeconfig_client_key_pem
}

output "k8s_kubeconfig_yaml" {
  value     = local.k8s_kubeconfig_yaml
  sensitive = true
}

variable "metallb_chart_url" {
  default = "https://charts.bitnami.com/bitnami/metallb-2.4.3.tgz"
}
locals {
  metallb_namespace_name = "metallb-system"
  metallb_release_name   = "metallb"
  metallb_pool_names     = ["default", "exdns"]
  metallb_pool_ranges    = ["192.168.0.20-192.168.0.29", "${local.exdns_ip}-${local.exdns_ip}"]
  metallb_chart_url      = var.metallb_chart_url
}

module "metallb" {
  depends_on = [
  module.k8s]
  source = "./metallb"

  chart_url      = local.metallb_chart_url
  namespace_name = local.metallb_namespace_name
  release_name   = local.metallb_release_name

  pool_names  = local.metallb_pool_names
  pool_ranges = local.metallb_pool_ranges
}

variable "domain" {
  default = "cls.local"
}
locals {
  exdns_namespace_name   = "exdns-system"
  exdns_release_name     = "exdns"
  exdns_chart_repository = "https://ori-edge.github.io/k8s_gateway/"
  exdns_chart_name       = "k8s-gateway"
  exdns_domain           = var.domain
  exdns_ip               = "192.168.0.32"
}

module "exdns" {
  depends_on = [
  module.metallb]
  source = "./exdns"

  namespace_name   = local.exdns_namespace_name
  chart_name       = local.exdns_chart_name
  chart_repository = local.exdns_chart_repository
  domain           = local.exdns_domain
  ip               = local.exdns_ip
  release_name     = local.exdns_release_name
}

variable "longhorn_replicas_count" {
  type    = number
  default = 2
}
variable "longhorn_chart_url" {
  default = "https://github.com/longhorn/charts/releases/download/longhorn-1.1.0/longhorn-1.1.0.tgz"
}
locals {
  longhorn_namespace_name     = "longhorn-system"
  longhorn_release_name       = "longhorn"
  longhorn_storage_class_name = "longhorn"
  longhorn_replicas_count     = max((length(local.k8s_node_names) >= 2 ? 2 : 1), var.longhorn_replicas_count)
  longhorn_chart_url          = var.longhorn_chart_url
}

module "longhorn" {
  depends_on = [
  module.metallb]
  source = "./longhorn"

  chart_url          = local.longhorn_chart_url
  namespace_name     = local.longhorn_namespace_name
  release_name       = local.longhorn_release_name
  storage_class_name = local.longhorn_storage_class_name
  replicas_count     = local.longhorn_replicas_count
}

locals {
  registry_common_name        = "${local.registry_service_name}.${local.registry_namespace_name}.${local.exdns_domain}"
  registry_namespace_name     = "registry"
  registry_storage_class_name = module.longhorn.storage_class_name
  registry_service_name       = "registry"
  registry_service_port       = 443
  registry_release_name       = "registry"
}

locals {
  registry_tls_key_pem = module.ca.subjects_tls_key_pems[local.registry_common_name]
  registry_tls_crt_pem = module.ca.subjects_tls_crt_pems[local.registry_common_name]
}

module "registry" {
  depends_on = [
    module.longhorn,
  module.ca]
  source = "./registry"

  storage_class_name = local.registry_storage_class_name
  namespace_name     = local.registry_namespace_name
  service_name       = local.registry_service_name
  service_port       = local.registry_service_port
  release_name       = local.registry_release_name
  tls_key_pem        = local.registry_tls_key_pem
  tls_crt_pem        = local.registry_tls_crt_pem
}

variable "elasticsearch_replicas_count" {
  default = 3
  type    = number
}
locals {
  elk_namespace_name     = "elk"
  elk_release_name       = "elk"
  elk_storage_class_name = module.longhorn.storage_class_name

  elasticsearch_image_name     = "elasticsearch"
  elasticsearch_service_name   = "elasticsearch"
  elasticsearch_service_port   = 9200
  elasticsearch_replicas_count = var.elasticsearch_replicas_count
  elasticsearch_release_name   = "elasticsearch"

  logstash_image_name   = "logstash"
  logstash_service_name = "logstash"
  logstash_service_port = 5042
  logstash_release_name = "logstash"

  kibana_image_name   = "kibana"
  kibana_service_name = "kibana"
  kibana_service_port = 5601
  kibana_release_name = "kibana"
}

module "elk" {
  depends_on = [
  module.registry]
  source = "./elk"

  namespace_name     = local.elk_namespace_name
  release_name       = local.elk_release_name
  storage_class_name = local.elk_storage_class_name

  elasticsearch_image_registry_url = local.internal_registry_url
  elasticsearch_image_name         = local.elasticsearch_image_name
  elasticsearch_service_name       = local.elasticsearch_service_name
  elasticsearch_service_port       = local.elasticsearch_service_port
  elasticsearch_replicas_count     = local.elasticsearch_replicas_count

  logstash_image_registry_url = local.internal_registry_url
  logstash_image_name         = local.logstash_image_name
  logstash_service_name       = local.logstash_service_name
  logstash_service_port       = local.logstash_service_port

  kibana_image_registry_url = local.internal_registry_url
  kibana_image_name         = local.kibana_image_name
  kibana_service_name       = local.kibana_service_name
  kibana_service_port       = local.kibana_service_port
}