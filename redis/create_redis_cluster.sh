#!/bin/bash

# 默认 redis 安装目录
DEFAULT_REDISDIR=$HOME/redis-3.2.1
DEFAULT_PASSWORD=""
DEFAULT_CLUSTERDIR=$DEFAULT_REDISDIR/cluster
LOCAL_IP=$(hostname -I | awk '{print $1}')
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
NODE_IP_PORTS=${NODE_IP_PORTS:-$DEFAULT_NODE_IP_PORTS}

# 将 IP:PORT 转换为数组
IFS=',' read -r -a NODE_ARRAY <<<"$(echo $NODE_IP_PORTS | tr -d ' ')"

check_rediscli_version() {
  REDISCLI_VERSION=$($REDISCLI --version | awk '/redis-cli/ {print $2}')
  REQUIRED_VERSION="5.0.0"
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$REDISCLI_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
    return 0
  else
    return 1
  fi
}

#recheck_rediscli_version() {
#  while ! check_rediscli_version; do
#    echo "错误: redis-cli 版本必须 >= 5.0.0"
#    read -p "请重新输入 redis-cli 路径 (如: /root/redis-6.0.17/bin/redis-cli): " REDISCLI
#  done
#}
#recheck_rediscli_version

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
    echo "关闭节点 $node_ip Redis 实例 $node_port 成功。"
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
    echo "正在创建目录 $CLUSTERDIR/$node_port 在节点 $node_ip..."
    ssh "$node_ip" "mkdir -p $CLUSTERDIR/$node_port"
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

  if $PING_CMD | grep -q PONG; then
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

# 创建 Redis 实例
create_redis_instance() {
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
  if ! check_rediscli_version; then
    create_redis_cluster_old
  else
    echo "创建 Redis 集群。"
    if [ -n "$PASSWORD" ]; then
      yes "yes" | $REDISCLI -a "$PASSWORD" --no-auth-warning --cluster create $NODE_LIST --cluster-replicas 1
    else
      yes "yes" | $REDISCLI --cluster create $NODE_LIST --cluster-replicas 1
    fi
  fi
}

clusert_meet() {
  length=${#NODE_ARRAY[@]}
  IFS=':' read -r -a node_0_parts <<<"${NODE_ARRAY[0]}"
  node_0_ip=${node_0_parts[0]}
  node_0_port=${node_0_parts[1]}

  for ((i = 0; i < length; i++)); do
    node=${NODE_ARRAY[$i]}
    IFS=':' read -r -a node_parts <<<"$node"
    node_ip=${node_parts[0]}
    node_port=${node_parts[1]}
    if [ -n "$PASSWORD" ]; then
      CMD="$REDISCLI -h $node_0_ip -p $node_0_port -a $PASSWORD --no-auth-warning cluster meet $node_ip $node_port"
    else
      CMD="$REDISCLI -h $node_0_ip -p $node_0_port cluster meet $node_ip $node_port"
    fi

    if $CMD | grep -q 'OK'; then
      echo "节点 $node 加入集群成功。"
    fi
  done
}
cluster_addslots() {
  length=$((${#NODE_ARRAY[@]} / 2))
  total_slots=16384
  slots_per_node=$(($total_slots / $length))
  start_slot=0

  for ((i = 0; i < length; i++)); do
    node=${NODE_ARRAY[$i]}
    IFS=':' read -r -a node_parts <<<"$node"
    node_ip=${node_parts[0]}
    node_port=${node_parts[1]}

    end_slot=$((start_slot + slots_per_node - 1))

    if [ $node == ${NODE_ARRAY[$length - 1]} ]; then
      # 确保最后一个节点分配到剩余的所有 slots
      end_slot=$((total_slots - 1))
    fi

    # 执行 slots 分配
    seq=$(seq $start_slot $end_slot)
    if [ -n "$PASSWORD" ]; then
      CMD="$REDISCLI -h $node_ip -p $node_port -a $PASSWORD --no-auth-warning cluster addslots $seq"
    else
      CMD="$REDISCLI -h $node_ip -p $node_port cluster addslots $seq"
    fi
    if $CMD | grep -q 'OK'; then
      echo "节点 $node 分配哈希槽 {$start_slot ... $end_slot} 成功。"
    fi
    start_slot=$((end_slot + 1))
  done
}

cluster_replicate() {
  length=${#NODE_ARRAY[@]}/2

  for ((i = 0; i < length; i++)); do

    master_node=${NODE_ARRAY[$i]}
    IFS=':' read -r -a master_node_parts <<<"$master_node"
    master_node_ip=${master_node_parts[0]}
    master_node_port=${master_node_parts[1]}

    slave_node=${NODE_ARRAY[$i + $length]}
    IFS=':' read -r -a slave_node_parts <<<"$slave_node"
    slave_node_ip=${slave_node_parts[0]}
    slave_node_port=${slave_node_parts[1]}

    if [ -n "$PASSWORD" ]; then
      nodes_info=$($REDISCLI -h $master_node_ip -p $master_node_port -a $PASSWORD --no-auth-warning cluster nodes)
      myid=$(echo "$nodes_info" | grep "$master_node_ip:$master_node_port" | awk '{print $1}')
      CMD="$REDISCLI -h $slave_node_ip -p $slave_node_port -a $PASSWORD --no-auth-warning cluster replicate $myid"
    else
      nodes_info=$($REDISCLI -h $master_node_ip -p $master_node_port cluster nodes)
      myid=$(echo "$nodes_info" | grep "$master_node_ip:$master_node_port" | awk '{print $1}')
      CMD="$REDISCLI -h $slave_node_ip -p $slave_node_port cluster replicate $myid"
    fi
    if $CMD | grep -q 'OK'; then
      echo "节点 $slave_node 跟随 $master_node 成功。"
    fi
  done
}

create_redis_cluster_old() {
  echo "创建 Redis 集群，redis-cli version < 5.0.0"
  # 节点加入集群
  clusert_meet
  sleep 1
  # 分配哈希槽
  cluster_addslots
  sleep 1
  # 从跟随主节点
  cluster_replicate
  sleep 5
}

# 执行集群初始化和创建
create_redis_instance
create_redis_cluster

# 等待集群初始化完成
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
