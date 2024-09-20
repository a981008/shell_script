#!/bin/bash

# 定义远程主机列表
unset HOSTS
declare -A HOSTS=(
  ["root@192.168.100.10"]="981008"
  ["root@192.168.100.11"]="981008"
  ["root@192.168.100.12"]="981008"
)

# 本地和远程的 SSH 密钥文件路径
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
TEMP_AUTHORIZED_KEYS="/tmp/authorized_keys"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
TMP_KNOWN_HOSTS="$HOME/tmp/known_hosts"

if ! command -v expect &> /dev/null; then
    echo "expect 未安装"
    exit 1
fi

auto_ssh_passwd() {
  local CMD=$1
  local PASSWORD=$2
  expect -c "
spawn $CMD
expect {
  \"yes/no\" {send \"yes\r\";exp_continue}
  \"password:\" {send \"$PASSWORD\r\";exp_continue}
  \"(y/n)\" {send \"y\r\"}
}
interact
"
}

# 在远程主机上创建 SSH 密钥对并收集公钥
generate_and_collect_keys() {
  >all_keys.pub # 创建或清空临时文件
  for host in "${!HOSTS[@]}"; do
    echo "在 ${host} 上生成 SSH 密钥对..."
    auto_ssh_passwd "ssh ${host} \"ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa\"" ${HOSTS[${host}]} >/dev/null 2>&1

    echo "从 ${host} 收集公钥..."
    auto_ssh_passwd "ssh ${host} \"cat ~/.ssh/id_rsa.pub\" " ${HOSTS[${host}]} 2>/dev/null | grep ssh-rsa >>all_keys.pub
  done
}

# 将收集到的公钥分发到所有远程主机
distribute_keys() {
  for host in "${!HOSTS[@]}"; do
    echo "将公钥分发到 ${host}..."
    auto_ssh_passwd "scp all_keys.pub ${host}:$TEMP_AUTHORIZED_KEYS" ${HOSTS[${host}]} >/dev/null 2>&1
    auto_ssh_passwd "ssh ${host} \"cat $TEMP_AUTHORIZED_KEYS >> $AUTHORIZED_KEYS && rm $TEMP_AUTHORIZED_KEYS\"" ${HOSTS[${host}]} >/dev/null 2>&1
  done
}

# 添加到 known_hosts
add_known_hosts() {
  for source in "${!HOSTS[@]}"; do
    for target in "${!HOSTS[@]}"; do
      host_ip=$(echo ${target} | cut -d'@' -f2)
      echo "将 ${target} 添加到 ${source} 的 known_hosts 中..."
      ssh ${source} " ssh-keyscan -H ${host_ip} >> $KNOWN_HOSTS && sort $KNOWN_HOSTS | uniq > ${TMP_KNOWN_HOSTS} && mv ${TMP_KNOWN_HOSTS} ${KNOWN_HOSTS}" >/dev/null 2>&1
    done
  done
}

# 检查所有节点间的 SSH 连接
test_ssh_login() {
  for source_host in "${!HOSTS[@]}"; do
    for target_host in "${!HOSTS[@]}"; do
      echo "测试从 ${source_host} 到 ${target_host} 的 SSH 连接..."
      ssh ${source_host} "ssh ${SSH_OPTS} ${target_host} 'echo 从 ${source_host} 到 ${target_host} 连接成功'"
    done
  done
}

generate_and_collect_keys
distribute_keys
add_known_hosts
test_ssh_login
