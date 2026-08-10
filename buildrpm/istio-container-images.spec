
%global kubectl             $(dnf list kubectl --showduplicates | grep kubectl | tail -1 | awk '{print substr($2, 1, length($2)-6)}')
%global debug_package       %{nil}
%global image_dir           bin/istio_images
%global istio_version       1.30.3
%global istio_release       1%{?dist}
%global kubectl_version     %{kubectl}
%global image_tag           %{istio_version}
%global _buildhost          build-ol%{?oraclelinux}-%{?_arch}.oracle.com

Name:                       istio-container-images
Version:                    %{istio_version}
Release:                    %{istio_release}
Summary:                    Istio(Connect, secure, control, and observe services) docker images
License:                    UPL
Source:                     %{name}-%{version}.tar.bz2
Vendor:                     Oracle America
BuildRequires:              rpm >= 4.11.3
BuildRequires:              ca-certificates
BuildRequires:              podman
BuildRequires:              bash

%prep
%setup -n %{name}-%{version}

%description
Istio is an open platform for providing a uniform way to integrate microservices,
manage traffic flow across microservices, enforce policies and aggregate telemetry data.
Istio's control plane provides an abstraction layer over the underlying cluster management platform,
such as Kubernetes, Mesos, etc.

%build
chmod +x ./oracle/build-istio-container-images.sh
./oracle/build-istio-container-images.sh \
    --image-dir %{image_dir} \
    --image-tag %{image_tag} \
    --rpm-release %{istio_release} \
    --rpm-version %{istio_version} \
    --kubectl-version %{kubectl_version}

%install
install -m 755 -d %{buildroot}/usr/local/share/istio
install -p -m 755 -t %{buildroot}/usr/local/share/istio %{image_dir}/pilot.tar
install -p -m 755 -t %{buildroot}/usr/local/share/istio %{image_dir}/proxyv2.tar
install -p -m 755 -t %{buildroot}/usr/local/share/istio %{image_dir}/istio_kubectl.tar
install -p -m 755 -t %{buildroot}/usr/local/share/istio %{image_dir}/install-cni.tar
install -p -m 755 -t %{buildroot}/usr/local/share/istio %{image_dir}/istio-istioctl.tar

%files
%license ./LICENSE ./THIRD_PARTY_LICENSES.txt olm/SECURITY.md
/usr/local/share/istio/pilot.tar
/usr/local/share/istio/proxyv2.tar
/usr/local/share/istio/istio_kubectl.tar
/usr/local/share/istio/install-cni.tar
/usr/local/share/istio/istio-istioctl.tar

%clean

%changelog
* Fri Jul 17 2026 Oracle Cloud Native Environment Authors <noreply@oracle.com> - 1.30.3-1
- Added Oracle specific files for 1.30.3
