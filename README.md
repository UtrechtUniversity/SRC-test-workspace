# SRC-test-workspace

This repository provides a set of scripts and [Packer](https://www.packer.io/) image definitions for building container and VM images and containers that mimic a SURF Research Cloud (SRC) workspace, for development and testing/CI purposes. The container image built from this repo are published as a [GitHub package](https://github.com/orgs/UtrechtUniversity/packages/container/package/src-test-workspace) to https://ghcr.io. The following images are available:

| Image name | Tag | Description |
| -- | -- | -- |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_focal | Ubuntu 20.04 |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_focal_desktop | Ubuntu 20.04 with xfce4 |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_jammy | Ubuntu 22.04 |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_jammy_desktop | Ubuntu 22.04 with xfce4 |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_focal-pilot | Ubuntu 20.04, latest version of [base components](#how-it-works). |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_focal-desktop-pilot | Ubuntu 20.04 with xfce4, latest version of [base components](#how-it-works) |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_jammy-pilot | Ubuntu 22.04, latest version of [base components](#how-it-works) |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_jammy-desktop-pilot | Ubuntu 22.04 with xfce4, latest version of [base components](#how-it-works) |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_jammy-nginx | Ubuntu 22.04 with [Nginx component](https://github.com/utrechtuniversity/src-component-nginx) |
| ghcr.io/utrechtuniversity/src-test-workspace | ubuntu_jammy-nginx-pilot | Ubuntu 22.04 with [Nginx component](https://github.com/utrechtuniversity/src-component-nginx), latest version of [base components](#how-it-works) |

The repository provides:

* `pack.sh`: a script that wraps Packer to generate the desired images.
* templates for the Ubuntu images in the `ubuntu` directory.

Using these templates, you can build local containers or virtual machines that are as close to a workspace as it would be deployed on Research Cloud as possible!

Each image definition can be used to build either container images (using Docker or Podman), or VM images. See [below](#Usage).

## Requirements

1. [Packer](https://www.packer.io/)
1. Ansible
1. Docker (for building containers)
1. Vagrant (for building virtual machines)

Run `ansible-galaxy collection install -r requirements.yml` to install the required Ansible collections.

## Usage

To create the default `ubuntu/focal` image:

`./pack.sh [docker,podman,vagrant]`

- `./pack.sh docker` will generate a Docker container.
- `./pack.sh podman` will generate a Podman container.
- `./pack.sh vagrant` will create a vagrant VM.

To select a different image, use the `IMG` environment variable:

`IMG=ubuntu/jammy ./pack.sh docker`

Valid values for `IMG` are paths to directories containing the Packer templates, of the form `<os>/<version>` (for example, `ubuntu/jammy`).

### Base container images

Container images are built on top of the base images defined in the `base` directory. The Containerfiles in the subdirectories of that directory 
simply add support for `systemd` to standard OS (e.g. Ubuntu) container images. The base images are built automatically by `pack.sh`.

### Architecture

By default, images will be built for the `amd64` architecture. Set the `ARCH` environment variable to change this. For example:

`ARCH=arm64 ./pack.sh docker`

### Image outputs

The default name and tag of the generated image is of the form `src-test-workspace:os_version`. So after running `./pack.sh docker`, you can see e.g.:

```
$ docker image list
REPOSITORY                                     TAG                    IMAGE ID       CREATED         SIZE
ghcr.io/utrechtuniversity/src-test-workspace   ubuntu_jammy           41bbc80e345f   5 days ago      438MB
```

### Submodule updates

This repository contains a number of subrepos (see [below](#how-it-works)). To update them all to the latest version:

`git submodule update --recursive --remote`

To update a specific one to a specific version, do for example:

```bash
cd plugin-co
git checkout <your-sha>
```

To make `pack.sh` update submodules to the latest version, set the `UPDATE_BASE_COMPONENTS` environment variable to `true`.

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
├──cfo-al_desktop
│   ├── src-ubuntu.pkr.hcl -> ../src-ubuntu.pkr.hcl
│   └── variables.auto.pkrvars.hcl
├── jammy
│   ├── src-ubuntu.pkr.hcl -> ../src-ubuntu.pkr.hcl
│   └── variables.auto.pkrvars.hcl
└── src-ubuntu.pkr.hcl
```

As you can see, for the Ubuntu packages, the templates in `ubuntu/<version>/` actually just symlink the same template file `ubuntu/src-ubuntu.pkr.hcl`. Customization for each version is achieved using the `variables.auto.pkrvars.hcl` file in each `ubuntu/<version>` directory.

# Design Goals

The image defintions are designed to be:

1. as lightweight as possible, while...
2. still providing an accurate enough representation of an SRC workspace for testing purposes, and...
3. making tests run as fast as possible.

This means, for example, that we don't try to include *every* package present on an SRC Ubuntu workspace (lightweight), but we *do* make sure that Ansible is preinstalled on the image (see [below](#how-it-works), so this does not have to be done during each test run.

## How it works

The template uses a basic OS container (for the Docker target) or VM image (for the Vagrant target) to build the workspace on top of.

On top of the base Linux image, Packer will execute a number of shell scripts, and more importantly Ansible playbooks. These playbooks the three basic components provided by SURF that need to be present on any SRC workspace:

1. SRC-OS
1. SRC-CO
1. SRC-External

The repositories for these components are included in this repo as git submodules.

### SRC-OS

Installs basic packages and services, sets permissions, etc.

### SRC-CO

Provides SRAM authentication, user and group provisioning, etc. Currently used with SRAM (totp) authenticationi disabled. Instead, a local testuser (username `testuser`) is added to the image.

### SRC-External

This component is an Ansible playbook that:

* connects from the host (controller) to the workspace
* installs ansible on the workspace
* calls the locally installed `ansible-playbook` to execute third-party components

The Packer template will execute the SRC-External component once, with the `dummy-external-plugin` component. The latter does not do anything except a ping operation, but running the 
SRC-External playbook on the workspace ensures that Ansible is installed in exactly the same way and using exactly the same version as on Research Cloud.

Ensuring that Ansible and dependencies are already installed on the workspace means that executing further Ansible scripts on the workspace goes much faster than otherwise.

## Limitations

This Packer template does not generate containers or images that are *identical* to SRC workspaces, for a few reasons explained below. This is in principle not a problem, given the [design goals](#design-goals).

### Not the same base image

Packer will use the most recent version of the source OS images available on DockerHub/ or on https://vagrantup.com/boxes. These base images may not be the same as those used on SRC. In particular, the SURF images may contain more preinstalled packages that on our testing images. While this may cause some test failures, this is in fact desired: that way, we will uncover implicit dependencies on preinstalled packages that are not made explicit in our playubooks.

### No modifications of /etc/hosts and /etc/hostname possible on Docker

Docker does not allow modifying `/etc/hosts` or `/etc/hostname`. The SRC-OS component tries to do just that. To work around this issue, this repository utilizes a [fork](https://github.com/UtrechtUniversity/src-plugin-os/tree/3afd56eb7f4e5ad53d2e91b35920205384cbe6f6) of the  component that adds tags to the tasks that attempt to modify the `/etc/host*` files. Our Packer template ensures that Ansible will skip tasks with these tags, when we are trying to build a Docker (as opposed to VM) image.

# CI

The CI `build_and_deploy` workflow will run the `pack.sh` script on each template directory (`<os>/<version>`) that was changed in the pushed commit. It also detects if a symlinked template file is changed, and then run `pack.sh` on each template that relies on it. So for instance, if `ubuntu/src-ubuntu.pkr.hcl` is changed, the build is run for all the subdirectories of `ubuntu`: `ubuntu/focal`, `ubuntu/jammy`, `ubuntu_focal-desktop`.

The `build_and_deploy` workflow checks out the latest version of all the submodules, so the image builds are always based on the latest version of them.

The `prune` workflow runs once a day (or when manually triggered), and will remove all untagged image versions except for the newest three. This ensures that when a new version of an image is built (and receives its tags), older versions are removed -- but we always keep some old versions of the images.
