#!/bin/bash
echo `basename "$0"`

printf "\u1b[32m
███████╗███████╗██████╗ ██╗  ██╗██╗   ██╗██████╗       ██████╗  ██████╗ ██╗  ██╗
╚══███╔╝██╔════╝██╔══██╗██║  ██║╚██╗ ██╔╝██╔══██╗      ██╔══██╗██╔═══██╗╚██╗██╔╝
  ███╔╝ █████╗  ██████╔╝███████║ ╚████╔╝ ██████╔╝█████╗██████╔╝██║   ██║ ╚███╔╝ 
 ███╔╝  ██╔══╝  ██╔═══╝ ██╔══██║  ╚██╔╝  ██╔══██╗╚════╝██╔══██╗██║   ██║ ██╔██╗ 
███████╗███████╗██║     ██║  ██║   ██║   ██║  ██║      ██████╔╝╚██████╔╝██╔╝ ██╗
╚══════╝╚══════╝╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝      ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
\033[m\n"

# Setup python venv
ZEPHRY_BOX_PYTHON_VENV=$WEST_WORKSPACE_CONTAINER/.pyEnv

if [ -d "$ZEPHRY_BOX_PYTHON_VENV" ];
then
    echo "Python already initialized"
else
    python3 -m venv $ZEPHRY_BOX_PYTHON_VENV
fi

. $ZEPHRY_BOX_PYTHON_VENV/bin/activate
pip install west cryptography

# Move actual logic to another script so that we do not have to rebuild container each time entrypoint.sh is changed
dos2unix $WORKDIR_CONTAINER/on_docker_startup.sh
env ZEPHRY_BOX_PYTHON_VENV=$ZEPHRY_BOX_PYTHON_VENV /bin/bash $WORKDIR_CONTAINER/on_docker_startup.sh

if [ -z "$RUN_IN_TERM" ];
then
    echo 'Container is running.'
else
    echo 'Container is running and can be attached.'
    cd $WORKDIR_CONTAINER
    bash
fi
