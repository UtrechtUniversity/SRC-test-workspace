# SRC-test-workspace

A set of scripts and [Packer](https://www.packer.io/) image definitions for building images and containers that mimic a SURF Research Cloud (SRC) workspace.

Provided are:

* `pack.sh`: a script that wraps Packer to generate a container or virtual machine image.
* templates for various Ubuntu flavours in the `ubuntu` directory

Using these templates, you can build local containers or virtual machines that are as close to a workspace as it would be deployed on Research Cloud as possible! The generated containers and VMs are ready in a matter of a few minutes.

## Requirements

1. [Packer](https://www.packer.io/)
1. Ansible
1. Docker (for building containers)
1. Vagrant (for building virtual machines)

## Usage

To create the default `ubuntu/focal` image:

`./pack.sh [docker,vagrant]`

For example, `./pack.sh docker` will generate a Docker container based on the template, while `./pack.sh vagrant` will create a vagrant VM based on the same.

To select a different image, use the `IMG` environment variable:

`IMG=ubuntu/jammy ./pack.sh docker`

Valid values for `IMG` are paths to directories containing the Packer templates, of the form `<os>/<version>` (for example, `ubuntu/jammy`).

### Architecture

By default, images will be built for the `amd64` architecture. Set the `ARCH` environment variable to change this to `arm64`. For example:

`ARCH=arm64 ./pack.sh docker`

### Image outputs

The default name and tag of the generated image is of the form `src-test-workspace:os_version`. So after running `./pack.sh docker`, you can see e.g.:

```
$ docker image list
REPOSITORY                                     TAG                    IMAGE ID       CREATED         SIZE
ghcr.io/utrechtuniversity/src-test-workspace   ubuntu_jammy           41bbc80e345f   5 days ago      438MB
```

# How it works

The template uses a basic OS container (for the Docker target) or VM image (for the Vagrant target) to build the workspace on top of.

On top of the base Linux image, Packer will execute a number of shell scripts, and more importantly Ansible playbooks. These are the three basic components provided by SURF that need to be present on any SRC workspace:

1. SRC-OS
1. SRC-CO
1. SRC-External

The repositories for these components are included in this repo as git submodules.

### SRC-OS

Installs basic packages and services, sets permissions, etc.

### SRC-CO

Provides SRAM authentication, user and group provisioning, etc. Currently used with SRAM (totp) authenticationi disabled. A local testuser (username `testuser`) is added to the image.

### SRC-External

This component is an Ansible playbook that:

* connects to the workspace
* installs ansible on the workspace
* calls the locally installed `ansible-playbook` to execute third-party components

The Packer template will execute the SRC-External component once, with the `dummy-external-plugin` component. The latter does not do anything except a ping operation, but running the 
SRC-External playbook on the workspace ensures that Ansible is installed in exactly the same way and using exactly the same version as on Research Cloud.

Ensuring that Ansible and dependencies are already installed on the workspace means that executing further Ansible scripts on the workspace goes much faster than otherwise.

# Limitations

This Packer template does not generate containers or images that are *identical* to SRC workspaces, for a few reasons explained below. This is in principle not a problem, because the goal is to generate workspace images that are:

1. close enough for local testing purposes
1. contain as *minimal* a set of preinstalled packages as possible.

This will help e.g. to identify hidden assumptions in our workspace definitions. For instance, some playbooks may succeed because they implicitly rely on the presence of packages present on some of SURF's OS images. As long as these dependencies remain implicit, the playbooks may fail when executed on different (newer) OS images.

### Not the same base image

Packer will use the most recent version of the source OS images available on DockerHub/ or on https://vagrantup.com/boxes. These base images may not be the same as those used on SRC.

### No modifications of /etc/hosts and /etc/hostname possible on Docker

Docker does not allow modifying `/etc/hosts` or `/etc/hostname`. The SRC-OS component tries to do just that. To work around this issue, this repository utilizes a [fork](https://github.com/UtrechtUniversity/src-plugin-os/tree/3afd56eb7f4e5ad53d2e91b35920205384cbe6f6) of the 
component that adds tags to the tasks that attempt to modify the `/etc/host*` files. Tasks with these tags are skipped by ansible (as defined in the Packer template).

# Templates

The `pack.sh` scripts expects the templates to live in this repository, with the following directory structure:

```
os
├── version1
│   ├── src-os.pkr.hcl
│   └── variables.auto.pkrvars.hcl
├── version2
│   ├── src-os.pkr.hcl
│   └── variables.auto.pkrvars.hcl
```

For example, for the Ubuntu templates:

```
ubuntu
├── focal
│   ├── src-ubuntu.pkr.hcl -> ../src-ubuntu.pkr.hcl
│   └── variables.auto.pkrvars.hcl
├── focal_desktop
│   ├── src-ubuntu.pkr.hcl -> ../src-ubuntu.pkr.hcl
│   └── variables.auto.pkrvars.hcl
├── jammy
│   ├── src-ubuntu.pkr.hcl -> ../src-ubuntu.pkr.hcl
│   └── variables.auto.pkrvars.hcl
└── src-ubuntu.pkr.hcl
```

As you can see, for the Ubuntu packages, the templates in `ubuntu/<version>/` actually just symlink the same template file `ubuntu/src-ubuntu.pkr.hcl`. Customization for each version is achieved using the `variables.auto.pkrvars.hcl` file in each `ubuntu/<version>` directory.

### CI

The CI build-and-deploy task will run the `pack.sh` script on each template directory (`<os>/<version>`) that was changed in the pushed commit. It also detects if a symlinked template file is changed, and then run `pack.sh` on each template that relies on it. So for instance, if `ubuntu/src-ubuntu.pkr.hcl`, the build is run for all the Ubuntu templates (`ubuntu/focal`, `ubuntu/jammy`, `ubuntu_focal-desktop`).