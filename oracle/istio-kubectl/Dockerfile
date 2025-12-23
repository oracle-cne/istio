#
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#

FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG REPO_NAME
ARG KUBECTL_VERSION
# Image for post install jobs

COPY *.repo /etc/yum.repos.d/

# Install the latest kubectl
RUN microdnf install --enablerepo=${REPO_NAME} -y kubectl-${KUBECTL_VERSION}
RUN chmod +x /usr/bin/kubectl

# --------------------------------------------------------------------
# Second container to only ship what is needed for the service to run
FROM container-registry.oracle.com/os/oraclelinux:8-slim

COPY --from=0 /usr/bin/kubectl /usr/bin/kubectl

# Ensure a kubectl compatible with the container OS was used.  This is a safety
# measure to make sure even if this Dockerfile is changed we don't pick up OSX kubectl.
RUN /usr/bin/kubectl --help
