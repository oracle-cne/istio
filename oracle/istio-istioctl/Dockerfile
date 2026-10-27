#
# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
#

FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG ISTIO_VERSION
# Image for post install jobs

# Install the specific istioctl version
RUN microdnf install -y istio-istioctl-${ISTIO_VERSION}
RUN chmod +x /usr/local/bin/istioctl

# --------------------------------------------------------------------
# Second container to only ship what is needed for the service to run
FROM container-registry.oracle.com/os/oraclelinux:8-slim

COPY --from=0 /usr/local/bin/istioctl /usr/local/bin/istioctl

# Ensure a istioctl compatible with the container OS was used.  This is a safety
# measure to make sure even if this Dockerfile is changed we don't pick up OSX istioctl.
RUN /usr/local/bin/istioctl --help
