#!/bin/bash

# 默认 redis 安装目录
DEFAULT_REDISDIR=/root/redis-6.0.17
DEFAULT_PASSWORD=""
DEFAULT_CLUSTERDIR=$DEFAULT_REDISDIR/cluster
LOCAL_IP=$(hostname -I | tr -d ' ')
DEFAULT_NODE_IP_PORTS="$LOCAL_IP:8000, $LOCAL_IP:8001, $LOCAL_IP:8002, $LOCAL_IP:8003, $LOCAL_IP:8004, $LOCAL_IP:8005"
REDISCLI=$DEFAULT_REDISDIR/bin/redis-cli

echo "[创建 Redis 集群]"
# 用户输入
read -p "请输入 Redis 安装目录 (默认: $DEFAULT_REDISDIR): " REDISDIR
REDISDIR=${REDISDIR:-$DEFAULT_REDISDIR}
read -p "请输入 Redis 存放数据目录 (默认: $DEFAULT_CLUSTERDIR)，用以存放 Redis 持久化数据、日志以及配置文件: " CLUSTERDIR
CLUSTERDIR=${CLUSTERDIR:-$DEFAULT_CLUSTERDIR}
read -p "请输入 Redis 密码 (默认: 无密码): " PASSWORD
PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
read -p "请输入 Redis 节点 IP:PORT 列表 (以逗号分隔，格式: IP:PORT。默认为: $DEFAULT_NODE_IP_PORTS): " NODE_IP_PORTS
NODE_IP_PORTS=${PASSWORD:-$DEFAULT_NODE_IP_PORTS}

# 将 IP:PORT 转换为数组
IFS=',' read -r -a NODE_ARRAY <<< "$(echo $NODE_IP_PORTS | tr -d ' ')"

# 检查端口是否被占用
check_port_availability() {
  local node_ip=$1
  local node_port=$2
  if ssh "$node_ip" "ss -tuln | grep ':$node_port '" >/dev/null 2>&1; then
    echo "节点 $node_ip 端口 $node_port 已被占用，创建 Redis 集群失败"
    exit 1
  fi
}

# 停止所有 Redis 实例
stop_all_redis() {
  local node_ip=$1
  local node_port=$2
  echo "正在关闭节点 $node_ip Redis 实例，端口: $node_port"
  ssh "$node_ip" "$REDISCLI -p $node_port -a $PASSWORD shutdown"
  if [ $? -eq 0 ]; then
    echo "节点 $node_ip Redis 实例 $node_port 已成功关闭。"
  else
    echo "关闭节点 $node_ip Redis 实例 $node_port 失败。"
  fi
}

# 创建 Redis 集群配置目录
create_cluster_dir() {
  local node_ip=$1
  local node_port=$2
  if ssh "$node_ip" "[ -d $CLUSTERDIR/$node_port ]"; then
    read -p "目录 $CLUSTERDIR/$node_port 已存在。是否强制重建目录？(y/n): " choice
    choice=${choice:-y}
    case "$choice" in
    y | Y)
      echo "正在删除并重建目录 $CLUSTERDIR/$node_port 在节点 $node_ip..."
      ssh "$node_ip" "rm -rf $CLUSTERDIR/$node_port && mkdir -p $CLUSTERDIR/$node_port"
      echo "目录 $CLUSTERDIR/$node_port 已在节点 $node_ip 重建。"
      ;;
    n | N)
      echo "保留现有目录 $CLUSTERDIR/$node_port 在节点 $node_ip。创建集群终止。"
      exit 1
      ;;
    *)
      echo "无效选择，保留现有目录 $CLUSTERDIR/$node_port 在节点 $node_ip。创建集群终止。"
      exit 1
      ;;
    esac
  else
    echo "正在创建目录 $CLUSTERDIR 在节点 $node_ip..."
    ssh "$node_ip" "mkdir -p $CLUSTERDIR"
    echo "目录 $CLUSTERDIR 已在节点 $node_ip 创建。"
  fi
}

# 创建 Redis 实例的配置文件
create_redis_conf() {
  local node_ip=$1
  local node_port=$2
  ssh "$node_ip" "mkdir -p $CLUSTERDIR/$node_port"
  ssh "$node_ip" "cat > $CLUSTERDIR/$node_port/redis.conf" <<EOF
port $node_port
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
appendonly yes
dbfilename dump.rdb
dir $CLUSTERDIR/$node_port
logfile $CLUSTERDIR/$node_port/redis.log
protected-mode no
daemonize yes
EOF
  # 如果设置了密码，则添加 requirepass 和 masterauth
  if [ -n "$PASSWORD" ]; then
    ssh "$node_ip" "echo 'requirepass $PASSWORD' >> $CLUSTERDIR/$node_port/redis.conf"
    ssh "$node_ip" "echo 'masterauth $PASSWORD' >> $CLUSTERDIR/$node_port/redis.conf"
  fi
}

# 启动 Redis 实例
start_redis_instance() {
  local node_ip=$1
  local node_port=$2
  ssh "$node_ip" "$REDISDIR/bin/redis-server $CLUSTERDIR/$node_port/redis.conf"
}

# 检查 Redis 实例是否成功启动
check_redis_instance() {
  local node_ip=$1
  local node_port=$2
  if [ -n "$PASSWORD" ]; then
    PING_CMD="$REDISCLI -h $node_ip -p $node_port -a $PASSWORD --no-auth-warning ping"
  else
    PING_CMD="$REDISCLI -h $node_ip -p $node_port ping"
  fi

  if ssh "$node_ip" "$PING_CMD" | grep -q PONG; then
    echo "节点 $node_ip 端口为 $node_port 的 Redis 实例启动成功。"
  else
    echo "节点 $node_ip 端口为 $node_port 的 Redis 实例启动失败。"
    stop_all_redis $node_ip $node_port
    exit 1
  fi
}

# 构建节点列表
NODE_LIST=""
for node in "${NODE_ARRAY[@]}"; do
  IFS=':' read -r -a node_parts <<<"$node"
  node_ip=${node_parts[0]}
  node_port=${node_parts[1]}
  NODE_LIST="$NODE_LIST $node_ip:$node_port"
done

# 同步机制：创建标志文件并检查是否所有节点都已完成该步骤
create_flag() {
  local node_ip=$1
  local step=$2
  ssh "$node_ip" "touch /tmp/${step}_completed"
}

check_all_flags() {
  local step=$1
  for node in "${NODE_ARRAY[@]}"; do
    IFS=':' read -r -a node_parts <<<"$node"
    node_ip=${node_parts[0]}
    while ! ssh "$node_ip" "[ -f /tmp/${step}_completed ]"; do
      echo "等待节点 $node_ip 完成步骤 $step..."
      sleep 0.5
    done
  done
}

# 初始化集群
initialize_cluster() {
  for node in "${NODE_ARRAY[@]}"; do
    IFS=':' read -r -a node_parts <<<"$node"
    node_ip=${node_parts[0]}
    node_port=${node_parts[1]}
    check_port_availability $node_ip $node_port
    create_flag $node_ip "check_port_availability"
  done
  check_all_flags "check_port_availability"

  for node in "${NODE_ARRAY[@]}"; do
    IFS=':' read -r -a node_parts <<<"$node"
    node_ip=${node_parts[0]}
    node_port=${node_parts[1]}
    create_cluster_dir $node_ip $node_port
    create_redis_conf $node_ip $node_port
    start_redis_instance $node_ip $node_port
    create_flag $node_ip "start_redis_instance"
  done
  check_all_flags "start_redis_instance"

  sleep 1

  for node in "${NODE_ARRAY[@]}"; do
    IFS=':' read -r -a node_parts <<<"$node"
    node_ip=${node_parts[0]}
    node_port=${node_parts[1]}
    check_redis_instance $node_ip $node_port
    create_flag $node_ip "check_redis_instance"
  done
  check_all_flags "check_redis_instance"
}

# 创建 Redis 集群
create_redis_cluster() {
  echo "初始化 Redis 集群。"
  if [ -n "$PASSWORD" ]; then
    yes "yes" | $REDISCLI -a "$PASSWORD" --no-auth-warning --cluster create $NODE_LIST --cluster-replicas 1
  else
    yes "yes" | $REDISCLI --cluster create $NODE_LIST --cluster-replicas 1
  fi
}

# 执行集群初始化和创建
initialize_cluster
create_redis_cluster

# 等待初始化完成
sleep 3

# 检查集群整体信息
IFS=':' read -r -a node_parts <<<"${NODE_ARRAY[0]}"
node_ip=${node_parts[0]}
node_port=${node_parts[1]}

if [ -n "$PASSWORD" ]; then
  CLUSTER_INFO_CMD="$REDISCLI -h $node_ip -p $node_port -a $PASSWORD --no-auth-warning cluster info"
else
  CLUSTER_INFO_CMD="$REDISCLI -h $node_ip -p $node_port cluster info"
fi

if $CLUSTER_INFO_CMD | grep -q 'cluster_state:ok'; then
  echo "Redis 集群已成功创建！"
else
  echo "Redis 集群创建失败，请检查日志和配置。"
  exit 1
fi
