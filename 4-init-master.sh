#!/bin/bash
#
# 仅主节点执行
# 初始化 control-plane

set -euxo pipefail

# 修改为你的用户名
USER="patrick"

sudo kubeadm init --config=./kubeadm/kubeadm-init-nftables.yaml

# 复制证书和配置到用户目录
mkdir -p home/$USER/.kube/config
sudo cp -i /etc/kubernetes/admin.conf home/$USER/.kube/config
sudo chown $(id -u):$(id -g) home/$USER/.kube/config