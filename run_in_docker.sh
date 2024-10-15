#!/bin/bash
set -e

USER_UID=$(id -u "$(whoami)")
USER_GID=$(id -g "$(whoami)")

# DOCKER_DIR needs to be the directory containing Dockerfile and a subdirectory of
# the PROJECT_ROOT_HOST directory
DOCKER_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
PROJECT_ROOT_HOST=$(realpath "$(dirname "$DOCKER_DIR")")
WEST_WORKSPACE_HOST=$PROJECT_ROOT_HOST/.west_workspace
HOME_CONTAINTER=/home/user
WEST_WORKSPACE_CONTAINER=$HOME_CONTAINTER/west_workspace
PYTHON_VENV_CONTAINER=$WEST_WORKSPACE_CONTAINER/.pyEnv
PROJECT_ROOT_CONTAINER=$WEST_WORKSPACE_CONTAINER/$(basename "$PROJECT_ROOT_HOST")
REQUIREMENTS_TXT="$PROJECT_ROOT_CONTAINER/requirements.txt"
ON_DOCKER_STARTUP="$PROJECT_ROOT_CONTAINER/on_docker_startup.sh"


mkdir --parents "$WEST_WORKSPACE_HOST"

docker build \
    --network host \
    --build-arg="UID=$USER_UID" \
    --build-arg="GID=$USER_GID" \
    --tag zephyr-box \
    "$DOCKER_DIR"

docker run \
    --network host --tty --interactive --rm --privileged \
    --volume "$WEST_WORKSPACE_HOST:$WEST_WORKSPACE_CONTAINER" \
    --volume "$PROJECT_ROOT_HOST:$PROJECT_ROOT_CONTAINER" \
    --volume ~/.ssh:$HOME_CONTAINTER/.ssh \
    --volume /dev:/dev \
    --env WEST_WORKSPACE="$WEST_WORKSPACE_CONTAINER" \
    --env PROJECT_ROOT="$PROJECT_ROOT_CONTAINER" \
    --env PYTHON_VENV="$PYTHON_VENV_CONTAINER" \
    --env REQUIREMENTS_TXT="$REQUIREMENTS_TXT" \
    --env ON_DOCKER_STARTUP="$ON_DOCKER_STARTUP" \
    zephyr-box "$@"
