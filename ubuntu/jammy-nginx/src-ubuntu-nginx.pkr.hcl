variable "source_repo" {
  default = "https://github.com/utrechtuniversity/src-test-workspace"
  type    = string
}

variable "container_repo" {
  default = ""
  type    = string
}

# pack.sh will set this variable to "-pilot" for pilot versions of the images
variable "img_tag_suffix" {
  default = ""
  type    = string
}

variable "ansible_host" {
  default = "packer-src"
  type    = string
}

variable "enabled_sources" {
  default = [
    "source.docker.ubuntu",
    "source.podman.ubuntu",
  ]
  type = list(string)
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
variable "target_arch" {
  default = "linux/amd64"
  type    = string
}

variable "container_base_img" {
  default = ""
  type    = string
}

variable "img_name" {
  default = "src-test-workspace"
  type    = string
}

variable "img_tag" {
  default = ""
  type    = string
}

local "ansible_host" {
  expression = "${var.ansible_host}-${var.img_tag}"
}

packer {
  required_plugins {
    podman = {
      version = ">=v0.1.0"
      source  = "github.com/polpetta/podman"
    }
    docker = {
      version = "~> 1"
      source  = "github.com/hashicorp/docker"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

source "podman" "ubuntu" {
  image       = var.container_base_img
  pull        = false
  commit      = true
  run_command = ["-d", "-i", "--platform", var.target_arch, "--name", local.ansible_host, "${var.container_base_img}", "/sbin/init"]
  changes = [
    "LABEL org.opencontainers.image.source=${var.source_repo}"
  ]
}

source "docker" "ubuntu" {
  image       = var.container_base_img
  platform    = var.target_arch
  pull        = false
  commit      = true
  run_command = ["-d", "-i", "-t", "--privileged", "--name", local.ansible_host, var.container_base_img, "/sbin/init"]
  changes = [
    "LABEL org.opencontainers.image.source=${var.source_repo}"
  ]
}

build {
  sources = var.enabled_sources

  provisioner "ansible" {
    playbook_file = "./src-component-nginx/plugin-nginx.yml"
    extra_arguments = concat(var.common_ansible_args, [
      "--skip-tags",
      "molecule-notest,molecule-idempotence-notest",
      "--extra-vars",
      "rsc_nginx_authorization_endpoint=/auth_endpoint rsc_nginx_user_info_endpoint=http://localhost rsc_nginx_service_url=localhost",
      "--extra-vars",
      "{nginx_enable_ssl: False, nginx_enable_auth: True}",
      "--extra-vars",
      "{rsc_nginx_oauth2_application: {client_id: 'foo'} }"
    ])
  }

  provisioner "file" {
    sources = "run_component.sh"
    destination = "/usr/local/bin/run_component.sh"
  }

  provisioner "file" {
    source = "plugin-external-plugin"
    destination = "/etc/rsc/plugin-external-plugin"
  }

  # The autoremove command run below removes recommended and suggested packages installed by 'apt installs' executed by the components executed above.
  # This makes for a smaller image (~260MB), but it may result in errors if further components implicitly rely on those recommended packages.
  provisioner "shell" {
    inline = [
      "apt-get autoremove -y -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 && apt-get autoclean -y && apt-get clean -y", "rm -rf /tmp/* /var/tmp* /usr/share/doc/* /root/.ansible* /usr/share/man/* /root/.cache /etc/rsc/plugins/*",
      "mkdir -p /usr/share/man/man1", # The step above removed all the man pages content, but this directory needs to be present as an install target for subsequent apt installs by components.
    ]
    inline_shebang = "/bin/sh -ex"
  }

  post-processor "docker-tag" {
    only       = ["docker.ubuntu"]
    repository = "${var.container_repo}${var.img_tag_suffix}"
  }

  post-processor "shell-local" {
    only   = ["podman.ubuntu"]
    inline = ["podman tag ${build.ImageSha256} ${var.container_repo}${var.img_tag_suffix}", "podman system prune -f"]
  }

  post-processor "shell-local" {
    only   = ["docker.ubuntu"]
    inline = ["docker system prune -f"]
  }
}
