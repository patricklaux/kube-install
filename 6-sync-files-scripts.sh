#!/bin/bash
#
# 仅主节点执行
# 1.导出工作节点所需容器镜像；
# 2.容器镜像、安装软件包和脚本：从主节点分发到各个工作节点

set -euxo pipefail

# 请修改用户名(假定：所有节点的用户名相同)
USER=patrick
# 请修改工作节点列表信息
NODES=("192.168.50.135" "192.168.50.136")
# 默认文件目录
FILES_DIR="/home/$USER/workspace/kube-install"
# 镜像文件目录
IMAGES_DIR="$FILES_DIR/kube-images"

# 是否导出镜像，如已导出请改为 false
EXPORT_IMAGES="true"
# 是否安装 sshpass，如已安装请改为 false
INSTALL_SSHPASS="true"
# 是否生成密钥对，如未生成请改为 true
GENERATE_KEY="false"

# 1、生成密钥对(用于免密登录)
if [ "$GENERATE_KEY" == "true" ]; then
  ssh-keygen -f ~/.ssh/id_ed25519 -N "" -q
fi

# 2、安装 sshpass
if [ "$INSTALL_SSHPASS" == "true" ]; then
  sudo apt install sshpass
fi

# 3、输入密码
# 假定：所有节点的密码相同
read -s -p "Enter password(for all nodes): " SSHPASS
echo
export SSHPASS

# 4、添加工作节点主机信息
for node in "${NODES[@]}"; do
  ssh-keyscan "$node" >> ~/.ssh/known_hosts
done

# 5、分发密钥（用于 SSH 登录其它节点执行命令）
for node in "${NODES[@]}"; do
  sshpass -e ssh-copy-id $USER@$node || { echo "SSH copy failed on $node"; exit 1; }
done
# 移除密码变量
unset SSHPASS

# 6、导出镜像
if [ "$EXPORT_IMAGES" == "true" ]; then
  mkdir -p "${IMAGES_DIR}/docker.io/calico/"
  mkdir -p "${IMAGES_DIR}/registry.k8s.io"
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
    sudo ctr -n=k8s.io images export "${IMAGES_DIR}/${imageName}.tar" "$imageName"
  done
fi

# 7、分发容器镜像、安装软件包、脚本
WORKER_SCRIPTS=(
  "1-prepare-system.sh"
  "2-install-containerd.sh"
  "3-install-kube-tools.sh"
  "7-import-kube-images.sh"
)
for node in "${NODES[@]}"; do
  ssh "$USER@$node" "cd /home/$USER && mkdir -p workspace/kube-install/containerd/ && mkdir -p workspace/kube-install/kube-images/"
  for script in "${WORKER_SCRIPTS[@]}"; do
    scp "$FILES_DIR/$script" "$USER@$node:$FILES_DIR/"
    ssh "$USER@$node" "chmod 770 $FILES_DIR/$script"
  done
  scp "$FILES_DIR"/containerd/* "$USER@$node:$FILES_DIR/containerd/"
  scp -r "$IMAGES_DIR"/* "$USER@$node:$IMAGES_DIR/"
done

# 输出提示信息
echo "Successfully! Please login each remote worker node and execute scripts."
