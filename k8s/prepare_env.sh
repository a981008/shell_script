#!/bin/bash

# 禁用 SELinux
echo "Disabling SELinux..."
sed -i '/^SELINUX=/ c SELINUX=disabled' /etc/selinux/config
setenforce 0

# 禁用 swap
echo "Disabling swap..."
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab

# 设置内核参数
echo "Applying kernel parameters for Kubernetes..."
cat > /etc/sysctl.d/k8s.conf << EOF
vm.swappiness=0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# 立即加载内核参数
sysctl -p /etc/sysctl.d/k8s.conf

# 加载必要的内核模块
echo "Loading necessary kernel modules..."
modprobe br_netfilter
modprobe overlay

# 配置 IPVS 模块
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

# 执行 IPVS 模块加载脚本
echo "Loading IPVS modules..."
/etc/sysconfig/modules/ipvs.modules

echo "Environment preparation for Kubernetes completed."
