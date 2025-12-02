This directory contains images for base containers used by the Packer image definitions, corresponding to the value of the `container_base_img` Packer variable.

Containers should be slim and contain only the dependencies necessary to get Packer going; for instance, `sudo` and `ssh` need to be installed on the issue before we can start provisioning with Packer.
