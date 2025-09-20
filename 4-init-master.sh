#!/bin/bash
#
# 仅主节点执行
# 初始化 control-plane

set -euxo pipefail

sudo kubeadm init --config=./kubeadm/kubeadm-init-nftables.yaml