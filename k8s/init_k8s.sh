#!/bin/bash

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
LB_VIP="192.168.53.101"

PACKAGE_DIR="/opt/k8s_package"
BIN_DIR="${PACKAGE_DIR}/bin"
IMAGES_DIR="${PACKAGE_DIR}/images"

REGISTRY_URL="192.168.53.100:8010"
IMAGE_PREFIX="myrepo"
REGISTRY_USERNAME="admin"
REGISTRY_PASSWORD="123456"
PAUSE_IMAGE=192.168.53.100:8010/myrepo/pause:3.10

#set -e
cat > /var/lib/kubelet/kubeadm-flags.env << EOF
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///var/run/cri-dockerd.sock \
--pod-infra-container-image=${PAUSE_IMAGE}"
EOF

kubeadm init --kubernetes-version=1.32.2 \
--apiserver-advertise-address=192.168.53.101 \
--image-repository=192.168.53.100:8010/myrepo \
--upload-certs \
--ignore-preflight-errors=Swap \
--cri-socket=unix:///var/run/cri-dockerd.sock \
-v=9

