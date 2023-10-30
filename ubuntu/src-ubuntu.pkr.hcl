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

variable "co_plugin_args" {
  type = map(string)
  default = {
    "co_totp"              = false,
    "co_researchdrive"     = false,
    "co_irods"             = false,
    "owner_id"             = "mocked_id",
    "co_user_api_endpoint" = "127.0.0.1",
    "co_token"             = "mocked_token",
    "co_id"                = "testimage",
    "co_passwordless_sudo" = true,
    "workspace_id"         = "mocked",
    "workspace_name"       = "src-test-workspace"
  }
}

variable "base_packages" {
  # It is currently necessary to install jinja2 as an apt package to keep jinja at version ~=2.
  # If we don't, jinja2 will be installed by pip as a dependency of ansible (in the external plugin)
  # That will cause version 3.1 of jinja to be installed, and this is not compatible with ansible 2.9.
  # Ansible 2.9.22 fixes this issue: https://github.com/ansible/ansible/issues/77413
  default = "python3 python3-jinja2 systemd sudo openssl git gpg gpg-agent cron rsync"
  type    = string
}

variable "extra_packages" {
  default = ""
  type    = string
}

variable "testuser" {
  type = map(string)
  default = {
    username = "testuser"
    password = "letmein"
  }
}

variable "target_arch" {
  default = "linux/amd64"
  type    = string
}

variable "docker_base_img" {
  default = ""
  type    = string
}

variable "vagrant_base_img" {
  default = ""
  type    = string
}

variable "img_name" {
  default = "src-workspace"
  type    = string
}

local "dummy_plugin_args" {
  expression = {
    "remote_ansible_version" = "${var.workspace_ansible_version}",
    "remote_plugin" = {
      "script_type"   = "Ansible PlayBook",
      "script_folder" = "../dummy-plugin",
      "path"          = "dummy.yml",
      "parameters"    = {},
      "arguments"     = "-i 127.0.0.1,"
    }
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
  image       = var.docker_base_img
  platform    = var.target_arch
  pull        = true
  commit      = true
  run_command = ["-d", "-i", "-t", "--name", var.ansible_host, "{{.Image}}", "/bin/bash"]
}

source "vagrant" "ubuntu" {
  communicator = "ssh"
  source_path  = var.vagrant_base_img
  provider     = "virtualbox"
  add_force    = true
}

build {
  sources = var.enabled_sources

  provisioner "shell" {
    only   = ["docker.ubuntu"]
    inline = ["apt update && DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y ${var.base_packages} ${var.extra_packages}"]
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
    playbook_file = "./plugin-co/plugin-co.yml"
    extra_arguments = concat(var.common_ansible_args, [
      "--extra-vars",
      jsonencode(var.co_plugin_args),
    ])
  }

  provisioner "ansible" {
    playbook_file = "./plugin-external-plugin/plugin-external-plugin.yml"
    extra_arguments = concat(var.common_ansible_args, [
      "--extra-vars",
      jsonencode(local.dummy_plugin_args),
    ])
  }

  # The autoremove command run below removes recommended and suggested packages installed by 'apt installs' executed by the components executed above.
  # This makes for a smaller image (~260MB), but it may result in errors if further components implicitly rely on those recommended packages.
  provisioner "shell" {
    inline = ["apt-get autoremove -y -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 && apt-get autoclean -y && apt-get clean -y", "rm -rf /tmp/* /var/tmp* /usr/share/doc/* /root/.ansible* /usr/share/man/* /root/.cache /etc/rsc/plugins/*"]
  }

  post-processor "docker-tag" {
    except     = ["vagrant.ubuntu"]
    repository = var.img_name
  }
  post-processor "shell-local" {
    except = ["vagrant.ubuntu"]
    inline = ["docker system prune -f"]
  }
}
