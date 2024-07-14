#!/bin/bash
REDISDIR=/root/redis-3.2.1
# 端口号
START_PORT=8000
END_PORT=8005

# 关闭所有 Redis 实例
for PORT in $(seq $START_PORT $END_PORT); do
  echo "正在关闭 Redis 实例，端口: $PORT"
  $REDISDIR/bin/redis-cli -p $PORT shutdown
  if [ $? -eq 0 ]; then
    echo "Redis 实例 $PORT 已成功关闭。"
  else
    echo "关闭 Redis 实例 $PORT 失败。"
  fi
done
