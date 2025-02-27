#!/bin/bash

# 节点名称和 IP
CLUSTER_NAMES=("k8s-etcd01" "k8s-etcd02" "k8s-etcd03")
CLUSTER_IPS=("192.168.53.103" "192.168.53.104" "192.168.53.105")

# etcd 版本
ETCD_VERSION="v3.5.18"
ETCD_TARBALL="etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
ETCD_URL="https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/${ETCD_TARBALL}"
ETCD_DIR="/tmp/etcd-${ETCD_VERSION}-linux-amd64"

# etcd 相关配置
export ETCDCTL_API=3
CLUSTER_TOKEN="k8s-etcd-cluster"
DATADIR="/home/etcd/data"

# 1. 下载并解压 etcd
echo "Downloading etcd..."
wget -q -P /tmp "${ETCD_URL}"
tar -zxf "/tmp/${ETCD_TARBALL}" -C /tmp

# 2. 分发 etcd 二进制文件
echo "Distributing etcd binaries..."
for node in "${CLUSTER_IPS[@]}"; do
    scp ${ETCD_DIR}/etcd ${ETCD_DIR}/etcdctl ${ETCD_DIR}/etcdutl "$node:/usr/bin/"
done

# 3. 生成 etcd 集群启动参数
CLUSTER=""
for i in "${!CLUSTER_NAMES[@]}"; do
    CLUSTER+="${CLUSTER_NAMES[i]}=http://${CLUSTER_IPS[i]}:2380,"
done
CLUSTER=${CLUSTER%,}
echo "ETCD Cluster: ${CLUSTER}"

# 4. 远程配置并启动 etcd
for i in "${!CLUSTER_IPS[@]}"; do
    nodeip=${CLUSTER_IPS[i]}
    nodename=${CLUSTER_NAMES[i]}

    echo "Configuring etcd on ${nodeip}..."

    ssh -T "$nodeip" <<EOF
        set -e

        # 创建 etcd 用户（如不存在）
        if ! id etcd &>/dev/null; then
            sudo useradd -r -s /sbin/nologin etcd
        fi

        # 创建数据目录并修改权限
        sudo mkdir -p "${DATADIR}"
        sudo chown -R etcd:etcd "${DATADIR}"

        # 生成 systemd 配置
        sudo tee /etc/systemd/system/etcd.service > /dev/null <<SERVICE
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
Type=notify
User=etcd
ExecStart=/usr/bin/etcd \\
    --name "${nodename}" \\
    --data-dir "${DATADIR}" \\
    --initial-advertise-peer-urls "http://${nodeip}:2380" \\
    --listen-peer-urls "http://${nodeip}:2380" \\
    --advertise-client-urls "http://${nodeip}:2379" \\
    --listen-client-urls "http://${nodeip}:2379" \\
    --initial-cluster "${CLUSTER}" \\
    --initial-cluster-state new \\
    --initial-cluster-token "${CLUSTER_TOKEN}"
ExecStop=/bin/bash -c 'kill -SIGTERM $(pgrep -f "/usr/bin/etcd")'

Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

        # 重新加载 systemd 并启动 etcd
        sudo systemctl daemon-reload
        sudo systemctl enable --now etcd
        sudo systemctl status etcd --no-pager || true
EOF
done

# 5. 检查 etcd 集群状态
echo "Checking etcd cluster health..."
ETCDCTL_API=3 ${ETCD_DIR}/etcdctl endpoint health --endpoints=$(IFS=,; echo "${CLUSTER_IPS[*]/%/:2379}")

# 6. 清理临时文件
rm -rf "${ETCD_DIR}" "/tmp/${ETCD_TARBALL}"