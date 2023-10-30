packer {
  required_plugins {
    docker = {
      version = "~> 1"
      source  = "github.com/hashicorp/docker"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = "~> 1"
    }
  }
}

variable "enabled_sources" {
  default = [
    "source.docker.ubuntu"
  ]
  type = list(string)
}

variable "target_arch" {
  default = "linux/amd64"
  type    = string
}

source "docker" "ubuntu" {
  image       = "ubuntu:focal"
  platform    = var.target_arch
  pull        = true
  commit      = true
  run_command = ["-d", "-i", "-t", "--name", "test-image", "{{.Image}}", "/bin/bash"]
}

build {
  sources = var.enabled_sources

  post-processor "docker-tag" {
    repository = "test"
  }
  post-processor "shell-local" {
    inline = ["docker system prune -f"]
  }
}
