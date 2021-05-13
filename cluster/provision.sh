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
>/etc/resolv.conf <<EOF
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
