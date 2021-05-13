#!/usr/bin/env bash

set -xeuo pipefail

export DEBIAN_FRONTEND=noninteractive

curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

apt-get update
apt-get install -y --no-install-recommends \
  git \
  "linux-headers-$( uname -r )" \
  ntp \
  rsync \
  terraform
