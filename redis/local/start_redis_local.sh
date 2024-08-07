#!/bin/bash
REDISDIR=/opt/homebrew/opt/redis/
# 端口号
START_PORT=8000
END_PORT=8005
# 创建 Redis 配置目录
CLUSTERDIR=/Users/wang/demo/redis-cluster

for PORT in $(seq $START_PORT $END_PORT); do
  $REDISDIR/bin/redis-server $CLUSTERDIR/$PORT/redis.conf &
done