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

apt-get update
apt-get install -y --no-install-recommends \
  build-essential \
  git \
  kubectl \
  "linux-headers-$( uname -r )" \
  ntp \
  rsync \
  terraform \
  vagrant \
  virtualbox-6.1
