#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 执行完脚本后，目录结构如下：
#/opt
#├── k8s_package
#│    ├── cri-dockerd-0.3.16.amd64.tgz
#│    ├── docker-28.0.1.tgz
#│    ├── etcd-v3.5.18-linux-amd64.tar.gz
#│    ├── images
#│    │    ├── flannel
#│    │    │    ├── flannel-cni-plugin:v1.6.2-flannel1.tar
#│    │    │    └── flannel:v0.26.4.tar
#│    │    └── registry.k8s.io
#│    │          ├── registry.k8s.io_coredns_coredns:v1.11.3.tar
#│    │          ├── registry.k8s.io_etcd:3.5.16-0.tar
#│    │          ├── registry.k8s.io_kube-apiserver:v1.32.2.tar
#│    │          ├── registry.k8s.io_kube-controller-manager:v1.32.2.tar
#│    │          ├── registry.k8s.io_kube-proxy:v1.32.2.tar
#│    │          ├── registry.k8s.io_kube-scheduler:v1.32.2.tar
#│    │          └── registry.k8s.io_pause:3.10.tar
#│    ├── kube-flannel.yml
#│    ├── kubeadm
#│    ├── kubectl
#│    └── kubelet
#└── k8s_package.tar.gz
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

DOWNLOAD_DIR="/opt/k8s_package"
OS="linux"
ARCH="amd64"

ETCD_VERSION="v3.5.18"
K8S_VERSION="1.32.0"
FLANNEL_VERSION="0.26.4"
DOCKER_VERSION="28.0.1"
CRI_DOCKERD_VERSION="0.3.16"

# Check if the directory exists, if not, create it
mkdir -p "${DOWNLOAD_DIR}/images/registry.k8s.io" "${DOWNLOAD_DIR}/images/flannel"

# Function to download and check for errors
download_file() {
  local url=$1
  local output_dir=$2
  echo "Downloading ${url}..."
  wget -q --show-progress -P "${output_dir}" "${url}"
  if [ $? -ne 0 ]; then
    echo "Error downloading ${url}. Exiting."
    exit 1
  fi
}

# Download etcd
ETCD_TARBALL="etcd-${ETCD_VERSION}-${OS}-${ARCH}.tar.gz"
ETCD_URL="https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/${ETCD_TARBALL}"
download_file "${ETCD_URL}" "${DOWNLOAD_DIR}"

# Download kubeadm, kubelet, kubectl
for bin in kubeadm kubelet kubectl; do
  download_file "https://dl.k8s.io/release/v${K8S_VERSION}/bin/${OS}/${ARCH}/${bin}" "${DOWNLOAD_DIR}"
  chmod +x "${DOWNLOAD_DIR}/${bin}"
done

# Download k8s images
image_list=$("${DOWNLOAD_DIR}/kubeadm" config images list)
for image in ${image_list}; do
  if [ -z "$image" ]; then
    continue
  fi
  echo "Pulling image: $image"
  docker pull "$image" && docker save -o "${DOWNLOAD_DIR}/images/registry.k8s.io/$(echo $image | tr / _).tar" "$image"
done

# Download flannel images
download_file "https://github.com/flannel-io/flannel/releases/download/v${FLANNEL_VERSION}/kube-flannel.yml" "${DOWNLOAD_DIR}"
for image in $(grep image "${DOWNLOAD_DIR}/kube-flannel.yml" | grep -v '#' | awk -F '/' '{print $NF}'); do
  echo "Pulling image: flannel/$image"
  docker pull "flannel/$image" && docker save -o "${DOWNLOAD_DIR}/images/flannel/$image.tar" "flannel/$image"
done

# Download Docker and cri-dockerd
ARCH_DOCKER="${ARCH}"
if [ "$ARCH" == "amd64" ]; then
  ARCH_DOCKER="x86_64"
fi
download_file "https://download.docker.com/${OS}/static/stable/${ARCH_DOCKER}/docker-${DOCKER_VERSION}.tgz" "${DOWNLOAD_DIR}"
download_file "https://github.com/Mirantis/cri-dockerd/releases/download/v${CRI_DOCKERD_VERSION}/cri-dockerd-${CRI_DOCKERD_VERSION}.${ARCH}.tgz" "${DOWNLOAD_DIR}"

tar -czvf "$DOWNLOAD_DIR.tar.gz" -C /opt k8s_package
echo "All downloads and pulls completed successfully."
