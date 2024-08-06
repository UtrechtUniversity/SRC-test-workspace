docker_repo               = "ghcr.io/utrechtuniversity/src-test-workspace:ubuntu_focal-desktop"
img_tag                   = "ubuntu_focal-desktop"
container_base_img        = "src-base-ubuntu_focal-desktop:latest"
vagrant_base_img          = "ubuntu/focal64"
extra_packages            = "gdm3 xfce4 xrdp xauth xorgxrdp"
extra_post_commands       = "update-alternatives --set x-session-manager /usr/bin/xfce4-session"
workspace_ansible_version = "9.1.0"
