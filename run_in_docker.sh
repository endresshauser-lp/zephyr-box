#!/bin/bash
set -e

# Parameters to configure script
SSH_DIR=${SSH_DIR:-"${HOME}/.ssh"}
RUN_LOCALLY=${RUN_LOCALLY:-"true"}
RUN_WITH_TTY=${RUN_WITH_TTY:-"true"}
RUN_OFFLINE=${RUN_OFFLINE:-"false"}
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"docker"}

EXTRA_VOLUMES=""
MOUNT_GITCONFIG=${MOUNT_GITCONFIG:-"false"}
GITCONFIG=${GITCONFIG:-"${HOME}/.gitconfig"}

DOCKER_REGISTRY=${DOCKER_REGISTRY:-"ghcr.io/endresshauser-lp"}
IMAGE_NAME="zephyr-box"

USER_UID=$(id -u "$(whoami)")
USER_GID=$(id -g "$(whoami)")

# DOCKER_DIR needs to be the directory containing Dockerfile and a subdirectory of
# the PROJECT_ROOT_HOST directory
DOCKER_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
PROJECT_ROOT_HOST=$(realpath "$(dirname "$DOCKER_DIR")")
WEST_WORKSPACE_HOST=$PROJECT_ROOT_HOST/.west_workspace
HOME_CONTAINER=/home/user
WEST_WORKSPACE_CONTAINER=$HOME_CONTAINER/west_workspace
PYTHON_VENV_CONTAINER=$WEST_WORKSPACE_CONTAINER/.pyEnv
PROJECT_ROOT_CONTAINER=$WEST_WORKSPACE_CONTAINER/$(basename "$PROJECT_ROOT_HOST")
REQUIREMENTS_TXT="$PROJECT_ROOT_CONTAINER/requirements.txt"
ON_DOCKER_STARTUP="$PROJECT_ROOT_CONTAINER/on_docker_startup.sh"

TTY_FLAG=""
if [ "$RUN_WITH_TTY" = "true" ]; then
    TTY_FLAG="--tty"
fi

mkdir --parents "$WEST_WORKSPACE_HOST"

if [ "$RUN_LOCALLY" = "true" ]; then
    # Build latest zephyr-box from scratch
    $CONTAINER_RUNTIME build \
        --network host \
        --build-arg="UID=$USER_UID" \
        --build-arg="GID=$USER_GID" \
        --tag zephyr-box \
        "$DOCKER_DIR"
else
    # Get zephyr-box image version from Git tag
    IMAGE_VERSION=$(git -C "$DOCKER_DIR" for-each-ref --points-at=HEAD --count=1 --format='%(refname)' 'refs/pull/*/head' | sed 's#refs/pull/\([0-9]\+\)/head#pr-\1#')
    if [ ! -z "$IMAGE_VERSION" ]; then
            printf "Using zephyr-box from pull request: %s\n" "${DOCKER_REGISTRY}/$IMAGE_NAME:$IMAGE_VERSION"
    else
        IMAGE_VERSION=$(git -C "$DOCKER_DIR" describe --tags --abbrev=0 2>/dev/null | sed -n 's/^v\([0-9]\+\.[0-9]\+\).*/\1/p')
        if [ -z "$IMAGE_VERSION" ]; then
            printf "No valid Git tag found to determine the version of the Docker image to be pulled from the remote\n"
            exit 1
        fi

        printf "Using zephyr-box from git tag: %s\n" "${DOCKER_REGISTRY}/$IMAGE_NAME:$IMAGE_VERSION"
    fi

    # Use already built zephyr-box image from remote with a tiny wrapper to get user UID and GID correct
    $CONTAINER_RUNTIME build \
         --build-arg="ZEPHYR_BOX_IMAGE=${DOCKER_REGISTRY}/$IMAGE_NAME:$IMAGE_VERSION" \
         --build-arg="UID=$USER_UID" \
         --build-arg="GID=$USER_GID" \
         --tag zephyr-box \
         --file "$DOCKER_DIR"/DockerfileUserWrapper .
fi

if [ "$MOUNT_GITCONFIG" = "true" ]; then
    EXTRA_VOLUMES+=" --volume $GITCONFIG:$HOME_CONTAINER/.gitconfig"
fi

if [ -d "$HOME/.config/gh" ]; then
    EXTRA_VOLUMES+=" --volume $HOME/.config/gh:$HOME_CONTAINER/.config/gh"
fi

$CONTAINER_RUNTIME run \
    --network host $TTY_FLAG --interactive --rm --privileged \
    --volume "$WEST_WORKSPACE_HOST:$WEST_WORKSPACE_CONTAINER" \
    --volume "$PROJECT_ROOT_HOST:$PROJECT_ROOT_CONTAINER" \
    --volume "$SSH_DIR":$HOME_CONTAINER/.ssh \
    --volume /dev:/dev \
    --volume /usr/local/share/ca-certificates:/usr/local/share/ca-certificates \
    $EXTRA_VOLUMES \
    --env WEST_WORKSPACE="$WEST_WORKSPACE_CONTAINER" \
    --env PROJECT_ROOT="$PROJECT_ROOT_CONTAINER" \
    --env RUN_OFFLINE="$RUN_OFFLINE" \
    --env PYTHON_VENV="$PYTHON_VENV_CONTAINER" \
    --env REQUIREMENTS_TXT="$REQUIREMENTS_TXT" \
    --env ON_DOCKER_STARTUP="$ON_DOCKER_STARTUP" \
    --env GH_TOKEN --env GITHUB_TOKEN \
    zephyr-box "$@"
