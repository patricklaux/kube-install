#!/bin/bash
#
# 仅主节点执行
# 安装网络插件 calico

kubectl create -f ./calico/operator-crds.yaml
kubectl create -f ./calico/tigera-operator.yaml
kubectl create -f ./calico/custom-resources.yaml

# 安装命令行工具
# 增加执行权限
sudo chmod +x ./calico/calicoctl-linux-amd64

# 作为独立工具安装
sudo cp ./calico/calicoctl-linux-amd64 /usr/local/bin/calicoctl