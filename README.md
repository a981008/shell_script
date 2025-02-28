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
* [batch_ssh_auth.sh](linux/batch_ssh_auth.sh)：节点互相间认证。
* [add_host.sh](linux/add_host.sh)：`/etc/hosts` 增加 IP 与域名映射。
* [auto_login.sh](linux/auto_login.sh)：自动登录主机。
## K8S
* [install_etcd_cluster.sh](k8s/install_etcd_cluster.sh)：安装 etcd 集群。
* [download.sh](k8s/download.sh)：下载离线安装需要的包。
* [prepare_env.sh](k8s/prepare_env.sh)：准备集群环境。
* [install.sh](k8s/install.sh)：安装k8s集群。
  * [install_docker.sh](k8s/install_docker.sh)：安装 docker。
  * [install_cir_dockerd.sh](k8s/install_cri_dockerd.sh)：安装 cri-dockerd
  * [push_images.sh](k8s/push_images.sh)：将离线包中的镜像上传到私有仓库。
  * [pull_images.sh](k8s/pull_images.sh)：将私有仓库镜像拉取到本地。
