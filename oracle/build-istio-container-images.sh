#!/bin/bash -x
#
# Copyright (c) 2021-2025, Oracle and/or its affiliates. All rights reserved.
#

set -o errexit
set -o nounset
set -o pipefail

log() {
    echo "build-istio-container-images.sh: $*"
}

require_var() {
    local name="$1"
    local value="${!name:-}"

    log "checking required variable ${name}"
    if [[ -z "${value}" ]]; then
        log "required variable ${name} is not set" >&2
        exit 1
    fi
}

append_podman_build_args() {
    local raw_args="${PODMAN_BUILD_ARGS:-}"

    log "checking optional PODMAN_BUILD_ARGS"
    if [[ -z "${raw_args}" ]]; then
        log "PODMAN_BUILD_ARGS is not set"
        return
    fi

    log "using PODMAN_BUILD_ARGS: ${raw_args}"
    read -r -a podman_build_args <<< "${raw_args}"
}

has_yum_vars_mount() {
    local arg

    for arg in "${podman_build_args[@]}"; do
        if [[ "${arg}" == *":/etc/yum/vars"* ]]; then
            return 0
        fi
    done

    return 1
}

mount_yum_config() {
    local yum_repo_config_file="${YUM_REPO_CONFIG_FILE:-}"
    local yum_vars_dir="${YUM_VARS_DIR:-/etc/yum/vars}"

    log "starting yum repository configuration check"
    if [[ -z "${yum_repo_config_file}" && -s "/etc/yum.repos.d/ol_artifacts.repo" ]]; then
        yum_repo_config_file="/etc/yum.repos.d/ol_artifacts.repo"
        log "YUM_REPO_CONFIG_FILE is not set; using ${yum_repo_config_file}"
    fi

    if [[ -z "${yum_repo_config_file}" ]]; then
        log "YUM_REPO_CONFIG_FILE is not set; using base image repository configuration"
        return
    fi

    if [[ "${yum_repo_config_file}" != /* ]]; then
        yum_repo_config_file="$(pwd)/${yum_repo_config_file}"
    fi

    log "checking yum repo config file ${yum_repo_config_file}"
    if [[ ! -s "${yum_repo_config_file}" ]]; then
        log "yum repo config file ${yum_repo_config_file} is missing or empty" >&2
        exit 1
    fi

    log "mounting yum repo config file ${yum_repo_config_file}"
    podman_build_args=(
        --volume "${yum_repo_config_file}:/etc/yum.repos.d/extra.repo:ro"
        "${podman_build_args[@]}"
    )

    log "checking yum vars directory ${yum_vars_dir}"
    if [[ ! -d "${yum_vars_dir}" ]]; then
        log "yum vars directory ${yum_vars_dir} is not present; continuing without yum vars mount"
        return
    fi

    if has_yum_vars_mount; then
        log "yum vars mount already present in podman build args"
        return
    fi

    log "mounting yum vars directory ${yum_vars_dir}"
    podman_build_args=(
        --volume "${yum_vars_dir}:/etc/yum/vars:ro"
        "${podman_build_args[@]}"
    )
}

# please update this variable when adding a new arguments
TOTAL_CMD_ARGS=10

log "starting istio container image RPM build"

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

require_var IMAGE_DIR
require_var IMAGE_TAG_VERSION
require_var RPM_VERSION
require_var RPM_RELEASE
require_var KUBECTL_VERSION

RPM_V=${RPM_VERSION}-${RPM_RELEASE}
REGISTRY=container-registry.oracle.com/olcne
mkdir -p "${IMAGE_DIR}"

podman_build_args=()
append_podman_build_args
mount_yum_config

# Component that has generic container build command
CMP_TAGS=("pilot" "proxyv2" "istio_kubectl" "install-cni" "istio-istioctl")

count=0
for CMP in "${CMP_TAGS[@]}"; do
    DOCKER_FILE_PATH=./oracle/"${CMP/_/-}"/Dockerfile
    CUSTOM_BUILD_SCRIPT=./oracle/"${CMP/_/-}"/build-docker.sh
    IMAGE_TAG=${CMP_TAGS[count]}
    IMAGE_REF=${REGISTRY}/${IMAGE_TAG}:${IMAGE_TAG_VERSION}
    # Check if any customized script is available for building the container image
    # If so calling the script with two parameter( version and image tar file output directory)
    if [ -f "${CUSTOM_BUILD_SCRIPT}" ]; then
        log "starting custom build for ${IMAGE_TAG}"
        "${CUSTOM_BUILD_SCRIPT}" "${IMAGE_TAG_VERSION}" "${IMAGE_DIR}"
        log "completed custom build for ${IMAGE_TAG}"
    else
        log "starting build for ${IMAGE_REF}"
        log "using dockerfile ${DOCKER_FILE_PATH}"
        log "installing RPM version ${RPM_V}"
        podman build \
            --network=host \
            --no-cache \
            --pull \
            --build-arg "VERSION=${RPM_V}" \
            --build-arg "KUBECTL_VERSION=${KUBECTL_VERSION}" \
            --build-arg "ISTIO_VERSION=${RPM_VERSION}" \
            --build-arg "http_proxy=${http_proxy:-}" \
            --build-arg "https_proxy=${https_proxy:-${http_proxy:-}}" \
            "${podman_build_args[@]}" \
            --tag "${IMAGE_REF}" \
            --file "${DOCKER_FILE_PATH}" .

        log "saving ${IMAGE_REF} to ${IMAGE_DIR}/${IMAGE_TAG}.tar"
        podman save \
            --output "${IMAGE_DIR}/${IMAGE_TAG}.tar" "${IMAGE_REF}"
        log "completed build for ${IMAGE_REF}"
    fi
    count=$((count + 1))
done

log "completed istio container image RPM build"
