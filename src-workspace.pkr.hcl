variable "ansible_host" {
  default = "packer-src-workspace"
  type    = string
}

variable "enabled_sources" {
  default = [
    "source.vagrant.ubuntu-focal",
    "source.docker.ubuntu-focal"
  ]
  type = list(string)
}

variable "testuser" {
  type = map(string)
  default = {
    username = "testuser"
    password = "letmein"
  }
}

packer {
  required_plugins {
    docker = {
      version = ">= 0.0.7"
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

source "docker" "ubuntu-focal" {
  image       = "ubuntu:focal"
  pull        = "false"
  commit      = true
  run_command = ["-d", "-i", "-t", "--name", var.ansible_host, "{{.Image}}", "/bin/bash"]
}

source "vagrant" "ubuntu-focal" {
  communicator = "ssh"
  source_path  = "ubuntu/focal64"
  provider     = "virtualbox"
  add_force    = true
}

build {
  sources = var.enabled_sources

  # Begin Docker specific provisioning
  provisioner "shell" {
    only   = ["docker.ubuntu-focal"]
    inline = ["apt update && DEBIAN_FRONTEND=noninteractive apt install python3-minimal systemd sudo openssl -y"]
  }

  provisioner "ansible" {
    only          = ["docker.ubuntu-focal"]
    playbook_file = "./plugin-os/plugin-os.yml"
    extra_arguments = [
      "-b",
      "--skip-tags",
      "skip_on_container",
      "-vvv"
    ]
  }
  # End Docker specific provisioning

  # Begin Vagrant specific provisioning
  provisioner "ansible" {
    except        = ["docker.ubuntu-focal"]
    playbook_file = "./plugin-os/plugin-os.yml"
    extra_arguments = [
      "-b",
      "--extra-vars",
      "rsc_os_ip=127.0.0.1 rsc_os_fqdn=${var.ansible_host}.test",
      "-vvv"
    ]
  }
  # End Vagrant specific provisioning

  provisioner "shell" {
    inline = ["useradd -p $(openssl passwd -1  ${var.testuser.password}) ${var.testuser.username}"]
  }

  provisioner "ansible" {
    playbook_file = "./plugin-external-plugin/plugin-external-plugin.yml"
    extra_arguments = [
      "-b",
      "--extra-vars",
      "{'remote_plugin': {'script_type': 'Ansible PlayBook', 'script_folder': '../dummy-external-plugin', 'path': 'dummy.yml', 'parameters': {}, 'arguments': '-i 127.0.0.1,'}}",
      "-vvv"
    ]
  }

  provisioner "shell" {
    inline = ["apt-get purge -y openssl && apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y", "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp* /usr/share/doc/* /root/.ansible* /root/.cache"]
  }

  post-processor "docker-tag" {
    only       = ["docker.ubuntu-focal"]
    repository = "src-basic-workspace"
  }
}

