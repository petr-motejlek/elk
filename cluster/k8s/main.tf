variable "dockerio_user" {}
variable "dockerio_token" {}
variable "ca_public_key_hash" {}
variable "ca_public_key_path" {}

locals {
  nodes = {
    node0 : "192.168.0.10"
    //    node1 : "192.168.0.11"
    //    node2 : "192.168.0.12"
    //    ...
  }
}

resource "local_file" "provision_sh" {
  filename = abspath("${path.module}/provision.sh")
  content  = <<-EOT
    #!/usr/bin/env bash

    set -xeuo pipefail

    export DEBIAN_FRONTEND=noninteractive

    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    sysctl -p

    apt-get update
    apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      lsb-release \
      nfs-common \
      ntp \
      open-iscsi

    curl -fsSL 'https://github.com/coredns/coredns/releases/download/v1.8.3/coredns_1.8.3_linux_amd64.tgz' | sudo tar -zxv -C /usr/bin/
    useradd -s /bin/false -m -d /var/lib/coredns coredns
    passwd -l coredns
    curl -fsSL https://raw.githubusercontent.com/coredns/deployment/master/systemd/coredns.service | sudo tee /etc/systemd/system/coredns.service
    mkdir -p /etc/coredns
    >/etc/coredns/Corefile cat <<EOF
    cls.local.:53 {
        forward . 192.168.0.32
    }

    .:53 {
        forward . 8.8.8.8
        log
        errors
        cache
    }
    EOF
    systemctl daemon-reload
    systemctl disable --now systemd-resolved
    >/etc/resolv.conf cat <<EOF
    nameserver 127.0.0.1
    EOF
    systemctl enable --now coredns

    cp /home/vagrant/ca.pem /usr/local/share/ca-certificates/ca.crt
    update-ca-certificates

    echo "InitiatorName=$(/sbin/iscsi-iname)" > /etc/iscsi/initiatorname.iscsi

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-add-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    apt-get update
    apt-get install -y --no-install-recommends \
      docker-ce \
      docker-ce-cli \
      containerd.io
    usermod -a -G docker vagrant
    systemctl enable --now docker

  EOT
}

locals {
  touch_Vagrantfile = "echo > ${local.Vagrantfile_path}"
  Vagrantfile_path  = abspath("${path.module}/Vagrantfile")
}

resource "shell_script" "Vagrantfile" {
  # Dummy resource to make sure that "some" Vagrantfile is always present
  # because of https://github.com/bmatcuk/terraform-provider-vagrant/issues/10
  lifecycle_commands {
    create = local.touch_Vagrantfile
    delete = local.touch_Vagrantfile
  }
}

resource "local_file" "Vagrantfile" {
  depends_on = [shell_script.Vagrantfile]

  filename = local.Vagrantfile_path
  content  = <<-EOT
    def GBasMB(numGB)
      1024 * numGB
    end

    Vagrant.configure("2") do |config|
      config.vm.box = "ubuntu/focal64"

      config.vm.disk :disk, size: "64GB", primary: true

      config.vm.provider "virtualbox" do |vbox|
        vbox.cpus = 4
        vbox.memory = GBasMB 16
      end

      %{for node, ip in local.nodes}
        config.vm.define "${node}" do |node|
          node.vm.hostname = "${node}"
          node.vm.network "private_network", ip: "${ip}"
          node.vm.provider "virtualbox" do |vbox|
            vbox.name = "${node}"
          end
        end
      %{endfor}

      config.vm.provision :file, source: "${var.ca_public_key_path}", destination: "ca.pem"
      config.vm.provision :shell, path: "${local_file.provision_sh.filename}"
    end
  EOT
}

resource "vagrant_vm" "nodes" {
  vagrantfile_dir = dirname(local_file.Vagrantfile.filename)
  env = {
    VAGRANT_EXPERIMENTAL = "disks",
    CAFILE_HASH          = var.ca_public_key_hash
    VAGRANTFILE_HASH     = md5(local_file.Vagrantfile.content)
    PROVISIONSHFILE_HASH = md5(local_file.provision_sh.content)
  }
  get_ports = true
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
  dns {
    upstream_nameservers = [for node, ip in local.nodes : ip]
  }
  dynamic "nodes" {
    for_each = vagrant_vm.nodes.machine_names

    content {
      address           = local.nodes[nodes.value]
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
