#!/bin/bash
set -e
echo `basename "$0"`

printf "\u1b[32m
███████╗███████╗██████╗ ██╗  ██╗██╗   ██╗██████╗       ██████╗  ██████╗ ██╗  ██╗
╚══███╔╝██╔════╝██╔══██╗██║  ██║╚██╗ ██╔╝██╔══██╗      ██╔══██╗██╔═══██╗╚██╗██╔╝
  ███╔╝ █████╗  ██████╔╝███████║ ╚████╔╝ ██████╔╝█████╗██████╔╝██║   ██║ ╚███╔╝ 
 ███╔╝  ██╔══╝  ██╔═══╝ ██╔══██║  ╚██╔╝  ██╔══██╗╚════╝██╔══██╗██║   ██║ ██╔██╗ 
███████╗███████╗██║     ██║  ██║   ██║   ██║  ██║      ██████╔╝╚██████╔╝██╔╝ ██╗
╚══════╝╚══════╝╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝      ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
\033[m\n"


if [ -d "$PYTHON_VENV_CONTAINER" ];
then
    echo "Python already initialized"
else
    python3 -m venv $PYTHON_VENV_CONTAINER
fi

. $PYTHON_VENV_CONTAINER/bin/activate
pip install west cryptography

# Move actual logic to another script so that we do not have to rebuild container each time entrypoint.sh is changed
dos2unix $WORKDIR_CONTAINER/on_docker_startup.sh
env ZEPHRY_BOX_PYTHON_VENV=$PYTHON_VENV_CONTAINER /bin/bash $WORKDIR_CONTAINER/on_docker_startup.sh

if [ -z "$RUN_IN_TERM" ];
then
    echo 'Container is running.'
else
    echo 'Container is running and can be attached.'
    cd $WORKDIR_CONTAINER
    bash
fi
