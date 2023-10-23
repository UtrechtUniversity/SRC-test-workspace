#!/bin/bash
VALID_SOURCES="docker, vagrant"

if [ "$#" -lt 1 ]
then
  echo "No valid build targets supplied. Pass at least one of: $VALID_SOURCES."
  exit 1
fi

if [ -z $IMG ]
then
  IMG="ubuntu/focal"
fi

if [ -z $ARCH ]
then
  ARCH="linux/amd64"
else
  ARCH="linux/$ARCH"
fi
echo "Building image for architecture: $ARCH"

DOCKER_SRC="\"sources.docker.ubuntu\""
VAGRANT_SRC="\"sources.vagrant.ubuntu\""
TARGETS=()

for i in "$@" ; do
    if [[ $i == "docker" ]] ; then
        TARGETS+=($DOCKER_SRC)
    fi
    if [[ $i == "vagrant" ]] ; then
        TARGETS+=($VAGRANT_SRC)
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

CMD="packer fmt $IMG && packer build -var 'enabled_sources=[$joined_targets]' -var 'target_arch=$ARCH' $IMG"
echo "Running: $CMD"
eval "$CMD";