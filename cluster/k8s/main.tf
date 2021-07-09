variable "registry_urls" {
  type = list(string)
}
variable "registry_users" {
  type = list(string)
}
variable "registry_tokens" {
  type = list(string)
}
variable "registry_isdefaults" {
  type = list(bool)
}
locals {
  registries = [for idx, url in var.registry_urls : {
    url        = url
    user       = var.registry_users[idx]
    token      = var.registry_tokens[idx]
    is_default = var.registry_isdefaults[idx]
  }]
}

variable "ca_public_key_pem" {}
locals {
  ca_public_key_pem = var.ca_public_key_pem
}

variable "node_names" {}
variable "node_ext_ips" {}
variable "node_int_ips" {}
locals {
  nodes = { for idx, name in var.node_names : name => {
    ext_ip = var.node_ext_ips[idx]
    int_ip = var.node_int_ips[idx]
    user   = "vagrant"
    }
  }
}

variable "cluster_name" {}
locals {
  cluster_name = var.cluster_name
}

variable "kubeconfig_path" {}
locals {
  kubeconfig_path = var.kubeconfig_path
}

resource "ssh_resource" "node_init" {
  for_each = local.nodes

  host        = each.value.ext_ip
  user        = "vagrant"
  private_key = "dummy value, because we use ssh-agent"

  commands = [
    <<-EOT
      #!/usr/bin/env bash

      set -xeuo pipefail

      export DEBIAN_FRONTEND=noninteractive

      sudo tee /usr/local/share/ca-certificates/ca.crt <<EOF
${local.ca_public_key_pem}
EOF
      sudo update-ca-certificates
      sudo systemctl restart docker
    EOT
  ]
}

resource "rke_cluster" "k8s" {
  depends_on = [ssh_resource.node_init]

  ssh_agent_auth = true
  cluster_name   = local.cluster_name

  dynamic "private_registries" {
    for_each = local.registries

    content {
      url        = private_registries.value.url
      user       = private_registries.value.user
      password   = private_registries.value.token
      is_default = private_registries.value.is_default
    }
  }
  ingress {
    provider = "nginx"
  }
  network {
    plugin = "canal"
    canal_network_provider {
      iface = "eth1"
    }
  }
  dns {
    upstream_nameservers = [for node_name, node in local.nodes : node.ext_ip]
  }
  dynamic "nodes" {
    for_each = local.nodes

    content {
      address           = nodes.value.ext_ip
      hostname_override = nodes.key
      internal_address  = nodes.value.int_ip
      user              = nodes.value.user
      role = [
        "controlplane",
        "etcd",
      "worker"]
    }
  }
}

resource "local_file" "kubeconfig" {
  sensitive_content = rke_cluster.k8s.kube_config_yaml
  filename          = local.kubeconfig_path
  file_permission   = "0700"
}

output "kubeconfig_path" {
  value = local_file.kubeconfig.filename
}
