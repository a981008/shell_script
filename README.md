# Profile
收录本人运维时常用的自动化 shell 脚本。

## Redis
* [create_redis_cluster.sh](redis/create_redis_cluster.sh)：搭建 Redis 集群。
* [stop_redis.sh](redis/stop_redis.sh)：批量关闭 Redis 实例。
* [start_redis.sh](redis/start_redis.sh)：批量开启 Redis 实例。
* [create_redis_cluster_local.sh](redis/local/create_redis_cluster_local.sh)：搭建 Redis 集群。不通过 SSH，适用于不知道本机密码的情况。
## Linux
* [xsync.sh](linux/xsync.sh)：将文件分发至所有主机。
* [xcall.sh](linux/xcall.sh)：在所有主机上执行命令。
* [batch_ssh_auth](linux/batch_ssh_auth.sh)：节点互相间认证。
* [add_host.sh](linux/add_host.sh)：`/etc/hosts` 增加 IP 与域名映射。
* [auto_login.sh](linux/auto_login.sh)：自动登录主机。

