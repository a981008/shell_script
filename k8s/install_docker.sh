#!/bin/bash
set -e

registry_url=$1

echo "Registry URL: ${registry_url}"

cat > /etc/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/docker.service

mkdir -p /etc/docker/

cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["http://${registry_url}"],
  "insecure-registries": ["${registry_url}"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl daemon-reload
systemctl enable --now docker.service

echo "Docker installed and configured successfully."
