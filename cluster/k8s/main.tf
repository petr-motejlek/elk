variable "dockerio_user" {}
variable "dockerio_token" {}
variable "ca_public_key_hash" {}
variable "ca_public_key_path" {}

locals {
  nodes = {
    node0 : {
      ext_ip: "192.168.0.10",
      int_ip: "192.168.255.10"
    },
    node1 : {
      ext_ip: "192.168.0.11",
      int_ip: "192.168.255.11"
    },
    //    ...
  }
}

resource "ssh_resource" "node-init" {
  for_each = local.nodes

  host         = each.value.ext_ip
  user         = "vagrant"
  private_key = "dummy value, because we use ssh-agent"

  file {
    source = var.ca_public_key_path
    destination = "/home/vagrant/ca.pem"
  }

  commands = [
    <<-EOT
      #!/usr/bin/env bash

      set -xeuo pipefail

      export DEBIAN_FRONTEND=noninteractive

      sudo cp /home/vagrant/ca.pem /usr/local/share/ca-certificates/ca.crt
      sudo update-ca-certificates
    EOT
  ]
}

resource "rke_cluster" "k8s" {
  depends_on = [ssh_resource.node-init]

  ssh_agent_auth = true
  cluster_name = "k8s"
  private_registries {
    url        = "docker.io"
    user       = var.dockerio_user
    password   = var.dockerio_token
    is_default = true
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
      user              = "vagrant"
      role = [
        "controlplane",
        "etcd",
      "worker"]
    }
  }
}

resource "local_file" "kubeconfig" {
  sensitive_content = rke_cluster.k8s.kube_config_yaml
  filename          = "kubeconfig.yaml"
  file_permission   = "0700"
}

output "kubeconfig_path" {
  value = local_file.kubeconfig.filename
}
