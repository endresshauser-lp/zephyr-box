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
if [[ -z "$PYTHON_VENV" ]];
then
    echo "PYTHON_VENV not defined"
    exit 1
fi
if [[ -z "$WEST_WORKSPACE" ]];
then
    echo "WEST_WORKSPACE not defined"
    exit 1
fi
if [[ -z "$PROJECT_ROOT" ]];
then
    echo "PROJECT_ROOT not defined"
    exit 1
fi

# Create and/or activate python virtual environment
if [ -d "$PYTHON_VENV" ];
then
    echo "Python already initialized"
else
    python3 -m venv "$PYTHON_VENV"
fi
. "$PYTHON_VENV/bin/activate"

# Initialize and/or update west work space
cd "$WEST_WORKSPACE"
pip3 install west
if [ -d "$WEST_WORKSPACE/.west" ];
then
    echo "West already initialized"
else
    west init --local "$PROJECT_ROOT"
fi
west update
west zephyr-export

# Install pip requirements for zephyr
pip3 install --verbose --upgrade --no-cache-dir \
    --requirement "$WEST_WORKSPACE/zephyr/scripts/requirements.txt"

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
    CMD_WORK_DIR="$PROJECT_ROOT"
    echo "No custom working dir specified. defaulting to '$PROJECT_ROOT'"
fi
cd "$CMD_WORK_DIR"
"$@"
