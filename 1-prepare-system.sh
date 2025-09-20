#!/bin/bash
#
#准备系统环境

# e异常退出 u使用未定义变量退出 x打印错误输出 o管道状态码
set -euxo pipefail

# 临时关闭交换分区
sudo swapoff -a
# 注释掉交换分区所在的行
sudo sed -ri 's/.*swap.*/#&/' /etc/fstab

# 调整时区
sudo timedatectl set-timezone Asia/Shanghai
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
#
# 使修改生效
sudo sysctl --system


echo "192.168.50.130 cluster-endpoint" | sudo tee -a /etc/hosts
