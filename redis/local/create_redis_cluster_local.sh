#!/bin/bash
REDISDIR=/opt/homebrew/opt/redis/
# 端口号
START_PORT=8000
END_PORT=8005
# 创建 Redis 配置目录
CLUSTERDIR=/Users/wang/demo/redis-cluster
# 创建 Redis 集群，需要 redis-cli version >= 5
REDISCLI=$REDISDIR/bin/redis-cli
# Redis 集群密码
PASSWORD=123456
IP=$(ifconfig en0 | grep "inet " | awk '{print $2}')
if [ -z "$IP" ]; then
	IP=$(ifconfig eth0 | grep "inet " | awk '{print $2}')
fi

# 检查端口号占用
for PORT in $(seq $START_PORT $END_PORT); do
  if ss -tuln | grep ":$PORT "; then
    echo "端口 $PORT 已被占用，创建 Redis 集群失败"
    exit 1
  fi
done

# 关闭所有 Redis 实例
stop_all_redis() {
  for PORT in $(seq $START_PORT $END_PORT); do
    echo "正在关闭 Redis 实例，端口: $PORT"
    $REDISCLI -p $PORT -a $PASSWORD shutdown
    if [ $? -eq 0 ]; then
      echo "Redis 实例 $PORT 已成功关闭。"
    else
      echo "关闭 Redis 实例 $PORT 失败。"
    fi
  done
}

# 检查 redis-cli 版本
check_rediscli_version() {
  REDISCLI_VERSION=$($REDISCLI --version | awk '/redis-cli/ {print $2}')
  REQUIRED_VERSION="5.0.0"
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$REDISCLI_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    return 1
  else
    return 0
  fi
}
rechek_rediscli_version() {
  while ! check_rediscli_version; do
    echo "错误: redis-cli 版本必须 >= 5.0.0"
    read -p "请重新输入 redis-cli 路径: " REDISCLI
    rechek_rediscli_version
  done
}

rechek_rediscli_version

# 创建目录
mkdir_cluster_dir() {
  if [ -d "$CLUSTERDIR" ]; then
    echo "目录 $CLUSTERDIR 已存在。"
    read -p "是否强制重建目录？(y/n): " choice
    case "$choice" in
    y | Y)
      echo "正在删除并重建目录 $CLUSTERDIR..."
      rm -rf "$CLUSTERDIR"
      mkdir -p "$CLUSTERDIR"
      echo "目录 $CLUSTERDIR 已重建。"
      ;;
    n | N)
      echo "保留现有目录 $CLUSTERDIR。创建集群终止。"
      exit 1
      ;;
    *)
      echo "无效选择，保留现有目录 $CLUSTERDIR。创建集群终止。"
      exit 1
      ;;
    esac
  else
    echo "正在创建目录 $CLUSTERDIR..."
    mkdir -p "$CLUSTERDIR"
    echo "目录 $CLUSTERDIR 已创建。"
  fi
}

mkdir_cluster_dir

# 创建 Redis 实例的配置文件
for PORT in $(seq $START_PORT $END_PORT); do
  mkdir -p $CLUSTERDIR/$PORT
  cat <<EOF >$CLUSTERDIR/$PORT/redis.conf
port $PORT
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
appendonly yes
dbfilename dump.rdb
dir $CLUSTERDIR/$PORT
logfile $CLUSTERDIR/$PORT/redis.log
protected-mode no
requirepass $PASSWORD
masterauth $PASSWORD
EOF
done

# 启动 Redis 实例
for PORT in $(seq $START_PORT $END_PORT); do
  $REDISDIR/bin/redis-server $CLUSTERDIR/$PORT/redis.conf &
done

# 等待实例启动
sleep 1

# 检查 Redis 实例是否成功启动
for PORT in $(seq $START_PORT $END_PORT); do
  if $REDISCLI -p $PORT -a $PASSWORD ping 2>/dev/null | grep -q PONG; then
    echo "端口为 $PORT 的 Redis 实例启动成功。"
  else
    echo "端口为 $PORT 的 Redis 实例启动失败。"
    stop_all_redis
    exit 1
  fi
done

# 构建节点列表
NODE_LIST=""
for PORT in $(seq $START_PORT $END_PORT); do
  NODE_LIST="$NODE_LIST $IP:$PORT"
done

# 创建 Redis 集群
echo "$REDISCLI -a $PASSWORD --cluster create $NODE_LIST --cluster-replicas 1"
yes "yes" | $REDISCLI -a $PASSWORD --cluster create $NODE_LIST --cluster-replicas 1 2>/dev/null

# 等待初始化完成
sleep 1

# 检查集群整体信息
$REDISCLI -p $START_PORT -a $PASSWORD cluster info 2>/dev/null | grep 'cluster_state:ok'
if [ $? -eq 0 ]; then
  echo "Redis 集群已成功创建！"
else
  echo "Redis 集群创建失败，请检查日志和配置。"
  exit 1
fi
