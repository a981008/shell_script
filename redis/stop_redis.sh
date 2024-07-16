#!/bin/bash
# 默认 redis 安装目录
DEFAULT_REDISDIR=$HOME/redis-6.0.17
DEFAULT_PASSWORD=""
LOCAL_IP=$(hostname -I | awk '{print $1}')
DEFAULT_NODE_IP_PORTS="$LOCAL_IP:8000, $LOCAL_IP:8001, $LOCAL_IP:8002, $LOCAL_IP:8003, $LOCAL_IP:8004, $LOCAL_IP:8005"

echo "[关闭 Redis]"
# 用户输入
read -p "请输入 Redis 安装目录 (默认: $DEFAULT_REDISDIR): " REDISDIR
REDISDIR=${REDISDIR:-$DEFAULT_REDISDIR}
read -p "请输入 Redis 密码 (默认: 无密码): " PASSWORD
PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
read -p "请输入 Redis 节点 IP:PORT 列表 (以逗号分隔，格式: IP:PORT。默认为: $DEFAULT_NODE_IP_PORTS): " NODE_IP_PORTS
NODE_IP_PORTS=${NODE_IP_PORTS:-$DEFAULT_NODE_IP_PORTS}
IFS=',' read -r -a NODE_ARRAY <<< "$(echo $NODE_IP_PORTS | tr -d ' ')"

# 关闭所有 Redis 实例
for node in "${NODE_ARRAY[@]}"; do
  IFS=':' read -r -a node_parts <<<"$node"
  node_ip=${node_parts[0]}
  node_port=${node_parts[1]}
  $REDISDIR/bin/redis-cli -h $node_ip -p $node_port -a $PASSWORD --no-auth-warning shutdown
  if [ $? -eq 0 ]; then
    echo "关闭 Redis 实例 $node 成功。"
  else
    echo "关闭 Redis 实例 $node 失败。"
  fi
done
