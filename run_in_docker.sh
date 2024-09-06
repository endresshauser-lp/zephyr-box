#!/bin/bash
set -e

USER_NAME=user
USER_UID=$(id -u "$(whoami)")
USER_GID=$(id -g "$(whoami)")

# SCRIPT_DIR needs to be the directory containing Dockerfile and a subdirectory of
# the PROJECT_ROOT_HOST directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
PROJECT_ROOT_HOST=$(realpath "$(dirname "$SCRIPT_DIR")")
WEST_WORKSPACE_HOST=$PROJECT_ROOT_HOST/.west_workspace

HOME_CONTAINTER=/home/$USER_NAME
WEST_WORKSPACE_CONTAINER=$HOME_CONTAINTER/west_workspace
PYTHON_VENV_CONTAINER=$WEST_WORKSPACE_CONTAINER/.venv
PROJECT_ROOT_CONTAINER=$WEST_WORKSPACE_CONTAINER/project

mkdir -p "$WEST_WORKSPACE_HOST"

docker build \
    --network host \
    --build-arg="USER_NAME=$USER_NAME" \
    --build-arg="UID=$USER_UID" \
    --build-arg="GID=$USER_GID" \
    --tag zephyr-box \
    "$SCRIPT_DIR"

docker run \
    --network host --tty --interactive --rm --privileged \
    --volume ~/.ssh:$HOME_CONTAINTER/.ssh \
    --volume /dev:/dev \
    --volume "$WEST_WORKSPACE_HOST:$WEST_WORKSPACE_CONTAINER" \
    --volume "$PROJECT_ROOT_HOST:$PROJECT_ROOT_CONTAINER" \
    --env WEST_WORKSPACE="$WEST_WORKSPACE_CONTAINER" \
    --env PYTHON_VENV="$PYTHON_VENV_CONTAINER" \
    --env PROJECT_ROOT="$PROJECT_ROOT_CONTAINER" \
    --entrypoint "$PROJECT_ROOT_CONTAINER/on_docker_startup.sh" \
    zephyr-box "$@"
