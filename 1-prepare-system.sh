#!/bin/bash
#
# 调整系统环境

# 脚本执行异常时退出
set -euxo pipefail

# 请调整为主节点的 IP
CONTROL_IP=“192.168.50.130”
# 请调整为正确时区
TIMEZONE="Asia/Shanghai"

# 临时关闭交换分区
sudo swapoff -a
# 注释掉交换分区所在的行
sudo sed -ri 's/.*swap.*/#&/' /etc/fstab

# 调整时区
sudo timedatectl set-timezone "$TIMEZONE"
sudo systemctl restart systemd-timedated
sudo systemctl restart systemd-timesyncd

# 动态加载 overlay 模块
sudo modprobe overlay
# 开机加载 overlay 模块
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
EOF
#

# 配置网络参数
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# 使修改生效
sudo sysctl --system

# 将 cluster-endpoint 解析到主节点
echo "$CONTROL_IP cluster-endpoint" | sudo tee -a /etc/hosts
