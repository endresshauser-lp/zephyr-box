#!/bin/bash
set -e

printf "\u1b[32m
███████╗███████╗██████╗ ██╗  ██╗██╗   ██╗██████╗       ██████╗  ██████╗ ██╗  ██╗
╚══███╔╝██╔════╝██╔══██╗██║  ██║╚██╗ ██╔╝██╔══██╗      ██╔══██╗██╔═══██╗╚██╗██╔╝
  ███╔╝ █████╗  ██████╔╝███████║ ╚████╔╝ ██████╔╝█████╗██████╔╝██║   ██║ ╚███╔╝
 ███╔╝  ██╔══╝  ██╔═══╝ ██╔══██║  ╚██╔╝  ██╔══██╗╚════╝██╔══██╗██║   ██║ ██╔██╗
███████╗███████╗██║     ██║  ██║   ██║   ██║  ██║      ██████╔╝╚██████╔╝██╔╝ ██╗
╚══════╝╚══════╝╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝      ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
\033[m\n"

printenv

# Check that the required env variables are set, the others are optional.
if [[ -z "$PYTHON_VENV_CONTAINER" ]];
then
    echo "PYTHON_VENV_CONTAINER not defined"
    exit 1
fi
if [[ -z "$WEST_WORKSPACE_CONTAINER" ]];
then
    echo "WEST_WORKSPACE_CONTAINER not defined"
    exit 1
fi
if [[ -z "$WORKDIR_CONTAINER" ]];
then
    echo "WORKDIR_CONTAINER not defined"
    exit 1
fi

# Create and/or activate python virtual environment
if [ -d "$PYTHON_VENV_CONTAINER" ];
then
    echo "Python already initialized"
else
    python3 -m venv "$PYTHON_VENV_CONTAINER"
fi
. "$PYTHON_VENV_CONTAINER/bin/activate"

# Initialize and/or update west work space
cd "$WEST_WORKSPACE_CONTAINER"
pip3 install west
if [ -d "$WEST_WORKSPACE_CONTAINER/.west" ];
then
    echo "West already initialized"
else
    west init --local "$WORKDIR_CONTAINER"
fi
west update
west zephyr-export

# Install pip requirements for zephyr
pip3 install --verbose --upgrade --no-cache-dir \
    --requirement "$WEST_WORKSPACE_CONTAINER/zephyr/scripts/requirements.txt"

# Install pip requirements for project, if set as REQUIREMENTS_TXT
if [ -f "$REQUIREMENTS_TXT" ];
then
    pip3 install --verbose --upgrade --no-cache-dir \
        --requirement "$REQUIREMENTS_TXT"
else
    echo "requirements.txt not found (path:'$REQUIREMENTS_TXT'). No action."
fi

# Execute project specific startup logic, if specified as ON_DOCKER_STARTUP
if [ -f "$ON_DOCKER_STARTUP" ];
then
    dos2unix "$ON_DOCKER_STARTUP"
    . "$ON_DOCKER_STARTUP"
    # env may have been modified
    printenv
else
    echo "No project specific startup script found (path:'$ON_DOCKER_STARTUP'). No action."
fi

# Execute command passed as arguments in specified directory
if [[ -z "$CMD_WORK_DIR" ]];
then
    CMD_WORK_DIR="$WORKDIR_CONTAINER"
    echo "No custom working dir specified. defaulting to '$WORKDIR_CONTAINER'"
fi
cd "$CMD_WORK_DIR"
"$@"
