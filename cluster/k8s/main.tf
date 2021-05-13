variable "dockerio_user" {}
variable "dockerio_token" {}

resource "vagrant_vm" "nodes" {
  env = {
    VAGRANT_EXPERIMENTAL = "disks",
    VAGRANTFILE_HASH     = md5(file("Vagrantfile"))
  }
  get_ports = true
}

locals {
  ips = {
    node0 : "192.168.0.10"
    node1 : "192.168.0.11"
    node2 : "192.168.0.12"
  }
}

resource "rke_cluster" "k8s" {
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
    # plugin = "canal"
    plugin = "weave"
  }
  dynamic "nodes" {
    for_each = vagrant_vm.nodes.machine_names

    content {
      address           = local.ips[nodes.value]
      hostname_override = nodes.value
      user              = vagrant_vm.nodes.ssh_config[nodes.key].user
      ssh_key           = vagrant_vm.nodes.ssh_config[nodes.key].private_key
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

output "ssh_host" {
  value = rke_cluster.k8s.nodes.0.address
}

output "ssh_user" {
  value = rke_cluster.k8s.nodes.0.user
}

output "ssh_private_key_pem" {
  value = rke_cluster.k8s.nodes.0.ssh_key
}
