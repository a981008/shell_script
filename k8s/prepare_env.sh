#!/bin/bash

echo "Disabling SELinux..."
sed -i '/^SELINUX=/ c SELINUX=disabled' /etc/selinux/config
setenforce 0

echo "Disabling swap..."
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab

echo "Applying kernel parameters for Kubernetes..."
cat > /etc/sysctl.d/k8s.conf << EOF
vm.swappiness=0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl -p /etc/sysctl.d/k8s.conf

echo "Loading necessary kernel modules..."
modprobe br_netfilter
modprobe overlay

echo "Setting up IPVS modules..."
mkdir -p /etc/sysconfig/modules/
cat > /etc/sysconfig/modules/ipvs.modules << EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF
chmod +x /etc/sysconfig/modules/ipvs.modules
/etc/sysconfig/modules/ipvs.modules

# 关闭防火墙
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl mask firewalld

echo "Environment preparation for Kubernetes completed."
