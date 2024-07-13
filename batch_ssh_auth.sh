#!/bin/bash

# 定义远程主机列表
HOSTS=(
  "root@192.168.100.10"
  "root@192.168.100.11"
  "root@192.168.100.12"
)

# 本地和远程的 SSH 密钥文件路径
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
TEMP_KEYS_FILE="/tmp/authorized_keys"
KNOWN_HOSTS_FILE="/tmp/known_hosts"

# SSH 选项
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# 在远程主机上创建 SSH 密钥对并收集公钥
generate_and_collect_keys() {
  >all_keys.pub # 创建或清空临时文件
  for host in "${HOSTS[@]}"; do
    echo "在 $host 上生成 SSH 密钥对..."
    ssh $SSH_OPTS "$host" "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"

    echo "从 $host 收集公钥..."
    ssh $SSH_OPTS "$host" "cat ~/.ssh/id_rsa.pub" >>all_keys.pub
  done
}

# 将收集到的公钥分发到所有远程主机
distribute_keys() {
  for host in "${HOSTS[@]}"; do
    echo "将公钥分发到 $host..."
    scp $SSH_OPTS all_keys.pub "$host:$TEMP_KEYS_FILE"
    ssh $SSH_OPTS "$host" "cat $TEMP_KEYS_FILE >> $AUTHORIZED_KEYS && rm $TEMP_KEYS_FILE"
  done
}

# 预先收集所有主机的公钥并添加到 known_hosts
collect_and_distribute_known_hosts() {
  >$KNOWN_HOSTS_FILE
  for host in "${HOSTS[@]}"; do
    host_ip=$(echo $host | cut -d'@' -f2)
    echo "收集 $host_ip 的主机密钥..."
    ssh-keyscan -H $host_ip >>$KNOWN_HOSTS_FILE
  done

  for host in "${HOSTS[@]}"; do
    echo "分发 known_hosts 到 $host..."
    scp $SSH_OPTS $KNOWN_HOSTS_FILE "$host:$KNOWN_HOSTS_FILE"
    ssh $SSH_OPTS "$host" "cat $KNOWN_HOSTS_FILE >> /root/.ssh/known_hosts && sort -u /root/.ssh/known_hosts -o /root/.ssh/known_hosts && rm $KNOWN_HOSTS_FILE"
  done
}

# 检查所有节点间的 SSH 连接
test_ssh_login() {
  for source_host in "${HOSTS[@]}"; do
    for target_host in "${HOSTS[@]}"; do
      echo "测试从 $source_host 到 $target_host 的 SSH 连接..."
      ssh $SSH_OPTS "$source_host" "ssh $SSH_OPTS $target_host 'echo 成功连接到 $target_host'"
    done
  done
}

echo "开始生成并收集公钥..."
generate_and_collect_keys

echo "开始分发公钥..."
distribute_keys
rm all_keys.pub

echo "开始收集并分发 known_hosts..."
collect_and_distribute_known_hosts
rm $KNOWN_HOSTS_FILE

echo "开始测试各个节点间的 SSH 连接..."
test_ssh_login
