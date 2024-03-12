#!/bin/bash

USE_WORKTREES=0
IMAGE_NAME=""
CONTAINER_NAME="zephyr-kite"
START_CMD="bash"
RULES=()
MOUNTS=()
declare -A volume_mounts
declare -A volume_mounts_has_link

docker_dir="$(realpath $(dirname ${BASH_SOURCE[0]}))"
prj_root="$(dirname $docker_dir)"
prj_deps=$prj_root/.west_workspace
prj_deps_container=/opt/zephyrproject
prj_root_container=$prj_deps_container/$(basename $prj_root)
user="user"
container_home="/home/$user"
startup_prefix="/tmp"
startup_location="$startup_prefix/"

# Set the name for the container.
set_name() {
    if [[ $# -ne 1 ]]; then
        echo "($FUNCNAME $@): Expected one argument (container-name) but $# were given." >&2
        exit 1
    fi

    CONTAINER_NAME=$1
}

use_worktrees() {
    if [[ $# -ne 0 ]]; then
        echo "($FUNCNAME $@): Expected no arguments but $# were given." >&2
        exit 1
    fi

    USE_WORKTREES=1
}

# Check if a volume exists.
volume_exist() {
    docker volume ls | grep $1 >/dev/null 2>&1
    echo $?
    return $?
}

# Adds a rule to be executed upon container startup.
add_rule() {
    RULES+=("$1;")
}

# Specify a command to run on entry.
run_on_entry() {
    if [[ $# -ne 1 ]]; then
        echo "($FUNCNAME $@): Expected one argument (program) but $# were given." >&2
        exit 1
    fi

    START_CMD=$1
}

# Sets the image to use.
use_image() {
    if [[ $# -ne 1 ]]; then
        echo "($FUNCNAME $@): Expected one argument (image-name) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    IMAGE_NAME=$1
}

# Adds a mountpoint to the container.
# If this function terminates successfully, it returns a mount index.
mountpoint() {
    if [[ $# -ne 3 ]]; then
        echo "($FUNCNAME $@): Expected three arguments (host, remote, access) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    local is_volume=$(volume_exist $1)
    local hostpath=$1
    if [[ $is_volume -ne 0 ]]; then
        hostpath=$(realpath $(eval echo $1))

        if ! [ -e $hostpath ]; then
            echo "($FUNCNAME $@): Host path \"$hostpath\" not found." >&2
            exit 1
        fi
    fi

    if [[ $2 != /* ]]; then
        echo "($FUNCNAME $@): Remote path \"$2\" is not absolute." >&2
        exit 1
    fi

    local mount_opt_regex="(ro|wo|rw|z|Z)(,(ro|wo|rw|z|Z))*"
    if ! [[ $3 =~ $mount_opt_regex ]]; then
        echo "($FUNCNAME $@): Expected some of the following access permissions: \"
            ro, wo, rw, z, Z but got \"$3\"." >&2
        exit 1
    fi

    local remotepath=$2
    local permissions=$3

    MOUNTS+=("-v $hostpath:$remotepath:$permissions")
}

# Creates and mounts a Docker volume.
volumemount() {
    if [[ $# -ne 3 ]]; then
        echo "($FUNCNAME $@): Expected three arguments (host, remote, access) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    if [[ $(volume_exist $1) -ne 0 ]]; then
        docker volume create $1
        if [[ $? -ne 0 ]]; then
            echo "($FUNCNAME $@): Failed to create volume \"$1\"." >&2
            exit 1
        fi
    fi

    mountpoint $1 $2 $3
    volume_mounts[$1]=$2
    add_rule "sudo chown $user $2"
}

# Inserts custom bash config.
bashconfig() {
    if [[ $# -ne 1 ]]; then
        echo "($FUNCNAME $@): Expected one argument (bashrc_config) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    mountpoint $1 "$container_home/.bashrc_custom" "ro"
}

# Inserts custom startup script.
startconfig() {
    if [[ $# -ne 1 ]]; then
        echo "($FUNCNAME $@): Expected one argument (startup_config) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    mountpoint $1 "$container_home/.startup_rules" "ro"
}

# Mounts a read only copy of a host file or folder, duplicates it on a given volume
# and creates a link to it within the container.
mountlink() {
    if [[ $# -ne 3 ]]; then
        echo "($FUNCNAME $@): Expected three arguments (host, volume, remote) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    local remote_path=${volume_mounts[$2]}
    if [[ -z $remote_path ]]; then
        echo "($FUNCNAME $@): No mount for volume \"$2\" specified." >&2
        exit 1
    fi

    if [[ -z ${volume_mounts_has_link[$2]} ]]; then
        add_rule "mkdir -p $remote_path/.links"
        volume_mounts_has_link[$2]="y"
    fi

    local link_path=$3
    if [[ $link_path != /* ]]; then
        echo "($FUNCNAME $@): The link target \"$link_path\" is not absolute." >&2
    fi

    local name=$(echo $3 | sed 's/\//-/g' | sed 's/\.//g')
    name=${name:1}
    local ro_path="$container_home/.dotfiles/$name"
    local rw_path="$remote_path/.links/$name"
    mountpoint $1 $ro_path "ro"
    add_rule \
        "rm -rf $rw_path \
        && cp -r $ro_path $rw_path \
        && mkdir -p $(dirname $link_path) \
        && ln -s $rw_path $link_path" 
}

# Creates a link from a read-only part in the filesystem to a writable path on a given volume.
volumelink() {
    if [[ $# -ne 2 ]]; then
        echo "($FUNCNAME $@): Expected two arguments (volume, remote) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    local remote_path=${volume_mounts[$1]}
    if [[ -z $remote_path ]]; then
        echo "($FUNCNAME $@): No mount for volume \"$1\" specified." >&2
        exit 1
    fi

    if [[ ${volume_mounts_has_link[$1]} != "y" ]]; then
        echo "${volume_mounts_has_link[$1]}"
        volume_mounts_has_link[$1]="y"
    fi

    local link_path=$2
    local name=$(echo $2 | sed 's/\//-/g' | sed 's/\.//g')
    name=${name:1}

    if [[ $link_path != /* ]]; then
        echo "($FUNCNAME $@): The link target \"$link_path\" is not absolute." >&2
    fi

    local rw_path="$remote_path/.links/$name"
    add_rule \
        "mkdir -p $rw_path \
        && mkdir -p $(dirname $link_path) \
        && ln -s $rw_path $link_path" 
}

# Exports all rules into bash commands and run a command.
export_rules() {
    startup_location+="startup$(head -c 4 /dev/random | od --format=x -A none | sed 's/ /-/g')"
    echo "${RULES[@]}" >> "$startup_location"
    startconfig $startup_location
}

# Export all mount options.
export_mounts() {
    echo "${MOUNTS[@]}"
}

# Updates the Docker container and runs an interactive shell inside it.
build_and_run() {
    if [[ IMAGE_NAME == "" ]]; then
        echo "No image name supplied with use_image." >&2
        exit 1
    fi

    # Create local dependency directory if it does not exist.
    mkdir -p $prj_deps
    export_rules

    # Build the docker image.
    echo "Updating Docker image..."
    cd $docker_dir
    docker build --network host --tag zephyr-box $docker_dir
    cd - >/dev/null

    current_branch=''
    if [[ $USE_WORKTREES != 0 ]]; then
        current_branch="/$(basename $prj_root)"
        prj_root=$(dirname $prj_root)
        prj_root_container=$prj_deps_container/$(basename $prj_root)
    fi

    # Run the docker image.
    docker run --rm --network host --privileged -tid                \
        -e RUN_IN_TERM=1                                            \
        -e USE_WORKTREES=$USE_WORKTREES                             \
        -e WEST_WORKSPACE_CONTAINER=$prj_deps_container             \
        -e WORKDIR_CONTAINER=$prj_root_container$current_branch     \
                                                                    \
        -v /dev:/dev                                                \
        -v $prj_deps:$prj_deps_container                            \
        -v $prj_root:$prj_root_container                            \
        $(export_mounts)                                            \
                                                                    \
        -w $prj_root_container                                      \
        --name $CONTAINER_NAME                                      \
        $IMAGE_NAME                                                 \
        $START_CMD

    rm $startup_location
}

# Attaches to a running container or builds it if it doesn't exist.
attach() {
    docker ps --filter="name=$CONTAINER_NAME" | grep $CONTAINER_NAME >/dev/null 2>&1
    if [[ $? != 0 ]]; then
        build_and_run
    fi
    docker exec -it $CONTAINER_NAME /bin/bash
}

