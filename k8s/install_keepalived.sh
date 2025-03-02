#!/bin/bash
VIP=$1
NET_CARD=$2

set -e

priority=$((RANDOM % 100 + 1))

mkdir -p /etc/keepalived
cat > /etc/keepalived/keepalived.conf << EOF
vrrp_instance VI_1 {
    state MASTER
    interface ${NET_CARD}
    virtual_router_id 51
    priority ${priority}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 123456
    }
    virtual_ipaddress {
        ${VIP}
    }
}
EOF

cat > /etc/systemd/system/keepalived.service << EOF
[Unit]
Description=Keepalived high availability monitor
After=network.target

[Service]
ExecStart=/usr/bin/keepalived -D -f /etc/keepalived/keepalived.conf
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=always
Type=forking

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now keepalived
