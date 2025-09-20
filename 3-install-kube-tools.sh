#!/bin/bash
#
# 安装 kubelet kubeadm kubectl

set -euxo pipefail

KUBE_STORE_VER="v1.34"
KUBE_VER="1.34.1-1.1"

sudo apt-get update
# 1. 安装依赖软件
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# 2. 下载 Kubernetes 软件仓库的公共签名密钥
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/$KUBE_STORE_VER/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 3. 添加 Kubernetes 指定版本的 apt 仓库
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBE_STORE_VER/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 4. 安装 kubelet、kubeadm 和 kubectl
sudo apt-get update
sudo apt-get install -y kubelet="$KUBE_VER" kubeadm="$KUBE_VER" kubectl="$KUBE_VER"

# 5. 锁定版本，避免升级破坏集群稳定性
sudo apt-mark hold kubelet kubeadm kubectl

# 6. 启动 kubelet
sudo systemctl enable kubelet
sudo systemctl start kubelet

# 7. 配置 crictl
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF
