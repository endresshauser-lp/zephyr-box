#!/bin/bash
set -e

USER_NAME=user
USER_UID=$(id -u "$(whoami)")
USER_GID=$(id -g "$(whoami)")

DOCKER_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PRJ_ROOT="$(dirname "$DOCKER_DIR")"
WEST_WORKSPACE_HOST=$PRJ_ROOT/.west_workspace
WEST_WORKSPACE_CONTAINER=/home/$USER_NAME/west_workspace
PYTHON_VENV_CONTAINER=$WEST_WORKSPACE_CONTAINER/.pyEnv
WORKDIR_HOST=$PRJ_ROOT
WORKDIR_CONTAINER=$WEST_WORKSPACE_CONTAINER/$(basename "$PRJ_ROOT")

touch ~/.bash_aliases
mkdir -p $WEST_WORKSPACE_HOST

docker build \
	--network host \
	--build-arg="USER_NAME=$USER_NAME" \
	--build-arg="UID=$USER_UID" \
	--build-arg="GID=$USER_GID" \
	--tag zephyr-box \
	.

docker run --network host -ti --rm --privileged \
	-v $WEST_WORKSPACE_HOST:$WEST_WORKSPACE_CONTAINER \
	-v $WORKDIR_HOST:$WORKDIR_CONTAINER \
	-v ~/.ssh:/home/user/.ssh \
	-v ~/.bash_aliases:/home/user/.bash_aliases \
	-w $WORKDIR_CONTAINER \
	-e WEST_WORKSPACE_CONTAINER=$WEST_WORKSPACE_CONTAINER \
	-e WORKDIR_CONTAINER=$WORKDIR_CONTAINER \
	-e PYTHON_VENV_CONTAINER=$PYTHON_VENV_CONTAINER \
	-v /dev:/dev \
	zephyr-box \
	"$@"
