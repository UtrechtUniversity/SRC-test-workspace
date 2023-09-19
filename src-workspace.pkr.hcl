variable "ansible_host" {
  default = "packer-src-workspace"
  type    = string
}

variable "enabled_sources" {
  default = [
    "source.vagrant.ubuntu",
    "source.docker.ubuntu"
  ]
  type = list(string)
}

variable "common_ansible_args" {
  default = [
    "-b",
    "--scp-extra-args", # This is required because of a bug in Packer when using SSH>=9.0: https://github.com/hashicorp/packer-plugin-ansible/issues/100
    "'-O'",
    "-vvv"
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

source "docker" "ubuntu" {
  image       = "ubuntu:focal"
  pull        = true
  commit      = true
  run_command = ["-d", "-i", "-t", "--name", var.ansible_host, "{{.Image}}", "/bin/bash"]
}

source "vagrant" "ubuntu" {
  communicator = "ssh"
  source_path  = "ubuntu/focal64"
  provider     = "virtualbox"
  add_force    = true
}

build {
  sources = var.enabled_sources

  # Begin Docker specific provisioning
  provisioner "shell" {
    only   = ["docker.ubuntu"]
    inline = ["apt update && DEBIAN_FRONTEND=noninteractive apt install python3-minimal systemd sudo openssl -y"]
  }

  provisioner "ansible" {
    only          = ["docker.ubuntu"]
    playbook_file = "./plugin-os/plugin-os.yml"
    extra_arguments = concat(var.common_ansible_args, [
      "--skip-tags",
      "skip_on_container",
    ])
  }
  # End Docker specific provisioning

  # Begin Vagrant specific provisioning
  provisioner "ansible" {
    except        = ["docker.ubuntu"]
    playbook_file = "./plugin-os/plugin-os.yml"
    extra_arguments = concat(var.common_ansible_args, [
      "--extra-vars",
      "rsc_os_ip=127.0.0.1 rsc_os_fqdn=${var.ansible_host}.test",
    ])
  }
  # End Vagrant specific provisioning

  provisioner "shell" {
    inline = ["useradd ${var.testuser.username}"]
  }

  provisioner "ansible" {
    playbook_file = "./plugin-external-plugin/plugin-external-plugin.yml"
    extra_arguments = concat(var.common_ansible_args, [
      "--extra-vars",
      "{'remote_plugin': {'script_type': 'Ansible PlayBook', 'script_folder': '../dummy-external-plugin', 'path': 'dummy.yml', 'parameters': {}, 'arguments': '-i 127.0.0.1,'}}",
    ])
  }

  provisioner "shell" {
    inline = ["apt-get purge openssl -y && apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y", "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp* /usr/share/doc/* /root/.ansible* /root/.cache"]
  }

  post-processor "docker-tag" {
    except     = ["vagrant.ubuntu"]
    repository = "src-basic-workspace"
  }
  post-processor "shell-local" {
    except = ["vagrant.ubuntu"]
    inline = ["docker system prune -f"]
  }
}

