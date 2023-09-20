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

variable "workspace_ansible_version" {
  default = "2.9"
  type    = string
}

variable "common_ansible_args" {
  default = [
    "-b",
    "--scp-extra-args", # This is required because of a bug in Packer when using SSH>=9.0: https://github.com/hashicorp/packer-plugin-ansible/issues/100
    "'-O'",
    "-vvvv"
  ]
  type = list(string)
}

variable "base_apt_packages" {
  # It is currently necessary to install jinja2 as an apt package to keep jinja at version ~=2.
  # If we don't, jinja2 will be installed by pip as a dependency of ansible (in the external plugin)
  # That will cause version 3.1 of jinja to be installed, and this is not compatible with ansible 2.9.
  # Ansible 2.9.22 fixes this issue: https://github.com/ansible/ansible/issues/77413
  default = "python3 python3-jinja2 systemd sudo openssl"
  type    = string
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
  image = "ubuntu:focal"
  #platform   = "linux/arm64"
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

  provisioner "shell" {
    only   = ["docker.ubuntu"]
    inline = ["apt update && DEBIAN_FRONTEND=noninteractive apt install ${var.base_apt_packages} -y"]
  }

  # Begin Docker specific provisioning
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
    inline = ["useradd -m -s $(which bash) -p $(openssl passwd -1  ${var.testuser.password}) ${var.testuser.username}"]
  }

  provisioner "ansible" {
    playbook_file = "./plugin-external-plugin/plugin-external-plugin.yml"
    extra_arguments = concat(var.common_ansible_args, [
      "--extra-vars",
      "{'remote_ansible_version': '${var.workspace_ansible_version}', 'remote_plugin': {'script_type': 'Ansible PlayBook', 'script_folder': '../dummy-external-plugin', 'path': 'dummy.yml', 'parameters': {}, 'arguments': '-i 127.0.0.1,'}}",
    ])
  }

  provisioner "shell" {
    inline = ["apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y", "rm -rf /tmp/* /var/tmp* /usr/share/doc/* /root/.ansible* /root/.cache"]
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