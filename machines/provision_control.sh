#!/usr/bin/env bash

set -xeuo pipefail

export DEBIAN_FRONTEND=noninteractive

ssh-add -L >> ~/.ssh/authorized_keys

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main"

curl -fsSL https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-add-repository "deb https://baltocdn.com/helm/stable/debian/ all main"

sudo add-apt-repository --yes --update ppa:ansible/ansible

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ansible \
  git \
  helm \
  kubectl \
  rsync \
  terraform
