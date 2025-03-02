#!/bin/bash
set -e

# 定义 k8s Master 节点
MASTER_HOSTS=("k8s-master01" "k8s-master02")
MASTER_IPS=("192.168.53.101" "192.168.53.102")

# 定义 k8s Worker 节点
WORKER_HOSTS=("k8s-node01")
WORKER_IPS=("192.168.53.201")

# 定义 ETCD 节点
ETCD_HOSTS=("k8s-etcd01" "k8s-etcd02" "k8s-etcd03")
ETCD_IPS=("192.168.53.103" "192.168.53.104" "192.168.53.105")

# 定义 loader balancer 节点和虚拟 IP
LB_IPS=("192.168.53.101" "192.168.53.102")
LB_VIP="192.168.53.10"

PACKAGE_DIR="/opt/k8s_package"
BIN_DIR="${PACKAGE_DIR}/bin"
IMAGES_DIR="${PACKAGE_DIR}/images"

REGISTRY_URL="192.168.53.100:8010"
IMAGE_PREFIX="myrepo"
REGISTRY_USERNAME="admin"
REGISTRY_PASSWORD="123456"

bold_green_echo() {
  echo -e "\e[1;32m$1\e[0m"
}

# 搭建 etcd 集群

# 上传镜像
images_txt=${PACKAGE_DIR}/images.txt
sh push_images.sh "${REGISTRY_USERNAME}" "${REGISTRY_PASSWORD}" "${REGISTRY_URL}" "${IMAGE_PREFIX}" "${images_txt}" "${IMAGES_DIR}"

# master 和 worker 准备工作
names=("${MASTER_HOSTS[@]}" "${WORKER_HOSTS[@]}")
for i in "${!names[@]}"; do
  host="${names[$i]}"

  # 0. 内核参数
  ssh root@"$host" "sh -s" < prepare_env.sh
  bold_green_echo "Initialization of kernel parameters completed on ${host}"

  # 1. 安装 docker
  echo "Installing Docker on ${host} ..."
  scp ${BIN_DIR}/docker root@"$host":/usr/bin/
  ssh root@"$host" "sh -s" < install_docker.sh "$REGISTRY_URL"
  bold_green_echo "Docker installation completed on ${host}"

  # 2. 导入镜像
  echo "Importing docker images on ${host} ..."
  scp ${images_txt} root@"$host":/tmp/images.txt
  ssh root@"$host" "sh -s" < pull_images.sh "${REGISTRY_USERNAME}" "${REGISTRY_PASSWORD}" "${REGISTRY_URL}" "/tmp/images.txt"
  bold_green_echo "Docker import images completed on ${host}"

  # 3. 安装 cri-dockerd
  pause_image=$(cat /opt/demo/k8s_package/images.txt |grep pause)
  echo "Installing cri-dockerd on ${host} ..."
  scp ${BIN_DIR}/cri-dockerd root@"$host":/usr/bin/
  ssh root@"$host" "sh -s" < install_cri_dockerd.sh $pause_image
  bold_green_echo "cri-dockerd installation completed on ${host}"

  # 4. 安装 kubeadm, kubelet, kubectl
  scp "${BIN_DIR}/kubeadm" root@"$host":/usr/bin/
  scp "${BIN_DIR}/kubelet" root@"$host":/usr/bin/
  scp "${BIN_DIR}/kubectl" root@"$host":/usr/bin/
  ssh root@"$host" "sh -s" < install_kubelet.sh
  bold_green_echo "kubeadm, kubelet, kubectl installation completed on ${host}"
done

# Keepalived + HAProxy
for i in "${!LB_IPS[@]}"; do
  host="${LB_IPS[$i]}"

  scp ${BIN_DIR}/haproxy root@"$host":/usr/bin/
  ssh root@"$host" "sh -s" < install_haproxy.sh ${LB_VIP} ${MASTER_HOSTS}
  echo "Installing HAProxy on ${host} ..."

  scp ${BIN_DIR}/keepalived root@"$host":/usr/bin/
  ssh root@"$host" "sh -s" < install_keepalived.sh ${LB_VIP} "ens160"
  echo "Installing Keepalived on ${host} ..."
done

# 初始化 k8s
ssh root@"${MASTER_HOSTS[0]}" "sh -s" < init_k8s.sh ${LB_VIP}


# 加入 master

# 配置 CNI

# 加入 worker
