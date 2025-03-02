#!/bin/bash
VIP=$1
MASTER_HOSTS=$2

set -e

mkdir -p /etc/haproxy

cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 4096
    daemon

defaults
    log global
    option httplog
    option dontlognull
    retries 3
    timeout http-request 10s
    timeout queue 1m
    timeout connect 10s
    timeout client 1m
    timeout server 1m
    timeout check 10s
    maxconn 3000

frontend k8s-api
    bind ${VIP}:6443
    mode tcp
    default_backend k8s-api-backend

backend k8s-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
EOF

for i in "${!MASTER_HOSTS[@]}"; do
    host="${MASTER_HOSTS[$i]}"
    echo "    server master-${i} ${host}:6443 check" >> /etc/haproxy/haproxy.cfg
done

cat > /etc/systemd/system/haproxy.service << EOF
[Unit]
Description=HAProxy Load Balancer
After=network.target

[Service]
ExecStart=/usr/bin/haproxy -f /etc/haproxy/haproxy.cfg
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now haproxy
