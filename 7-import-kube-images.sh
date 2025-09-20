#!/bin/bash
#
# 工作节点导入镜像

set -euxo pipefail

# 导入镜像
images=(
  docker.io/calico/cni:v3.30.3
  docker.io/calico/csi:v3.30.3
  docker.io/calico/node-driver-registrar:v3.30.3
  docker.io/calico/node:v3.30.3
  docker.io/calico/pod2daemon-flexvol:v3.30.3
  docker.io/calico/typha:v3.30.3
  registry.k8s.io/kube-proxy:v1.34.1
  registry.k8s.io/pause:3.10.1
)
for imageName in ${images[@]} ; do
  sudo ctr -n=k8s.io images import "kube-images/${imageName}.tar"
done
