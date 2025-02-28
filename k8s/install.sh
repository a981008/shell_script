#!/bin/bash
set -e

# 定义 K8s Master 节点
declare -A MASTER_HOSTS=(
  ["k8s-master01"]="192.168.53.101"
  ["k8s-master02"]="192.168.53.102"
)

# 定义 ETCD 节点
declare -A ETCD_HOSTS=(
  ["k8s-etcd01"]="192.168.53.103"
  ["k8s-etcd02"]="192.168.53.104"
  ["k8s-etcd03"]="192.168.53.105"
)

# 定义 Node 节点
declare -A NODE_HOSTS=(
  ["k8s-node01"]="192.168.53.201"
)

PACKAGE_DIR="/opt/demo/k8s_package"
BIN_DIR="${PACKAGE_DIR}/bin"
IMAGES_DIR="${PACKAGE_DIR}/images"

REGISTRY_URL="192.168.53.100:8010"
IMAGE_PREFIX="myrepo"
REGISTRY_USERNAME="admin"
REGISTRY_PASSWORD="123456"

# 上传镜像
images_txt=${PACKAGE_DIR}/images.txt
#sh push_images.sh "${REGISTRY_USERNAME}" "${REGISTRY_PASSWORD}" "${REGISTRY_URL}" "${IMAGE_PREFIX}" "${images_txt}" "${IMAGES_DIR}"

for host in "${!MASTER_HOSTS[@]}"; do
  ip="${MASTER_HOSTS[$host]}"
#  # 0. 内核参数
#  ssh root@"$ip" "sh -s" < prepare_env.sh
#
#  # 1. 安装 docker
#  echo "Installing Docker on ${host} (${ip})..."
#  scp ${BIN_DIR}/docker root@"$ip":/usr/bin/
#  ssh root@"$ip" "sh -s" < install_docker.sh "$REGISTRY_URL"
#  echo "Docker installation completed on ${host} (${ip})"
#
#  # 2. 导入镜像
#  echo "Importing docker images on ${host} (${ip})..."
#  scp ${images_txt} root@"$ip":/tmp/images.txt
#  ssh root@"$ip" "sh -s" < pull_images.sh "${REGISTRY_USERNAME}" "${REGISTRY_PASSWORD}" "${REGISTRY_URL}" "/tmp/images.txt"

  # 3. 安装 cri-dockerd
  pause_image=$(cat /opt/demo/k8s_package/images.txt |grep pause)
  echo "Installing cri-dockerd on ${host} (${ip})..."
  scp ${BIN_DIR}/cri-dockerd root@"$ip":/usr/bin/
  ssh root@"$ip" "sh -s" < install_cri_dockerd.sh $pause_image
  echo "cri-dockerd installation completed on ${host} (${ip})"

  # 4. 安装 kubeadm, kubelet, kubectl
#  scp "${BIN_DIR}/kubeadm" root@"$ip":/usr/bin/
#  scp "${BIN_DIR}/kubelet" root@"$ip":/usr/bin/
#  scp "${BIN_DIR}/kubectl" root@"$ip":/usr/bin/
#  echo "kubeadm, kubelet, kubectl installation completed on ${host} (${ip})"

done
echo "All Master nodes have Docker installed."