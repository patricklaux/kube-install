# kube-install

Scripts and files for installing Kubernetes.

## 特别说明

> ⚠️ 警告
>
> 本项目仅用于搭建个人学习环境，请勿用于生产环境。
>
> 本项目包含了预下载的安装软件包，使用前请仔细核对每个软件包的摘要信息，如与官方信息不符请勿使用！！！

## 项目文件概览

```shell
kube-install/
├── 0-wget-tools.sh
├── 1-prepare-system.sh
├── 2-install-containerd.sh
├── 3-install-kube-tools.sh
├── 4-init-master.sh
├── 5-install-calico-network.sh
├── 6-sync-files-scripts.sh
├── calico
│   ├── calicoctl-linux-amd64
│   ├── custom-resources.yaml
│   ├── operator-crds.yaml
│   └── tigera-operator.yaml
├── containerd
│   ├── cni-plugins-linux-amd64-v1.8.0.tgz
│   ├── config.toml
│   ├── containerd-2.1.4-linux-amd64.tar.gz
│   ├── containerd.service
│   └── runc.amd64
└── kubeadm
    └── kubeadm-init-nftables.yaml
```

### 脚本说明

- `0-wget-tools.sh` （可选执行，譬如下载其它版本）

  执行：主节点

  作用：下载 `containerd` 和 `calico` 相关软件

- `1-prepare-system.sh`

  执行：所有节点

  作用：调整系统环境

- `2-install-containerd.sh`

  执行：所有节点

  作用：安装容器运行时 `containerd`

- `3-install-kube-tools.sh`

  执行：所有节点

  作用：安装 Kubelet, Kubeadm, Kubectl

- `4-init-master.sh`

  执行：主节点

  作用：初始化主节点

- `5-install-calico-network.sh`

  执行：主节点

  作用：安装网络插件 `calico`

- `6-sync-files-scripts.sh`

  执行：主节点

  作用：分发文件和脚本到工作节点

**执行顺序**：主节点 0 至 6 全部执行完毕且确认成功后，再在工作节点执行 1 至 3。

### 文件夹说明

- `calico`：网络插件 calico 的相关配置和安装软件包。
- `containerd`：容器运行时 containerd 的相关配置和安装软件包。
- `kubeadm`：集群初始化配置文件。




```shell
# 设置各机器的主机名
# 192.168.50.130
sudo hostnamectl set-hostname k8s-control-1
# 192.168.50.135
sudo hostnamectl set-hostname k8s-worker-1
# 192.168.50.136
sudo hostnamectl set-hostname k8s-worker-2
```



```
sudo apt install sshpass

chmod +x sync-files-scripts.sh 0-wget-tools.sh 1-prepare-system.sh 2-install-containerd.sh 3-install-kube-tools.sh 4-init-master.sh 5-install-calico-network.sh
```



## 分发文件和脚本

脚本名称：sync-files-scripts.sh

执行节点：控制平面节点

```shell
#!/bin/bash
#
# 文件和脚本：从控制平面节点分发到各个工作节点

set -euxo pipefail

# 假定所有节点的用户名相同
USER=patrick
NODES=("192.168.50.135" "192.168.50.136")
FILES_DIR="/home/$USER/workspace/kube-install"

# 0、输入密码（假定：所有节点密码相同）
read -s -p "Enter password(for all nodes): " SSHPASS
echo
export SSHPASS

# 1、添加节点信息
for node in "${NODES[@]}"; do
  ssh-keyscan "$node" >> ~/.ssh/known_hosts
done

# 2、分发密钥（用于 SSH 登录其它节点执行命令）
for node in "${NODES[@]}"; do
  sshpass -e ssh-copy-id $USER@$node || { echo "SSH copy failed on $node"; exit 1; }
done
unset SSHPASS

# 3、 同步文件及脚本
REMOTE_SCRIPTS=("1-prepare-system.sh" "2-install-containerd.sh" "3-install-kube-tools.sh")
for node in "${NODES[@]}"; do
  ssh $USER@$node "cd /home/$USER && mkdir -p workspace/kube-install/containerd/"
  for script in "${REMOTE_SCRIPTS[@]}"; do
    scp $FILES_DIR/$script $USER@$node:$FILES_DIR/
    ssh $USER@$node "chmod 770 $FILES_DIR/$script"
  done
  scp $FILES_DIR/containerd/* $USER@$node:$FILES_DIR/containerd/
done

echo "sync files and scripts successfully! Please login each remote worker node and execute script."
```



## 调整系统环境

脚本名称：1-prepare-system.sh

执行节点：所有

```shell
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

# 将 cluster-endpoint 解析到控制平面节点
echo "$CONTROL_IP cluster-endpoint" | sudo tee -a /etc/hosts
```



## 安装容器运行时

```shell
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
```



## 安装三大工具

```shell
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
```



## 初始化主节点

```shell
#!/bin/bash
#
# 初始化 control-plane

set -euxo pipefail

sudo kubeadm init --config=./kubeadm/kubeadm-init-nftables.yaml
```



## 安装网络插件

```shell
#!/bin/bash
#
# 安装网络插件 calico

kubectl create -f ./calico/operator-crds.yaml
kubectl create -f ./calico/tigera-operator.yaml
kubectl create -f ./calico/custom-resources.yaml

# 安装命令行工具
# 增加执行权限
sudo chmod +x ./calico/calicoctl-linux-amd64

# 作为独立工具安装
sudo cp ./calico/calicoctl-linux-amd64 /usr/local/bin/calicoctl
```



