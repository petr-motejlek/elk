terraform {
  required_providers {

    helm = {
      source  = "hashicorp/helm"
      version = "2.1.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.2.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }

    rke = {
      source  = "rancher/rke"
      version = "1.2.2"
    }

    shell = {
      source  = "scottwinkler/shell"
      version = "1.7.7"
    }

    ssh = {
      source  = "loafoe/ssh"
      version = "0.2.0"
    }

  }
}
