#
# Copyright (c) 2021, 2024, Oracle and/or its affiliates. All rights reserved.
#

FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG VERSION
ARG APP_NAME=pilot-discovery
ARG REPO_NAME=ol8_addons

COPY *.repo /etc/yum.repos.d/
RUN microdnf install -y --enablerepo=${REPO_NAME} istio-${VERSION} istio-${APP_NAME}-${VERSION}

RUN test -d /LICENSES || ln -s /usr/share/licenses /LICENSES
ADD LICENSE /LICENSES/${APP_NAME}-${VERSION}/LICENSE
ADD THIRD_PARTY_LICENSES.txt /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt
ADD olm/SECURITY.md /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md

# --------------------------------------------------------------------
# Second container to only ship what is needed for the service to run
FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG VERSION
ARG APP_NAME=pilot-discovery

COPY --from=0 /LICENSES/${APP_NAME}-${VERSION}/LICENSE /LICENSES/${APP_NAME}-${VERSION}/LICENSE
COPY --from=0 /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt
COPY --from=0 /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md
COPY --from=0 /usr/local/bin/pilot-discovery /usr/local/bin/pilot-discovery
COPY --from=0 /etc/pki/tls/cert.pem /etc/pki/tls/cert.pem
# Workaround for https://github.com/istio/istio/pull/5798
RUN /bin/ln -s /etc/pki/tls/cert.pem /cacert.pem

# All containers need a /tmp directory
RUN mkdir -p /tmp/
WORKDIR /

# "runAsUser: 1337" was removed in 1.20:
# https://linux-git.oraclecorp.com/OLCNE/istio/istio/-/blob/oracle/release/1.19.5/manifests/charts/istio-control/istio-discovery/templates/deployment.yaml#L191
USER 1337:1337

ENTRYPOINT [ "/usr/local/bin/pilot-discovery" ]
