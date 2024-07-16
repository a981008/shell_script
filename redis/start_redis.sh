#!/bin/bash
# 默认 redis 安装目录
DEFAULT_REDISDIR=$HOME/redis-6.0.17
DEFAULT_CLUSTERDIR=$DEFAULT_REDISDIR/cluster
LOCAL_IP=$(hostname -I | awk '{print $1}')
DEFAULT_NODE_IP_PORTS="$LOCAL_IP:8000, $LOCAL_IP:8001, $LOCAL_IP:8002, $LOCAL_IP:8003, $LOCAL_IP:8004, $LOCAL_IP:8005"

echo "[开启 Redis]"
# 用户输入
read -p "请输入 Redis 安装目录 (默认: $DEFAULT_REDISDIR): " REDISDIR
REDISDIR=${REDISDIR:-$DEFAULT_REDISDIR}
REDISCLI=$REDISDIR/bin/redis-cli
read -p "请输入 Redis 存放数据目录 (默认: $DEFAULT_CLUSTERDIR)，用以存放 Redis 持久化数据、日志以及配置文件: " CLUSTERDIR
CLUSTERDIR=${CLUSTERDIR:-$DEFAULT_CLUSTERDIR}
read -p "请输入 Redis 节点 IP:PORT 列表 (以逗号分隔，格式: IP:PORT。默认为: $DEFAULT_NODE_IP_PORTS): " NODE_IP_PORTS
NODE_IP_PORTS=${NODE_IP_PORTS:-$DEFAULT_NODE_IP_PORTS}
IFS=',' read -r -a NODE_ARRAY <<<"$(echo $NODE_IP_PORTS | tr -d ' ')"

for node in "${NODE_ARRAY[@]}"; do
  IFS=':' read -r -a node_parts <<<"$node"
  node_ip=${node_parts[0]}
  node_port=${node_parts[1]}
  file_path=$CLUSTERDIR/$node_port/redis.conf
  # 启动实例
  ssh "$node_ip" "$REDISDIR/bin/redis-server $file_path"

  # 从配置文件中获取密码
  grep -v '^\s*#' "$file_path" | grep 'requirepass' | while IFS= read -r line; do
    password=$(echo $line | awk '{print $2}')
    # 检查实例是否启动成功
    if [ -n "$password" ]; then
      PING_CMD="$REDISCLI -h $node_ip -p $node_port -a $password --no-auth-warning ping"
    else
      PING_CMD="$REDISCLI -h $node_ip -p $node_port ping"
    fi
    if $PING_CMD | grep -q PONG; then
    echo "节点 $node_ip 端口为 $node_port 的 Redis 实例启动成功。"
  fi
  done
done
