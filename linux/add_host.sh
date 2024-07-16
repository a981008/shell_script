#!/bin/bash

# 检查是否提供了两个参数
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <IP> <hostname>"
    exit 1
fi

IP=$1
HOSTNAME=$2

# 备份当前的 /etc/hosts 文件
cp /etc/hosts /etc/hosts.bak

# 检查是否已经存在该IP地址的条目
if grep -q "$IP" /etc/hosts; then
    # 检查是否已经存在相同的主机名
    if grep -q "$HOSTNAME" /etc/hosts; then
        echo "主机名 $HOSTNAME 已存在于 /etc/hosts。"
    else
        # 追加新的主机名到现有 IP 地址的条目
        sed -i-c "/$IP/s/$/\ $HOSTNAME/" /etc/hosts
        echo "IP 为 $IP 追加新的主机名 $HOSTNAME。"
    fi
else
    # 将新的 IP 地址和主机名追加到 /etc/hosts
    printf "$IP\t$HOSTNAME\n" >> /etc/hosts
    echo "追加新的 $IP 和 $HOSTNAME 条目。"
fi
