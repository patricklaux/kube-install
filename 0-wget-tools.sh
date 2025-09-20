#!/bin/bash
#
# 下载相关软件（可选）
# 如果不想使用已下载好的软件，可以使用此脚本执行下载
# 请根据系统平台要求下载特定版本

CALICO_VER=v3.30.3

# 1. 下载 calico
mkdir calico

# 1.1. 下载 calicoctl
wget https://github.com/projectcalico/calico/releases/download/$CALICO_VER/calicoctl-linux-amd64 -o ./calico/calicoctl-linux-amd64
# 1.2. 下载 operator-crds.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VER/manifests/operator-crds.yaml -o ./calico/operator-crds.yaml
# 1.3. 下载 tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VER/manifests/tigera-operator.yaml -o ./calico/tigera-operator.yaml

# 1.4. 下载 custom-resources.yaml
# ！！！注意：此文件请根据安装需求进行修改！！！
wget https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VER/manifests/custom-resources.yaml -o ./calico/custom-resources.yaml


# 2. 下载容器运行时：Containerd
# 请根据系统平台要求下载特定版本
mkdir containerd
wget https://github.com/containerd/containerd/releases/download/v2.1.4/containerd-2.1.4-linux-amd64.tar.gz -o ./containerd/containerd-linux-amd64.tar.gz

wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o ./containerd/containerd.service

wget https://github.com/opencontainers/runc/releases/download/v1.4.0-rc.1/runc.amd64 -o ./containerd/runc.amd64

wget https://github.com/containernetworking/plugins/releases/download/v1.8.0/cni-plugins-linux-amd64-v1.8.0.tgz -o ./containerd/cni-plugins-linux-amd64.tgz