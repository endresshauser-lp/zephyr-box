#!/bin/bash

set -e

CONFIG_NAME="devconfig.sh"

docker_dir="$(realpath $(dirname ${BASH_SOURCE[0]}))"
prj_root="$(dirname $docker_dir)"
prj_dotfiles=$prj_root/.dotfiles
prj_deps=$prj_root/.west_workspace
prj_deps_container=/opt/zephyrproject
prj_root_container=$prj_deps_container/$(basename $prj_root)
prj_config=$prj_root/$CONFIG_NAME
container_home="/home/user"

RULES=()
MOUNTS=()
declare -A volume_mounts
declare -A volume_mounts_has_link

volume_exist() {
    docker volume ls | grep $1 >/dev/null 2>&1
    return $?
}

add_rule() {
    RULES+=($1";")
}

export_rules() {
    if [[ ${#RULES[@]} != 0 ]]; then
        echo "${RULES[@]} bash"
    else
        echo "bash"
    fi
}

export_mounts() {
    echo "${MOUNTS[@]}"
}

# Adds a mountpoint to the container.
# If this function terminates successfully, it returns a mount index.
mountpoint() {
    if [[ $# -ne 3 ]]; then
        echo "Expected three arguments (host, remote, access) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    local is_volume=$(volume_exist $1)
    local hostpath=$1
    if [[ $is_volume -ne 0 ]]; then
        if ! [ -f $1 ]; then
            echo "Host path \"$1\" not found." >&2
            exit 1
        fi

        hostpath=$(realpath $1)
    fi

    if [[ $2 != /* ]]; then
        echo "Remote path \"$2\" is not absolute." >&2
        exit 1
    fi

    local mount_options=("ro", "wo", "rw")
    if [[ ${mount_options[@]} =~ "\<$3\>" ]]; then
        echo "Expected one of the following access permissions: ${mount_options[@]}" \
            " but got \"$3\"." >&2
        exit 1
    fi

    local remotepath=$2
    local permissions=$3

    MOUNTS+=("-v $hostpath:$remotepath:$permissions")
}

# Creates and mounts a Docker volume.
volumemount() {
    if [[ $# -ne 3 ]]; then
        echo "Expected three arguments (host, remote, access) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    if [[ $(volume_exist $1) -ne 0 ]]; then
        docker volume create $1
        if [[ $? -ne 0 ]]; then
            echo "Failed to create volume \"$1\"." >&2
            exit 1
        fi
    fi

    mountpoint $1 $2 $3
    volume_mounts[$1]=$2
}

# Inserts custom bash config.
bashconfig() {
    if [[ $# -ne 1 ]]; then
        echo "Expected one argument (bashrc_config) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    mountpoint $1 "$container_home/.bashrc_custom" "ro"
}

# Inserts custom startup script.
startconfig() {
    if [[ $# -ne 1 ]]; then
        echo "Expected one argument (startup_config) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    mountpoint $1 "$container_home/.startup_custom" "ro"
}

# Mounts a read only copy of a host file or folder, duplicates it on a given volume
# and creates a link to it within the container.
mountlink() {
    if [[ $# -ne 4 ]]; then
        echo "Expected three arguments (host, volume, name, remote) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    local remote_path=${volume_mounts[$2]}
    if [[ -z $remote_path ]]; then
        echo "No mount for volume \"$2\" specified." >&2
        exit 1
    fi

    if [[ -z ${volume_mounts_has_link[$2]} ]]; then
        add_rule "mkdir -p $remote_path/.links"
        volume_mounts_has_link[$2]="y"
    fi

    local link_path=$4
    if [[ $link_path != /* ]]; then
        echo "The link target \"$link_path\" is not absolute." >&2
    fi

    local name=$3
    local ro_path="$container_home/.dotfiles/$name"
    local rw_path="$remote_path/.links/$name"
    mountpoint $1 $ro_path "ro"
    add_rule \
        "rm -rf $rw_path \
        && cp -r $ro_path $rw_path \
        && mkdir -p $(dirname $link_path) \
        && ln -s $rw_path $link_path" 
}

volumelink() {
    if [[ $# -ne 3 ]]; then
        echo "Expected three arguments (volume, name, remote) but $# were given." >&2
        # We directly return an error here so we receive it in the parent script.
        exit 1
    fi

    local remote_path=${volume_mounts[$1]}
    if [[ -z $remote_path ]]; then
        echo "No mount for volume \"$1\" specified." >&2
        exit 1
    fi

    if [[ -z ${volume_mounts_has_link[$1]} ]]; then
        add_rule "mkdir -p $remote_path/.links"
        volume_mounts_has_link[$1]="y"
    fi

    local name=$2
    local link_path=$3
    if [[ $link_path != /* ]]; then
        echo "The link target \"$link_path\" is not absolute." >&2
    fi

    local rw_path="$remote_path/.links/$name"
    add_rule \
        "mkdir -p $rw_path \
        && mkdir -p $(dirname $link_path) \
        && ln -s $rw_path $link_path" 
}

# Parses the configuration if it exists.
parse_config() {
    if [[ -f $prj_config ]]; then
        cd $(realpath $(dirname $prj_config))
        . $prj_config
        err=$?
        cd - >/dev/null
        if [ $err -ne 0 ]; then
            echo "Configuration in $prj_config contained errors ($err). Aborting..." >&2
            exit $err
        fi
    fi
}

# Updates the Docker container and runs an interactive shell inside it.
build_and_run() {
    # Create local dependency directory if it does not exist.
    mkdir -p $prj_deps

    # Build the docker image.
    echo "Updating Docker image..."
    cd $docker_dir
    docker build --network host --tag zephyr-box $docker_dir
    cd - >/dev/null

    # Run the docker image.
    docker run --rm --network host --privileged --ti        \
        -e RUN_IN_TERM=1                                    \
        -e WEST_WORKSPACE_CONTAINER=$prj_deps_container     \
        -e WORKDIR_CONTAINER=$prj_root_container            \
                                                            \
        -v /dev:/dev                                        \
        -v $prj_deps:$prj_deps_container                    \
        $(export_mounts)                                    \
                                                            \
        -w $prj_root_container                              \
        -p 80:80                                            \
        zephyr-box                                          \
        $(export_rules)
}

parse_config
build_and_run

