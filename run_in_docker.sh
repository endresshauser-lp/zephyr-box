#!/bin/bash
set -e

# SCRIPT_DIR needs to be the directory containing Dockerfile
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
# WORK_DIR needs to be the directory containing the west.yml and the requirements.txt
WORK_DIR=$(realpath "$(dirname "$SCRIPT_DIR")")

USER_UID=$(id -u "$(whoami)")
USER_GID=$(id -g "$(whoami)")

docker build \
    --network host \
    --build-arg="UID=$USER_UID" \
    --build-arg="GID=$USER_GID" \
    --file "$SCRIPT_DIR/Dockerfile" \
    --tag zephyr-box \
    "$WORK_DIR"

docker run \
    --network host --tty --interactive --rm --privileged \
    --volume ~/.ssh:/home/user/.ssh \
    --volume /dev:/dev \
    --volume "$WORK_DIR:/home/user/west_workspace/project" \
    zephyr-box "$@"
