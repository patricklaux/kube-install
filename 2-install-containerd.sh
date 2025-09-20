#!/bin/bash
#
# 安装容器运行时

set -euxo pipefail

DOCKER_MIRROR=https://docker.1ms.run
K8S_MIRROR=https://k8s.m.daocloud.io
PROXY_SERVER=192.168.50.218
USE_MIRROR=false
USE_PROXY=true

# 1.安装containerd
sudo tar Cxzvf /usr/local ./containerd/containerd-2.1.4-linux-amd64.tar.gz

# 2.设为服务
sudo mkdir -p /usr/local/lib/systemd/system/
sudo cp ./containerd/containerd.service /usr/local/lib/systemd/system/

# 3.安装 runc
sudo install -m 755 ./containerd/runc.amd64 /usr/local/sbin/runc

# 4.安装 cni-plugins
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin ./containerd/cni-plugins-linux-amd64-v1.8.0.tgz

# 5.配置
sudo mkdir -p /etc/containerd/certs.d/docker.io/
sudo mkdir -p /etc/containerd/certs.d/registry.k8s.io/

# 5.1. 复制基本配置
sudo cp -r ./containerd/config.toml /etc/containerd/

# 5.2. 创建 docker.io 镜像源
if [ "$USE_MIRROR" == "true" ]; then
  cat <<EOF | sudo tee /etc/containerd/certs.d/docker.io/hosts.toml
server = "https://docker.io"
[host."$DOCKER_MIRROR"]
capabilities = ["pull", "resolve"]
EOF
fi

# 5.3. 创建 registry.k8s.io 镜像源
if [ "$USE_MIRROR" == "true" ]; then
  cat <<EOF | sudo tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml
server = "https://registry.k8s.io"
[host."$K8S_MIRROR"]
capabilities = ["pull", "resolve"]
EOF
fi
# 5.4. 增加代理
if [ "$USE_PROXY" == "true" ]; then
  sudo mkdir -p /etc/systemd/system/containerd.service.d/
  cat <<EOF | sudo tee /etc/systemd/system/containerd.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://$PROXY_SERVER:3128/"
Environment="HTTPS_PROXY=http://$PROXY_SERVER:3128/"
Environment="NO_PROXY=localhost,127.0.0.1,127.0.1.1,::1,10.0.0.0/8,192.168.0.0/16,172.17.0.0/16,172.30.0.0/16,172.31.0.0/16,.svc,.cluster.local,169.254.169.254"
EOF
fi

# 6.启动服务
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart containerd

