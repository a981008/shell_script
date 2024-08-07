#!/bin/bash
REDISDIR=/root/redis-6.0.17
# 端口号
START_PORT=8000
END_PORT=8005
# 创建 Redis 配置目录
CLUSTERDIR=$REDISDIR/redis-cluster
mkdir -p $CLUSTERDIR
REDISCLI=$REDISDIR/bin/redis-cli
# Redis 集群密码
PASSWORD=123456

# 创建 Redis 实例的配置文件
for PORT in $(seq $START_PORT $END_PORT); do
  mkdir -p $CLUSTERDIR/$PORT
  cat << EOF > $CLUSTERDIR/$PORT/redis.conf
port $PORT
appendonly yes
dbfilename dump.rdb
dir $CLUSTERDIR/$PORT
logfile $CLUSTERDIR/$PORT/redis.log
protected-mode no
requirepass 123456
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
EOF
done

# 检查端口号占用
for PORT in $(seq $START_PORT $END_PORT); do
  if ss -tuln | grep ":$PORT "; then
    echo "端口 $PORT 已被占用，创建 Redis 集群失败"
    exit 1
  fi
done

# 启动 Redis 实例
for PORT in $(seq $START_PORT $END_PORT); do
  $REDISDIR/bin/redis-server $CLUSTERDIR/$PORT/redis.conf &
done

# 等待实例启动
sleep 1

# 检查 Redis 实例是否成功启动
for PORT in $(seq $START_PORT $END_PORT); do
  if $REDISCLI -p $PORT -a $PASSWORD ping | grep -q PONG; then
    echo "端口为 $PORT 的 Redis 实例启动成功。"
  else
    echo "端口为 $PORT 的 Redis 实例启动失败。"

    # 关闭所有 Redis 实例
    for PORT in $(seq $START_PORT $END_PORT); do
      echo "正在关闭 Redis 实例，端口: $PORT"
      $REDISCLI -p $PORT -a $PASSWORD shutdown
      if [ $? -eq 0 ]; then
        echo "Redis 实例 $PORT 已成功关闭。"
      else
        echo "关闭 Redis 实例 $PORT 失败。"
      fi
    done

    exit 1
  fi
done