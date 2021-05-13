#!/usr/bin/env bash

set -xeuo pipefail

export DEBIAN_FRONTEND=noninteractive

curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | apt-key add -
curl -fsSL https://www.virtualbox.org/download/oracle_vbox.asc | apt-key add -
apt-add-repository "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main"

curl -fsSL https://baltocdn.com/helm/signing.asc | apt-key add -
apt-add-repository "deb https://baltocdn.com/helm/stable/debian/ all main"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

apt-get update
apt-get install -y --no-install-recommends \
  build-essential \
  containerd.io \
  docker-ce \
  docker-ce-cli \
  git \
  helm \
  kubectl \
  "linux-headers-$( uname -r )" \
  ntp \
  rsync \
  terraform \
  vagrant \
  virtualbox-6.1

usermod -a -G docker vagrant
systemctl enable --now docker

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
