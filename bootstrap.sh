#!/usr/bin/env bash

set -xeou pipefail

BASE_CIDR="10.110.0.0/16"

IMAGE_NAME="terraform-custom"

docker build -f Dockerfile -t $IMAGE_NAME .

if ! docker network inspect tailscale-docker-terraform >/dev/null 2>&1; then
docker network create \
  --driver bridge \
  --subnet "$BASE_CIDR" \
  --ip-range "$BASE_CIDR" \
  tailscale-docker-terraform
fi

SOCKET_PATH=$(
  docker context inspect "$(docker context show)" \
    | jq -r '.[0].Endpoints.docker.Host | sub("^unix://"; "")'
)

docker run --rm -it \
  --network tailscale-docker-terraform \
  -v "$PWD:$PWD" \
  -v $SOCKET_PATH:/var/run/docker.sock \
  -w $PWD \
  $IMAGE_NAME \
  $@

# init
