#!/bin/bash
VALID_SOURCES="docker, podman, vagrant"
BASE_IMG_PATH="base"

if [ "$#" -lt 1 ]
then
  echo "No valid build targets supplied. Pass at least one of: $VALID_SOURCES."
  exit 1
fi

if [ -z "$UPDATE_BASE_COMPONENTS" ]
then
  UPDATE_BASE_COMPONENTS=false
fi

if [ -z "$BUILD_BASE_IMG" ]
then
  BUILD_BASE_IMG=true
fi

if [ -z "$IMG" ]
then
  IMG="ubuntu/focal"
fi
OS_NAME=$(echo "$IMG" | cut -f1 -d/)
OS_VERSION=$(basename "$IMG")

if [ -z "$ARCH" ]
then
  ARCH="linux/amd64"
else
  ARCH="linux/$ARCH"
fi
echo "Building image for architecture: $ARCH"

PODMAN_SRC="\"sources.podman.ubuntu\""
DOCKER_SRC="\"sources.docker.ubuntu\""
VAGRANT_SRC="\"sources.vagrant.ubuntu\""
TARGETS=()

build_base_img() {
  if [[ "$BUILD_BASE_IMG" == false ]]; then return; fi
  cmd="${1:-docker}"
  BASE_IMG_NAME="$OS_NAME"_"$OS_VERSION"
  BASE_BUILD_ARGS="build -t src-base-$BASE_IMG_NAME $BASE_IMG_PATH/$OS_NAME -f $BASE_IMG_PATH/$OS_NAME/Containerfile_$OS_VERSION --platform $ARCH"

  echo "Building base image for $OS_NAME $OS_VERSION $ARCH"
  echo "Build command: $cmd $BASE_BUILD_ARGS"
  eval "$cmd $BASE_BUILD_ARGS"
}

for i in "$@" ; do
    if [[ $i == "docker" ]] ; then
        TARGETS+=("$DOCKER_SRC")
        build_base_img 'docker'
    fi
    if [[ $i == "podman" ]] ; then
        TARGETS+=("$PODMAN_SRC")
        build_base_img 'podman'
    fi
    if [[ $i == "vagrant" ]] ; then
        TARGETS+=("$VAGRANT_SRC")
    fi
done

if [ ${#TARGETS[@]} -eq 0 ]
then
    echo "No valid build targets supplied. Pass at least one of: $VALID_SOURCES."
    exit 1
elif [ ${#TARGETS[@]} -eq 1 ]; then
    joined_targets=${TARGETS[0]}
else
  printf -v joined_targets '%s,' "${TARGETS[@]}"
fi

if [[ "$UPDATE_BASE_COMPONENTS" == true ]]
then
  echo "Updating submodules..."
  git submodule update --recursive --remote # Update git submodules
  IMG_TAG_SUFFIX="-var img_tag_suffix=-pilot"
fi

CMD="packer init $IMG && packer fmt $IMG && packer build -var 'enabled_sources=[$joined_targets]' -var 'target_arch=$ARCH' $IMG_TAG_SUFFIX $IMG"
echo "Running: $CMD"
eval "$CMD";
