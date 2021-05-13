terraform {
  required_providers {
    archive = {
      source = "hashicorp/archive"
      version = "2.2.0"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "2.11.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.2.0"
    }
  }
}