#!/bin/bash
set -e

get_index () {
    REDHAT_REGISTRY_TOKEN=$(curl --silent -u "${REGISTRY_REDHAT_IO_USER}":${REGISTRY_REDHAT_IO_PASS} "https://sso.redhat.com/auth/realms/rhcc/protocol/redhat-docker-v2/auth?service=docker-registry&client_id=curl&scope=repository:rhel:pull" | jq -r '.access_token')
    REMOTE_CREATED=$(curl --silent --location -H "Authorization: Bearer $REDHAT_REGISTRY_TOKEN"  https://registry.redhat.io/v2/redhat/redhat-operator-index/manifests/v4.8 | jq -r '.history[0].v1Compatibility' | jq -r '.created')
    LOCAL_CREATED=$(podman inspect registry.redhat.io/redhat/redhat-operator-index:v4.8 | jq -r '.[0].Created')
    if [ "${REMOTE_CREATED}" != "${LOCAL_CREATED}" ]; then
        ${CONTAINER_ENGINE} rmi -f ${IMAGE} | true
    fi
}

# Make sure all variables are set in the environment
export CONTAINER_ENGINE=$1
export IMAGE=$2
export REGISTRY_REDHAT_IO_USER=$3
export REGISTRY_REDHAT_IO_PASS=$4
echo "Checking for and outdated ${IMAGE} against the registry with user ${REGISTRY_REDHAT_IO_USER}."

get_index