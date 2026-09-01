
# Generate devel rpm
%global with_devel 0
# Build with debug info rpm
%global with_debug 0
# Run unit tests
%global with_tests 0
# Build test binaries
%global with_test_binaries 0

%define _unpackaged_files_terminate_build 0

%if 0%{?with_debug}
%global _dwz_low_mem_die_limit 0
%else
%global debug_package   %{nil}
%endif

%ifarch %{arm} arm64 aarch64
%global custom_arch arm64
%else
%global custom_arch amd64
%endif
%global linux_arch linux_%{custom_arch}

%global import_path     istio.io/istio
%global istio_go_path   ISTIO
%global istio_go_src    %{istio_go_path}/src/%{import_path}
%global istio_go_bin    %{istio_go_src}/out/%{linux_arch}

# istio-cni-taint was removed since 1.18
%if "%{dist}" == ".el8"
%global binaries        pilot-discovery pilot-agent istioctl istio-cni install-cni
%else
%global binaries        istioctl
%endif

# Istio directories
%global istio_file_dir            %{_sysconfdir}/istio
%global istio_file_build_dir      %{buildroot}/%{istio_file_dir}
%global istio_artifact_file_dir   %{istio_file_dir}/artifacts
%global istio_artifact_build_dir  %{buildroot}/%{istio_artifact_file_dir}
# Istio-proxy directories
%global istio_pilot_artifact_file_dir  %{_sysconfdir}/pilot-agent/artifacts
%global istio_pilot_artifact_build_dir %{buildroot}/%{istio_pilot_artifact_file_dir}

# Use /usr/local as base dir, once upstream heavily depends on that
%global _prefix /usr/local

%global istio_version       1.31.0
%global istio_release       1%{?dist}
%global _buildhost          build-ol%{?oraclelinux}-%{?_arch}.oracle.com

Name:                       istio
Version:                    %{istio_version}
Release:                    %{istio_release}
Summary:                    An open platform to connect, manage, and secure microservices
License:                    ASL 2.0
Vendor:                     Oracle America
URL:                        https://github.com/istio/istio

Source0:                    %{name}-%{version}.tar.bz2
Source1:                    istiorc
Source2:                    buildinfo
Patch0:                     run.sh.patch
Patch3:                     setup_env.sh.patch
Patch4:                     egress-values_1.22.patch
Patch5:                     ingress-values_1.22.patch
Patch6:                     init.sh.patch
Patch7:                     Makefile.core.mk.patch
Patch8:                     gobuild.sh.patch

# If go_compiler is not set to 1, there is no virtual provide. Use golang instead.
BuildRequires:  golang
%if "%{dist}" == ".el9"
BuildRequires:  python
%else 
BuildRequires:  python2
%endif
BuildRequires:  hostname
BuildRequires:  helm

%if "%{dist}" == ".el8"
BuildRequires:  istio-proxy = %{version}
%endif

%if "%{dist}" == ".el7"
Obsoletes:                  istio-pilot-discovery
Obsoletes:                  istio-pilot-agent
%endif

%description
Istio is an open platform that provides a uniform way to connect, manage
and secure microservices. Istio supports managing traffic flows between
microservices, enforcing access policies, and aggregating telemetry data,
all without requiring changes to the microservice code.

########### pilot-discovery ###############
%package pilot-discovery
Summary:  The istio pilot discovery
Requires: istio = %{version}-%{release}

%description pilot-discovery
Istio is an open platform that provides a uniform way to connect, manage
and secure microservices. Istio supports managing traffic flows between
microservices, enforcing access policies, and aggregating telemetry data,
all without requiring changes to the microservice code.

This package contains the pilot-discovery program.

pilot-discovery is the main pilot component and belongs to Control Plane.

########### pilot-agent ###############
%package pilot-agent
Summary:  The istio pilot agent
Requires: istio = %{version}-%{release}

%description pilot-agent
Istio is an open platform that provides a uniform way to connect, manage
and secure microservices. Istio supports managing traffic flows between
microservices, enforcing access policies, and aggregating telemetry data,
all without requiring changes to the microservice code.

This package contains the pilot-agent program.

pilot-agent is agent that talks to Istio pilot. It belongs to Data Plane.
Along with Envoy, makes up the proxy that goes in the sidecar along with applications.

########### istioctl ###############
%package istioctl
Summary:  The istio command line tool
Requires: istio = %{version}-%{release}

%description istioctl
Istio is an open platform that provides a uniform way to connect, manage
and secure microservices. Istio supports managing traffic flows between
microservices, enforcing access policies, and aggregating telemetry data,
all without requiring changes to the microservice code.

This package contains the istioctl program.

istioctl is the configuration command line utility.
########### install-cni ###############
%package install-cni
Summary:  The install cni program
Requires: istio = %{version}-%{release}

%description install-cni
Istio is an open platform that provides a uniform way to connect, manage
and secure microservices. Istio supports managing traffic flows between
microservices, enforcing access policies, and aggregating telemetry data,
all without requiring changes to the microservice code.

This package contains the install-cni program.

install-cni injects the CNI plugin config to the CNI config file.

%if 0%{?with_test_binaries}

########### tests ###############
%package pilot-tests
Summary:  Istio Pilot Test Binaries
Requires: istio = %{version}-%{release}

%description pilot-tests
Istio is an open platform that provides a uniform way to connect, manage
and secure microservices. Istio supports managing traffic flows between
microservices, enforcing access policies, and aggregating telemetry data,
all without requiring changes to the microservice code.

This package contains the binaries needed for pilot tests.

%endif

%if 0%{?with_devel}
%package devel
Summary:       %{summary}
BuildArch:     noarch

%description devel
Istio is an open platform that provides a uniform way to connect, manage
and secure microservices. Istio supports managing traffic flows between
microservices, enforcing access policies, and aggregating telemetry data,
all without requiring changes to the microservice code.

This package contains library source intended for
building other packages which use import path with
%{import_path} prefix.
%endif

%prep
mkdir -p %{istio_go_src}
tar xf %{SOURCE0} -C %{istio_go_src} --strip=1
#proxy setup
mkdir -p %{istio_go_src}/ENVOY_BIN
# Move envoy to where istio expects it to be.  Stub this
# out for OL7 builds as envoy is only built for OL8
%if "%{dist}" == ".el8"
cp /usr/local/bin/envoy %{istio_go_src}/ENVOY_BIN/
cp %{SOURCE2} %{istio_go_src}/buildinfo
%else
touch %{istio_go_src}/ENVOY_BIN/envoy
%endif

# Apply run script patch to ensure that
# no invalid podman arguments are used
pushd %{istio_go_src}
%patch0
%if "%{dist}" == ".el7"
%patch3
%endif
%patch4
%patch5
popd

which python || ln -s /usr/bin/python2 /usr/bin/python

%build
pushd %{istio_go_path}
export GOPATH=$(pwd)
popd

pushd %{istio_go_src}

# NOTE: Since our build pipline uses 'git archive' to tar the repo for the rpm build process
# we have to fake out the git history so istio will not mark our project as dirty in the version cmd

# Remove git archive files
rm -rf HEAD
rm -rf FETCH_HEAD
# Commit all local changes to keep the project clean
git config --global user.email "o@oracle.com"
git config --global user.name "oracle"
# Fix for "detected dubious ownership in repository" error
git config --global --add safe.directory `pwd`
git init
git add .
git commit -a -m "Oracle Path Files"
git tag %{istio_version} -m 'Oracle Build'

# The following is for jenkins build failure
# fatal: unsafe repository ('/work' is owned by someone else)
git config --global --add safe.directory /work

# Istio vars to generate yaml
export REGISTRY="container-registry.oracle.com"
# This release is a tech preview so the default generated deploy yaml has to point to the developer namespace
export REGISTRY_NAMESPACE="olcne-developer"
export OUTPUT_BASE_DIR="oracle"
# Shared Arg between Istio build and generating istio deploy yaml
export ISTIO_VERSION=%{istio_version}
export VERSION=%{istio_version}
# Override Istio build Args to populate istioctl version cmd
export ISTIO_DOCKER_HUB=${REGISTRY}/${REGISTRY_NAMESPACE}
export BUILD_WITH_CONTAINER=0
# To consume Oracle built envoy binary instead of fetching from upstream
# For containerized builds, /work in the container corresponds to
# %{istio_go_src} on the host
if [ "$BUILD_WITH_CONTAINER" -eq 0  ];then
  export ISTIO_ENVOY_LOCAL=%{_builddir}/%{istio_go_src}/ENVOY_BIN
else
  export ISTIO_ENVOY_LOCAL=/work/ENVOY_BIN
fi
export ISTIO_ENVOY_LOCAL_PATH=${ISTIO_ENVOY_LOCAL}/envoy
export ISTIO_ENVOY_LINUX_RELEASE_DIR=${ISTIO_ENVOY_LOCAL}/
export ISTIO_ENVOY_LINUX_RELEASE_PATH=${ISTIO_ENVOY_LINUX_RELEASE_DIR}/envoy

# Use podman instead of Docker
export CONTAINER_CLI=podman
export DOCKER_SOCKET_MOUNT=" "
# Jenkins pipeline has DEBUG=false which clobbers the Makefile
# 1.18 - change build target from binaries to build-linux
make USE_LOCAL_PROXY=1 DEBUG=0 build-linux && echo "OK"

%if 0%{?with_test_binaries}
make DEBUG=0 test-bins
%endif

# Build istio deploy yaml
#NOTE: Commenting it as we are using olcne installer to deploy istio as a module
#chmod +x generate_istio_deploy_yaml.sh
#./generate_istio_deploy_yaml.sh

popd

%install
mkdir -p $RPM_BUILD_ROOT%{_bindir}
shopt -s dotglob
pushd %{istio_go_bin}
bins=(%{binaries})
%if 0%{?with_debug}
  for i in "${bins[@]}"; do
    cp -pav $i $RPM_BUILD_ROOT%{_bindir}/
  done
%else
  mkdir stripped
  for i in "${bins[@]}"; do
    echo stripping: $i
    strip -o stripped/$i -s $i
    cp -pav stripped/$i $RPM_BUILD_ROOT%{_bindir}/
  done
%endif

# Files used with pilot
%if "%{dist}" == ".el8"
install -d -p %{istio_pilot_artifact_build_dir}
install -d -p %{istio_artifact_build_dir}

install %{_builddir}/%{istio_go_src}/tools/packaging/common/envoy_bootstrap.json     %{istio_pilot_artifact_build_dir}
install %{_builddir}/%{istio_go_src}/tools/packaging/common/sidecar.env              %{istio_pilot_artifact_build_dir}
# Files used to deploy istio
#install %{_builddir}/%{istio_go_src}/generate_istio_deploy_yaml.sh                  %{istio_file_build_dir}
#install %{_builddir}/%{istio_go_src}/oracle/istio.yaml                              %{istio_artifact_build_dir}
#install %{_builddir}/%{istio_go_src}/oracle/istio-crds.yaml                         %{istio_artifact_build_dir}
%endif

%if 0%{?with_test_binaries}
cp -pav %{istio_go_bin}/{pilot-test-server,pilot-test-client,pilot-test-eurekamirror} $RPM_BUILD_ROOT%{_bindir}/
%endif

%if 0%{?with_tests}
%check
cd %{istio_go_path}
export GOPATH=$(pwd):%{gopath}
export GOPATH=$(pwd):$GOPATH
pushd %{istio_go_src}
make DEBUG=0 localTestEnv test
make DEBUG=0 localTestEnvCleanup
popd
%endif

# source codes for building projects
%if 0%{?with_devel}
install -d -p %{buildroot}/%{gopath}/src/%{import_path}/
echo "%%dir %%{gopath}/src/%%{import_path}/." >> devel.file-list
# find all *.go but no *_test.go files and generate devel.file-list
for file in $(find . \( -iname "*.go" -or -iname "*.s" \) \! -iname "*_test.go") ; do
    dirprefix=$(dirname $file)
    install -d -p %{buildroot}/%{gopath}/src/%{import_path}/$dirprefix
    cp -pav $file %{buildroot}/%{gopath}/src/%{import_path}/$file
    echo "%%{gopath}/src/%%{import_path}/$file" >> devel.file-list

    while [ "$dirprefix" != "." ]; do
        echo "%%dir %%{gopath}/src/%%{import_path}/$dirprefix" >> devel.file-list
        dirprefix=$(dirname $dirprefix)
    done
done
%endif

%if 0%{?with_devel}
sort -u -o devel.file-list devel.file-list
%endif

#define license tag if not already defined
%{!?_licensedir:%global license %doc}

%files
%license %{istio_go_src}/LICENSE %{istio_go_src}/THIRD_PARTY_LICENSES.txt
%doc     %{istio_go_src}/README.md
# Files used to deploy istio
#%{istio_artifact_file_dir}/istio-crds.yaml
#%{istio_artifact_file_dir}/istio.yaml
#%{istio_file_dir}/generate_istio_deploy_yaml.sh

%if "%{dist}" == ".el8"
%files pilot-discovery
%{_bindir}/pilot-discovery
%license %{istio_go_src}/LICENSE %{istio_go_src}/THIRD_PARTY_LICENSES.txt

%files pilot-agent
%{_bindir}/pilot-agent
# Files used with pilot
%{istio_pilot_artifact_file_dir}/envoy_bootstrap.json
%{istio_pilot_artifact_file_dir}/sidecar.env
%license %{istio_go_src}/LICENSE %{istio_go_src}/THIRD_PARTY_LICENSES.txt

# istio-cni-taint was removed since 1.18
%files install-cni
%{_bindir}/istio-cni
%{_bindir}/install-cni
%license %{istio_go_src}/LICENSE %{istio_go_src}/THIRD_PARTY_LICENSES.txt
%endif

%files istioctl
%{_bindir}/istioctl
%license %{istio_go_src}/LICENSE %{istio_go_src}/THIRD_PARTY_LICENSES.txt

%if 0%{?with_test_binaries}
%files pilot-tests
%{_bindir}/pilot-test-server
%{_bindir}/pilot-test-client
%{_bindir}/pilot-test-eurekamirror
%endif

%if 0%{?with_devel}
%files devel -f devel.file-list
%license %{istio_go_src}/LICENSE %{istio_go_src}/THIRD_PARTY_LICENSES.txt
%doc %{istio_go_src}/README.md %{istio_go_src}/DEV-*.md %{istio_go_src}/CONTRIBUTING.md
%dir %{gopath}/src/%{provider}.%{provider_tld}/%{project}
%endif

%clean
rm -fr %{buildroot}
rm -fr %{_builddir}/%{name}-%{version}

%changelog
* Tue Sep 01 2026 Oracle Cloud Native Environment Authors <noreply@oracle.com> - 1.31.0-1
- Added Oracle specific files for 1.31.0-1
