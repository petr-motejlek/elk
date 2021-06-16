#!/usr/bin/env bash

set -xeuo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get install -y --no-install-recommends \
    nfs-common \
    open-iscsi

echo "InitiatorName=$(sudo /sbin/iscsi-iname)" | sudo tee /etc/iscsi/initiatorname.iscsi
