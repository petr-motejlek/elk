variable "registry-urls" {
  type = list(string)
}
variable "registry-users" {
  type = list(string)
}
variable "registry-tokens" {
  type = list(string)
}
variable "registry-isdefaults" {
  type = list(bool)
}
locals {
  registries = [for idx, url in var.registry-urls : {
    url        = url
    user       = var.registry-users[idx]
    token      = var.registry-tokens[idx]
    is_default = var.registry-isdefaults[idx]
  }]
}

variable "ca-public_key-path" {}
variable "ca-public_key-remote-path" {}
locals {
  ca-public_key-remote-path = var.ca-public_key-remote-path
  ca-public_key-path        = var.ca-public_key-path
}

variable "node-names" {}
variable "node-ext_ips" {}
variable "node-int_ips" {}
locals {
  nodes = { for idx, name in var.node-names : name => {
    ext_ip = var.node-ext_ips[idx]
    int_ip = var.node-int_ips[idx]
    user   = "vagrant"
    }
  }
}

variable "cluster-name" {}
locals {
  cluster-name = var.cluster-name
}

variable "kubeconfig-path" {}
locals {
  kubeconfig-path = var.kubeconfig-path
}

resource "ssh_resource" "node-init" {
  for_each = local.nodes

  host        = each.value.ext_ip
  user        = "vagrant"
  private_key = "dummy value, because we use ssh-agent"

  file {
    source      = local.ca-public_key-path
    destination = local.ca-public_key-remote-path
  }

  commands = [
    <<-EOT
      #!/usr/bin/env bash

      set -xeuo pipefail

      export DEBIAN_FRONTEND=noninteractive

      sudo cp ${local.ca-public_key-remote-path} /usr/local/share/ca-certificates/ca.crt
      sudo update-ca-certificates
      sudo systemctl restart docker
    EOT
  ]
}

resource "rke_cluster" "k8s" {
  depends_on = [ssh_resource.node-init]

  ssh_agent_auth = true
  cluster_name   = local.cluster-name

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
  filename          = local.kubeconfig-path
  file_permission   = "0700"
}

output "kubeconfig-path" {
  value = local_file.kubeconfig.filename
}
