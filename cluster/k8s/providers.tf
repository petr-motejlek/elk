terraform {
  required_providers {

    rke = {
      source  = "rancher/rke"
      version = "1.2.2"
    }

    ssh = {
      source  = "loafoe/ssh"
      version = "0.2.0"
    }

  }
}
