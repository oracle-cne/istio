#
# Copyright (c) 2021, 2022, Oracle and/or its affiliates. All rights reserved.
#
{{{$version := printf "%s.%s.%s" .major .minor .patch }}}
FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG VERSION
ARG APP_NAME=proxy
ARG REPO_NAME=ol8_addons

# Only need ca-certificates & openssl if want to use DNS over TLS (RFC 7858).
# binutils: Used for tool `ar` which gets the ca for a deb package
# tar is used for intaring files
# xz: Used to untar .xz files

RUN microdnf install -y ca-certificates binutils openssl tar xz gzip

COPY *.repo /etc/yum.repos.d/

RUN microdnf --enablerepo=${REPO_NAME} -y install istio-${VERSION} istio-pilot-agent-${VERSION} istio-${APP_NAME}-${VERSION}
RUN microdnf -y install iptables iproute

RUN test -d /LICENSES || ln -s /usr/share/licenses /LICENSES
ADD LICENSE /LICENSES/${APP_NAME}-${VERSION}/LICENSE
ADD THIRD_PARTY_LICENSES.txt /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt
ADD olm/SECURITY.md /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md

ADD oracle/common-istio/fetch_cacerts.sh fetch_cacerts.sh
RUN chmod +x fetch_cacerts.sh && ./fetch_cacerts.sh
RUN chmod 755 /usr/local/bin/envoy /usr/local/bin/pilot-agent

# --------------------------------------------------------------------
# Second container to only ship what is needed for the service to run
FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG VERSION
ARG APP_NAME=proxy
ARG proxy_version

ARG ISTIO_API_SHA=unknown
ARG ENVOY_SHA=unknown
LABEL istio-api-vcs-ref=$ISTIO_API_SHA \
    envoy-vcs-ref=$ENVOY_SHA

# All containers need a /tmp directory
RUN mkdir -p /tmp

WORKDIR /

COPY --from=0 /etc/ssl/certs /etc/ssl/certs
COPY --from=0 /LICENSES/${APP_NAME}-${VERSION}/LICENSE /LICENSES/${APP_NAME}-${VERSION}/LICENSE
COPY --from=0 /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt
COPY --from=0 /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md
# Install Envoy.
COPY --from=0 /usr/local/bin/envoy /usr/local/bin/envoy

# Environment variables indicating this proxy's version/capabilities as opaque string
ENV ISTIO_META_ISTIO_PROXY_VERSION "${VERSION}"
# Environment variable indicating the exact proxy sha - for debugging or version-specific configs
ENV ISTIO_META_ISTIO_PROXY_SHA "${VERSION}"
# Environment variable indicating the exact build, for debugging
ENV ISTIO_META_ISTIO_VERSION "${VERSION}"

COPY --from=0 /usr/local/bin/pilot-agent /usr/local/bin/pilot-agent

# Copy Proxy templates from pilot-agent
# Copy Envoy bootstrap templates from pilot-agent
COPY --from=0 /etc/pilot-agent/artifacts/envoy_bootstrap.json /var/lib/istio/envoy/envoy_bootstrap_tmpl.json
{{{- if semverCompare "<1.24.0" $version }}}
COPY --from=0 /etc/pilot-agent/artifacts/gcp_envoy_bootstrap.json /var/lib/istio/envoy/gcp_envoy_bootstrap_tmpl.json
{{{- end }}}
#COPY --from=0 /etc/pilot-agent/artifacts/metadata-exchange-filter.wasm /etc/istio/extensions/metadata-exchange-filter.wasm
#COPY --from=0 /etc/pilot-agent/artifacts/stats-filter.wasm /etc/istio/extensions/stats-filter.wasm

# Grab all the commands that the proxy needs to configure networking
# This includes a mess of libraries as well.  It's too complicated
# to figure out which exact libraries are required, so just bring
# them all.
COPY --from=0 /sbin/xtables-* /sbin/iptables* /sbin/ip6tables* /sbin/ip /sbin/
COPY --from=0 /usr/lib64/xtables/ /usr/lib64/xtables
COPY --from=0 /usr/lib64 /usr/lib64
COPY --from=0 /etc/iproute2 /etc/iproute2
RUN ln -s /sbin/xtables-nft-multi /sbin/xtables-multi

{{{- if semverCompare "<=1.17.1" $version }}}
# TODO: Remove this when OL7 support is deprecated
# iptables hack
RUN microdnf install yum
ADD oracle/common-istio/ol7.repo /etc/yum.repos.d/
ADD oracle/common-istio/iptables-switch /sbin/iptables-switch
RUN chmod +x /sbin/iptables-switch

RUN mkdir /ol7_root
RUN yum -y --installroot=/ol7_root --disablerepo=ol8_baseos_latest --disablerepo=ol8_appstream install iptables binutils

RUN unlink /sbin/ip6tables && \
        unlink /sbin/ip6tables-restore && \
        unlink /sbin/ip6tables-save && \
        unlink /sbin/iptables && \
        unlink /sbin/iptables-restore && \
        unlink /sbin/iptables-save

RUN ln -s /sbin/iptables-switch /sbin/ip6tables && \
        ln -s /sbin/iptables-switch /sbin/ip6tables-restore && \
        ln -s /sbin/iptables-switch /sbin/ip6tables-save && \
        ln -s /sbin/iptables-switch /sbin/iptables && \
        ln -s /sbin/iptables-switch /sbin/iptables-restore && \
        ln -s /sbin/iptables-switch /sbin/iptables-save
{{{- end }}}
# Grab the certs tar from the previous pod
COPY --from=0 ca-certificates.tgz /

# Sudoers used to allow tcpdump and other debug utilities.
RUN useradd -m --uid 1337 istio-proxy && \
    echo "istio-proxy ALL=NOPASSWD: ALL" >>/etc/sudoers && \
    chown -R istio-proxy /var/lib/istio

# The pilot-agent will bootstrap Envoy.
ENTRYPOINT ["/usr/local/bin/pilot-agent"]
