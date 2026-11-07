#!/bin/bash -x
#
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#

WD=$(dirname "$0")
WD=$(
    cd "$WD"
    pwd
)

set -o errexit
set -o nounset
set -o pipefail

CA_CERTS=${WD}/ca-certificates.tgz

TMP_DIR=$(mktemp -d)
cd "${TMP_DIR}"

# Grab the bundle and rename to `etc/ssl/certs/ca-certificates.crt`
mkdir -p etc/ssl/certs
cp /etc/pki/tls/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt

# Tar it all up for this istio services
tar -czf "${CA_CERTS}" --owner=0 --group=0 etc/ssl/certs/ca-certificates.crt
