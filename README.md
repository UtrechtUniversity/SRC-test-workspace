# SRC-test-workspace

A [Packer](https://www.packer.io/) image definition for building images and containers that mimic a SURF Research Cloud (SRC) workspace. Provided are:

* `src-workspace.pkr.hcl`: the Packer template
* `pack.sh`: a script that wraps Packer to generate a container or virtual machine image.

Using this template, you can build local containers or virtual machines that are as close to a workspace as it would be deployed on Research Cloud as possible! The generated containers 
and VMs are ready in a matter of a few minutes.

## Requirements

1. [Packer](https://www.packer.io/)
1. Ansible
1. Docker (for building containers)
1. Vagrant (for building virtual machines)

## Usage

`./pack.sh [docker,vagrant]`

For example, `./pack.sh docker` will generate a Docker container based on the template, while `./pack.sh vagrant` will create a vagrant VM based on the same.

The default name of the generated image is `src-basic-workspace`. So after running `./pack.sh docker`, you can see:

```
$ docker image list
REPOSITORY            TAG       IMAGE ID       CREATED         SIZE
src-basic-workspace   latest    c4c4496e23b5   6 minutes ago   608MB
```

# How it works

The template uses a basic OS container (for the Docker target) or VM image (for the Vagrant target) to build the workspace on top of. At present, only Ubuntu 20.04 (focal) sources are 
provided.

On top of the base Linux image, Packer will execute a number of Ansible playbooks. These are the three basic components provided by SURF that need to be present on any SRC workspace:

1. SRC-OS
1. SRC-CO (**currently not used**)
1. SRC-External

The repositories for these components are included in this repo as git submodules.

### SRC-OS

Installs basic packages and servives, sets permissions, etc.

### SRC-CO

Provides SRAM authentication, SSH, etc. Currently not yet implemented. Instead, a local testuser (username `testuser`) is added to the image.

### SRC-External

This component is an Ansible playbook that:

* connects to the workspace
* installs ansible on the workspace
* calls the locally installed `ansible-playbook` to execute third-party (e.g. our) components

The Packer template will execute the SRC-External component once, with the `dummy-external-plugin` component. The latter does not do anything except a ping operation, but running the 
SRC-External playbook on the workspace ensures that Ansible is installed in exactly the same way and using exactly the same version as on Research Cloud.

Ensuring that Ansible and dependencies are already installed on the workspace means that executing further Ansible scripts on the workspace goes much faster than otherwise.

# Limitations

This Packer template does not generate containers or images that are *identical* to SRC workspaces, for a few reasons explained below. The goal is to generate workspaces that are close 
enough for local testing purposes.

### Not the same base image

Packer will use the most recent version of the source OS images available on DockerHub/ or on https://vagrantup.com/boxes. These base images may not be the same as those used on SRC.

### No modifications of /etc/hosts and /etc/hostname possible on Docker

Docker does not allow modifying `/etc/hosts` or `/etc/hostname`. The SRC-OS component tries to do just that. To work around this issue, this repository utilizes a [fork]() of the 
component that adds tags to the tasks that attempt to modify the `/etc/host*` files. Tasks with these tags are skipped by ansible (as defined in the Packer template).

### No SRC-component

As explained above, the SRC-CO component is currenly not used. This is to avoid containers trying to connect to SURF to authorize (and fail).
