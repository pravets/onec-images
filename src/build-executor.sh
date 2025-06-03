#!/bin/bash
set -e

if [ -z ${CI} ]; then
	echo "The script is not running in CI"
	source ./scripts/load_env.sh	
else
	echo "The script is running in CI";
fi

./scripts/docker_login.sh
./scripts/prepare_executor_api_key.sh

if [[ $DOCKER_SYSTEM_PRUNE = "true" ]] ;
then

    docker system prune -af
fi

last_arg="."
if [[ $NO_CACHE = "true" ]] ; then
	last_arg="--no-cache ."
fi

executor_version=$EXECUTOR_VERSION

DOCKER_BUILDKIT=1 docker build \
    --secret id=dev1c_executor_api_key,src=dev1c_executor_api_key.txt \
    --pull \
    --build-arg EXECUTOR_VERSION="$EXECUTOR_VERSION" \
    -t $DOCKER_REGISTRY_URL/executor:$executor_version \
    -f ./src/executor/Dockerfile \
    $last_arg

docker push $DOCKER_REGISTRY_URL/executor:$executor_version

source ./scripts/cleanup.sh