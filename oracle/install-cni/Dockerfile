#
# Copyright (c) 2022, 2023, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG VERSION
ARG APP_NAME=install-cni

RUN microdnf install -y istio-${VERSION} istio-${APP_NAME}-${VERSION}

RUN test -d /LICENSES || ln -s /usr/share/licenses /LICENSES
ADD LICENSE /LICENSES/${APP_NAME}-${VERSION}/LICENSE
ADD THIRD_PARTY_LICENSES.txt /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt
ADD olm/SECURITY.md /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md

# --------------------------------------------------------------------
# Second container to only ship what is needed for the service to run
FROM container-registry.oracle.com/os/oraclelinux:8-slim

ARG VERSION
ARG APP_NAME=install-cni

COPY --from=0 /LICENSES/${APP_NAME}-${VERSION}/LICENSE /LICENSES/${APP_NAME}-${VERSION}/LICENSE
COPY --from=0 /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt /LICENSES/${APP_NAME}-${VERSION}/THIRD_PARTY_LICENSES.txt
COPY --from=0 /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md /SECURITY/${APP_NAME}-${VERSION}/SECURITY.md
COPY --from=0 /usr/local/bin/istio-cni /opt/cni/bin/istio-cni
COPY --from=0 /usr/local/bin/install-cni /usr/local/bin/install-cni

RUN microdnf install -y iptables iproute libibverbs && \
    microdnf clean all && \
    rm -rf /var/cache/yum

# Sudoers used to allow tcpdump and other debug utilities.
RUN useradd -m --uid 1337 istio-proxy && \
  echo "istio-proxy ALL=NOPASSWD: ALL" >> /etc/sudoers

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/cni/bin
WORKDIR /opt/cni/bin
CMD ["/usr/local/bin/install-cni"]
