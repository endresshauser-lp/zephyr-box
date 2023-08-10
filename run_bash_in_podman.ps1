$PRJ_ROOT=$pwd
$WEST_WORKSPACE_HOST="$PRJ_ROOT/.west_workspace"
$WEST_WORKSPACE_CONTAINER="/opt/zephyrproject"
$WORKDIR_HOST=$PRJ_ROOT
$WORKDIR_CONTAINER="$WEST_WORKSPACE_CONTAINER/$(Split-Path $PRJ_ROOT -Leaf)"

if (!(Test-Path $WEST_WORKSPACE_HOST))
{
	mkdir $WEST_WORKSPACE_HOST 
}

podman build --network host --tag localhost/zephyrbox:latest .

podman run --network host -ti --rm --privileged `
	-v ${WEST_WORKSPACE_HOST}:${WEST_WORKSPACE_CONTAINER} `
	-v ${WORKDIR_HOST}:$WORKDIR_CONTAINER `
	-e WEST_WORKSPACE_CONTAINER=${WEST_WORKSPACE_CONTAINER} `
	-e WORKDIR_CONTAINER=$WORKDIR_CONTAINER `
	-e RUN_IN_TERM=true `
	-p 80:80 `
	-w $WORKDIR_CONTAINER `
	localhost/zephyrbox:latest