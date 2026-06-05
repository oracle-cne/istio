#!/bin/bash -x
#
# Copyright (c) 2021-2025, Oracle and/or its affiliates. All rights reserved.
#

set -o errexit
set -o nounset
set -o pipefail

# please update this variable when adding new required arguments
TOTAL_CMD_ARGS=10
YUM_REPO_CONFIG_DIR=""

if [[ $# -lt $TOTAL_CMD_ARGS ]]; then
    echo "usage:" >&2
    echo "  $0 --image-dir <IMAGE_DIR> --image-tag <IMAGE_TAG> --rpm-version <ISTIO_VERSION> --rpm-release <ISTIO_MIN_VERSION> --kubectl-version <KUBECTL_VERSION> [--yum-repo-config-dir <YUM_REPO_CONFIG_DIR>]" >&2
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
    --yum-repo-config-dir)
        YUM_REPO_CONFIG_DIR="$2"
        shift # past argument
        shift # past value
        ;;
    esac
done

echo "build-istio-container-images.sh: image_dir=${IMAGE_DIR}"
echo "build-istio-container-images.sh: image_tag=${IMAGE_TAG_VERSION}"
echo "build-istio-container-images.sh: rpm_version=${RPM_VERSION}"
echo "build-istio-container-images.sh: rpm_release=${RPM_RELEASE}"
echo "build-istio-container-images.sh: kubectl_version=${KUBECTL_VERSION}"
echo "build-istio-container-images.sh: yum_repo=${YUM_REPO}"

if [[ -n "${YUM_REPO_CONFIG_DIR}" ]]; then
    echo "build-istio-container-images.sh: using yum repo config directory ${YUM_REPO_CONFIG_DIR}"
    if [[ ! -f "${YUM_REPO_CONFIG_DIR}/yum.conf" ]]; then
        echo "build-istio-container-images.sh: missing yum config file ${YUM_REPO_CONFIG_DIR}/yum.conf" >&2
        exit 1
    fi
    if [[ ! -d "${YUM_REPO_CONFIG_DIR}/yum.repos.d" ]]; then
        echo "build-istio-container-images.sh: missing yum repo directory ${YUM_REPO_CONFIG_DIR}/yum.repos.d" >&2
        exit 1
    fi
    shopt -s nullglob
    repo_files=("${YUM_REPO_CONFIG_DIR}"/yum.repos.d/*.repo)
    if [[ ${#repo_files[@]} -eq 0 ]]; then
        echo "build-istio-container-images.sh: no repo files found in ${YUM_REPO_CONFIG_DIR}/yum.repos.d" >&2
        exit 1
    fi
    echo "build-istio-container-images.sh: staging ${#repo_files[@]} repo file(s) into the build context for Dockerfile COPY commands"
    cp -f "${repo_files[@]}" ./
    shopt -u nullglob
else
    echo "build-istio-container-images.sh: no yum repo config directory provided"
fi

if [ -f "/etc/yum.repos.d/ol_artifacts.repo" ]; then
    cp /etc/yum.repos.d/ol_artifacts.repo ./
fi

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
        build_args=(
            --no-cache
            --pull
            --build-arg REPO_NAME=${YUM_REPO}
            --build-arg VERSION=${RPM_V}
            --build-arg KUBECTL_VERSION=${KUBECTL_VERSION}
            --build-arg ISTIO_VERSION=${RPM_VERSION}
            --build-arg http_proxy=${http_proxy}
            --build-arg https_proxy=${http_proxy}
            --tag ${REGISTRY}/${IMAGE_TAG}:${IMAGE_TAG_VERSION}
            --file ${DOCKER_FILE_PATH}
            .
        )
        if [[ -n "${YUM_REPO_CONFIG_DIR}" ]]; then
            build_args=(
                --volume "${YUM_REPO_CONFIG_DIR}/yum.conf:/etc/yum.conf:ro"
                --volume "${YUM_REPO_CONFIG_DIR}/yum.repos.d:/etc/yum.repos.d:ro"
                "${build_args[@]}"
            )
        fi
        echo "build-istio-container-images.sh: building image=${REGISTRY}/${IMAGE_TAG}:${IMAGE_TAG_VERSION} dockerfile=${DOCKER_FILE_PATH}"
        docker build "${build_args[@]}"

        echo "build-istio-container-images.sh: saving image=${REGISTRY}/${IMAGE_TAG}:${IMAGE_TAG_VERSION} to ${IMAGE_DIR}/${IMAGE_TAG}.tar"
        docker save \
            --output ${IMAGE_DIR}/${IMAGE_TAG}.tar ${REGISTRY}/${IMAGE_TAG}:${IMAGE_TAG_VERSION}
    fi
    count=$((count + 1))
done
