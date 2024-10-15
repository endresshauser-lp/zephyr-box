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

echo 'Container is running.'
cd $WORKDIR_CONTAINER
"$@"
