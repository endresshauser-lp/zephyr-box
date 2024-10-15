#!/bin/bash
set -e

USER_UID=$(id -u "$(whoami)")
USER_GID=$(id -g "$(whoami)")

DOCKER_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PRJ_ROOT="$(dirname "$DOCKER_DIR")"
WEST_WORKSPACE_HOST=$PRJ_ROOT/.west_workspace
USER_HOME_CONTAINER=/home/user
WEST_WORKSPACE_CONTAINER=$USER_HOME_CONTAINER/west_workspace
PYTHON_VENV_CONTAINER=$WEST_WORKSPACE_CONTAINER/.pyEnv
WORKDIR_HOST=$PRJ_ROOT
WORKDIR_CONTAINER=$WEST_WORKSPACE_CONTAINER/$(basename "$PRJ_ROOT")
REQUIREMENTS_TXT="$WORKDIR_CONTAINER/requirements.txt"
ON_DOCKER_STARTUP="$WORKDIR_CONTAINER/on_docker_startup.sh"

touch ~/.bash_aliases
mkdir --parents "$WEST_WORKSPACE_HOST"

docker build \
    --network host \
    --build-arg="UID=$USER_UID" \
    --build-arg="GID=$USER_GID" \
    --tag zephyr-box \
    .

docker run \
    --network host --tty --interactive --rm --privileged \
    --volume "$WEST_WORKSPACE_HOST:$WEST_WORKSPACE_CONTAINER" \
    --volume "$WORKDIR_HOST:$WORKDIR_CONTAINER" \
    --volume ~/.ssh:/$USER_HOME_CONTAINER/.ssh \
    --volume ~/.bash_aliases:$USER_HOME_CONTAINER/.bash_aliases \
    --volume /dev:/dev \
    --env "WEST_WORKSPACE_CONTAINER=$WEST_WORKSPACE_CONTAINER" \
    --env "WORKDIR_CONTAINER=$WORKDIR_CONTAINER" \
    --env "PYTHON_VENV_CONTAINER=$PYTHON_VENV_CONTAINER" \
    --env "REQUIREMENTS_TXT=$REQUIREMENTS_TXT" \
    --env "ON_DOCKER_STARTUP=$ON_DOCKER_STARTUP" \
    zephyr-box \
    "$@"
