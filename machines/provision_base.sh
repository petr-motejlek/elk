#!/usr/bin/env bash

set -xeuo pipefail

export DEBIAN_FRONTEND=noninteractive

ssh-add -L >> ~/.ssh/authorized_keys

echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  ntp

# https://github.com/kubernetes/kubernetes/issues/96459#issuecomment-857711708
# BEGIN
sudo sed -i 's,$1 $2 $3,$1 --disable-timesync $2 $3,; s,$1 -- $2 $3,$1 -- --disable-timesync $2 $3,' \
  /opt/VBoxGuestAdditions-*/init/vboxadd-service
sudo systemctl daemon-reload
sudo systemctl restart vboxadd-service
# END


curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io
sudo usermod -a -G docker vagrant
sudo systemctl enable --now docker

curl -fsSL 'https://github.com/coredns/coredns/releases/download/v1.8.3/coredns_1.8.3_linux_amd64.tgz' | sudo tar -zxv -C /usr/bin/
sudo useradd -s /bin/false -m -d /var/lib/coredns coredns
sudo passwd -l coredns
curl -fsSL https://raw.githubusercontent.com/coredns/deployment/master/systemd/coredns.service | sudo tee /etc/systemd/system/coredns.service
sudo mkdir -p /etc/coredns
sudo tee /etc/coredns/Corefile <<EOF
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
sudo systemctl daemon-reload
sudo systemctl disable --now systemd-resolved
sudo rm /etc/resolv.conf
sudo tee /etc/resolv.conf <<EOF
nameserver 127.0.0.1
EOF
sudo systemctl enable --now coredns

