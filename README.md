# SRC-test-deployment
A set of scripts and image definitions to test development SURF Research Cloud (SRC) components locally. Provided are:

* `pack.sh`: a script that builds a basic SRC workspace (based on the `src-workspace.pkr.hcl` definition) image. The image contains the basic OS setup for an SRC workspace, as well as everything necessary to install additional components on it.
* `deploy.py`: a script that deploys a SRC component on a target image.

# Getting Started

Requirements:

1. [Packer](https://www.packer.io/)
1. Ansible
1. Docker (if you wish to build Docker containers, and not VM images)

To create a base Docker image (`src-basic-test`) to run tests/deploy components on:

1. Checkout the required submodules: `git submodule update --init --recursive`
1. `packer init .`
1. Build the base image: `./pack.sh docker`
1. You can now have a look around the newly configured workspace image: `docker run --rm -it src-basic-workspace /bin/bash`

