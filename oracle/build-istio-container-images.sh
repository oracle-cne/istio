#!/bin/bash -x
#
# Copyright (c) 2021-2025, Oracle and/or its affiliates. All rights reserved.
#

set -o errexit
set -o nounset
set -o pipefail

# please update this variable when adding a new arguments
TOTAL_CMD_ARGS=10

if [[ $# -lt $TOTAL_CMD_ARGS ]]; then
    echo "usage:" >&2
    echo "  $0 --image-dir <IMAGE_DIR> --rpm-version <ISTIO_VERSION> --rpm-release <ISTIO_MIN_VERSION> --kubectl-version <KUBECTL_VERSION>" >&2
    exit 1
fi

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -id | --image-dir)
        IMAGE_DIR="$2"
        shift # past argument
        shift # past value
        ;;
    -i | --image-tag)
        IMAGE_TAG_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
    -i | --rpm-version)
        RPM_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
    -r | --rpm-release)
        RPM_RELEASE="$2"
        shift # past argument
        shift # past value
        ;;
    -k | --kubectl-version)
        KUBECTL_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
    esac
done

for REPO_DIR in /etc/yum.repos.d /etc/yum.repos.internal.d; do
    if [ -d "${REPO_DIR}" ]; then
        find "${REPO_DIR}" -maxdepth 1 -type f -name "*.repo" -exec cp -p {} ./ \;
    fi
done

RPM_V=${RPM_VERSION}-${RPM_RELEASE}
REGISTRY=container-registry.oracle.com/olcne
mkdir -p ${IMAGE_DIR}

# Component that has generic docker build command
CMP_TAGS=("pilot" "proxyv2" "istio_kubectl" "install-cni" "istio-istioctl")

count=0
for CMP in "${CMP_TAGS[@]}"; do
    DOCKER_FILE_PATH=./oracle/"${CMP/_/-}"/Dockerfile
    CUSTOM_BUILD_SCRIPT=./oracle/"${CMP/_/-}"/build-docker.sh
    IMAGE_TAG=${CMP_TAGS[count]}
    # Check if any customized script is available for building the container image
    # If so calling the script with two parameter( version and image tar file output directory)
    if [ -f ${CUSTOM_BUILD_SCRIPT} ]; then
        ${CUSTOM_BUILD_SCRIPT} ${IMAGE_TAG_VERSION} ${IMAGE_DIR}
    else
        docker build \
            --no-cache \
            --pull \
            --build-arg REPO_NAME=${YUM_REPO} \
            --build-arg VERSION=${RPM_V} \
            --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} \
            --build-arg ISTIO_VERSION=${RPM_VERSION} \
            --build-arg http_proxy=${http_proxy} \
            --build-arg https_proxy=${http_proxy} \
            --tag ${REGISTRY}/${IMAGE_TAG}:${IMAGE_TAG_VERSION} \
            --file ${DOCKER_FILE_PATH} .

        docker save \
            --output ${IMAGE_DIR}/${IMAGE_TAG}.tar ${REGISTRY}/${IMAGE_TAG}:${IMAGE_TAG_VERSION}
    fi
    count=$((count + 1))
done
