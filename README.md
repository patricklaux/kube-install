# kube-install

Scripts and files for installing Kubernetes.

## 特别说明

> ⚠️ 注意：
>
> 本项目的相关脚本和软件安装包依赖于特定平台和系统环境，请根据实际情况进行调整。
>
> 本项目包含部分技术预览特性，且未考虑安全性、可用性和性能优化等，请勿直接用于生产环境。
>
> 本项目包含预下载的软件安装包，使用前请核对每个软件包的摘要信息，如与官方不符请勿使用！！！

## 项目概览

### 文件概览

```shell
kube-install/
├── 0-wget-tools.sh
├── 1-prepare-system.sh
├── 2-install-containerd.sh
├── 3-install-kube-tools.sh
├── 4-init-master.sh
├── 5-install-calico-network.sh
├── 6-sync-files-scripts.sh
├── 7-import-kube-images.sh
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

  作用：下载 `containerd` 和 `calico` 的相关配置文件和软件安装包

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
  
- `7-import-kube-images.sh`

  执行：工作节点

  作用：导入工作节点所必需的镜像

**脚本执行顺序**：

1. 主节点执行脚本 0 至 5 且确认成功；
3. 主节点执行脚本 6：分发安装文件、容器镜像和执行脚本到每个工作节点；
4. 每个工作节点执行脚本 1, 2, 3, 7；
5. 每个工作节点执行加入集群命令。

### 文件夹说明

- `calico`：网络插件 calico 的相关配置和软件安装包。
- `containerd`：容器运行时 containerd 的相关配置和软件安装包。
- `kubeadm`：集群初始化配置文件。

### 目录约定

1、所有文件仅需上传到主节点，文件目录：`/home/$user/workspace/kube-install/`

2、某些脚本使用相对路径，请务必进入到 `kube-install` 目录再执行脚本。

### 节点信息

示例集群共有 3 个节点：1 个主节点和 2 个工作节点。

操作系统均为 Ubuntu 24.04.3，硬件配置为 4C - 8G - 200G 虚拟机，详细信息如下：

|       IP       |    主机名     |   角色    |
| :------------: | :-----------: | :-------: |
| 192.168.50.130 | k8s-control-1 | 控制平面  |
| 192.168.50.135 | k8s-worker-1  | 工作节点1 |
| 192.168.50.136 | k8s-worker-2  | 工作节点2 |

### 安装版本

**Kubernetes** 1.34.1

**Containerd** 2.1.4

**Calico** 3.30.3

### 配置文件

#### Kubeadm 配置

文件 `kubeadm-init-nftables.yaml` 由以下命令生成：

```yaml
# 生成默认配置文件
kubeadm config print init-defaults -v=5 --component-configs KubeProxyConfiguration,KubeletConfiguration > kubeadm-init-nftables.yaml
```

根据默认文件进行修改和删减后，仅保留了已修改项。

> 注：Kubeadm 读取配置时，未配置项将使用默认值。

这份配置文件，需要特别注意子网范围和主节点 IP，请根据网络环境进行修改：

1、第 4 行：`advertiseAddress` 请设定为你的主节点 IP。

2、第 13 行 `serviceSubnet ` ，第 14 行 `podSubnet`，第 19 行 `clusterCIDR`：

- `podSubnet` 和`clusterCIDR` 必须保持一致；
- `serviceSubnet ` 、`podSubnet` 的子网范围不能重叠，且与其它的子网范围也不能重叠。

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.50.130
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
controlPlaneEndpoint: cluster-endpoint
kubernetesVersion: 1.34.1
networking:
  # 与 kubeadm init --service-cidr=10.96.0.0/12 同含义
  serviceSubnet: 10.96.0.0/12
  podSubnet: 172.30.0.0/16
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
# 与 podSubnet 保持一致
clusterCIDR: 172.30.0.0/16
# 配置为使用 nftables
mode: nftables
---
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
kind: KubeletConfiguration
```

#### Calico 配置

文件 `calico/custom-resources.yaml` 是从官方 Github 下载，修改如下：

1、第11行 ：增加 `linuxDataplane: Nftables` ，指定使用 `Nftables` 维护服务代理规则，此新特性 [calico-nftables](https://docs.tigera.io/calico/latest/getting-started/kubernetes/nftables) 文档明确指出 `v3.30` 依然处于技术预览阶段。

2、第16行：`192.168.0.0/16` 修改为 `172.30.0.0/16`，务必与 `kubeadm-init-nftables.yaml` 文件中的 `podSubnet` 和 `clusterCIDR` 配置项保持一致。

```yaml
# This section includes base Calico installation configuration.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # 设置为使用 Nftables
    linuxDataplane: Nftables
    ipPools:
    - name: default-ipv4-ippool
      blockSize: 26
      # 由 192.168.0.0/16 修改为 172.30.0.0/16
      cidr: 172.30.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()

# 省略其它未作调整内容
……
```

#### Containerd 配置

文件 `containerd/config.toml` 由以下命令生成默认配置：

```shell
sudo containerd config default > config.toml
```

根据默认配置修改如下：

1、第 50 行：`registry.k8s.io/pause:3.10` 修改为 `registry.k8s.io/pause:3.10.1`。

2、第 53 行：增加 `/etc/containerd/certs.d`，设定镜像源配置目录。

3、第 108 行：增加 `SystemdCgroup = true`，设定将 `systemd` 用以 `cgoup`。

此文件如无特殊需求，无需修改。

```toml
version = 3
root = '/var/lib/containerd'
state = '/run/containerd'
temp = ''
disabled_plugins = []
required_plugins = []
oom_score = 0
imports = []

[grpc]
  address = '/run/containerd/containerd.sock'
  tcp_address = ''
  tcp_tls_ca = ''
  tcp_tls_cert = ''
  tcp_tls_key = ''
  uid = 0
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[ttrpc]
  address = ''
  uid = 0
  gid = 0

[debug]
  address = ''
  uid = 0
  gid = 0
  level = ''
  format = ''

[metrics]
  address = ''
  grpc_histogram = false

[plugins]
  [plugins.'io.containerd.cri.v1.images']
    snapshotter = 'overlayfs'
    disable_snapshot_annotations = true
    discard_unpacked_layers = false
    max_concurrent_downloads = 3
    concurrent_layer_fetch_buffer = 0
    image_pull_progress_timeout = '5m0s'
    image_pull_with_sync_fs = false
    stats_collect_period = 10
    use_local_image_pull = false

    [plugins.'io.containerd.cri.v1.images'.pinned_images]
      sandbox = 'registry.k8s.io/pause:3.10.1'

    [plugins.'io.containerd.cri.v1.images'.registry]
      config_path = '/etc/containerd/certs.d'

    [plugins.'io.containerd.cri.v1.images'.image_decryption]
      key_model = 'node'

  [plugins.'io.containerd.cri.v1.runtime']
    enable_selinux = false
    selinux_category_range = 1024
    max_container_log_line_size = 16384
    disable_apparmor = false
    restrict_oom_score_adj = false
    disable_proc_mount = false
    unset_seccomp_profile = ''
    tolerate_missing_hugetlb_controller = true
    disable_hugetlb_controller = true
    device_ownership_from_security_context = false
    ignore_image_defined_volumes = false
    netns_mounts_under_state_dir = false
    enable_unprivileged_ports = true
    enable_unprivileged_icmp = true
    enable_cdi = true
    cdi_spec_dirs = ['/etc/cdi', '/var/run/cdi']
    drain_exec_sync_io_timeout = '0s'
    ignore_deprecation_warnings = []

    [plugins.'io.containerd.cri.v1.runtime'.containerd]
      default_runtime_name = 'runc'
      ignore_blockio_not_enabled_errors = false
      ignore_rdt_not_enabled_errors = false

      [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes]
        [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
          runtime_type = 'io.containerd.runc.v2'
          runtime_path = ''
          pod_annotations = []
          container_annotations = []
          privileged_without_host_devices = false
          privileged_without_host_devices_all_devices_allowed = false
          cgroup_writable = false
          base_runtime_spec = ''
          cni_conf_dir = ''
          cni_max_conf_num = 0
          snapshotter = ''
          sandboxer = 'podsandbox'
          io_type = ''

          [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
            BinaryName = ''
            CriuImagePath = ''
            CriuWorkPath = ''
            IoGid = 0
            IoUid = 0
            NoNewKeyring = false
            Root = ''
            ShimCgroup = ''
            SystemdCgroup = true
# 省略其它未修改配置
```



## 1. 调整系统环境

脚本名称：`1-prepare-system.sh`

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

# 将 cluster-endpoint 解析到主节点
echo "$CONTROL_IP cluster-endpoint" | sudo tee -a /etc/hosts
```



## 2. 安装容器运行时

脚本名称：`2-install-containerd.sh`

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
sudo cp ./containerd/config.toml /etc/containerd/

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



## 3. 安装三大工具

脚本名称：`3-install-kube-tools.sh`

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



## 4. 初始化主节点

脚本名称：`4-init-master.sh`

```shell
#!/bin/bash
#
# 仅主节点执行
# 初始化 control-plane

set -euxo pipefail

sudo kubeadm init --config=./kubeadm/kubeadm-init-nftables.yaml
```

这一步执行完成后，控制台将会打印一些信息，

## 5. 安装网络插件

脚本名称：`5-install-calico-network.sh`

```shell
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
```



## 6. 分发文件和脚本

脚本名称：`6-sync-files-scripts.sh`

> 注：执行此脚本之前，请确认已经使用 `ssh-keygen` 命令生成密钥对。

```shell
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
# 是否分发密钥，如已复制密钥请改为 false
SSH_COPY="true"

# 1、生成密钥对(用于免密登录)
if [ "$GENERATE_KEY" == "true" ]; then
  ssh-keygen -f ~/.ssh/id_ed25519 -N "" -q
fi

# 2、安装 sshpass
if [ "$INSTALL_SSHPASS" == "true" ]; then
  sudo apt install sshpass
fi

# 3、分发密钥
if [ "$SSH_COPY" == "true" ]; then
  # 3.1、输入密码
  # 假定：所有节点的密码相同
  read -s -p "Enter password(for all nodes): " SSHPASS
  echo
  export SSHPASS

  # 3.2、添加工作节点主机信息
  for node in "${NODES[@]}"; do
    ssh-keyscan "$node" >> ~/.ssh/known_hosts
  done

  # 3.3、分发密钥（用于 SSH 登录其它节点执行命令）
  for node in "${NODES[@]}"; do
   sshpass -e ssh-copy-id $USER@$node || { echo "SSH copy failed on $node"; exit 1; }
  done
  # 3.4、移除密码变量
  unset SSHPASS
fi

# 4、导出镜像
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

# 5、分发容器镜像、安装软件包、脚本
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

# 6、输出提示信息
echo "Successfully! Please login each remote worker node and execute scripts."
```



## 7. 工作节点加入集群

第 6 步执行成功后，各工作节点都将存在如下文件：

```shell
kube-install/
├── 1-prepare-system.sh
├── 2-install-containerd.sh
├── 3-install-kube-tools.sh
├── 7-import-kube-images.sh
├── containerd
│   ├── cni-plugins-linux-amd64-v1.8.0.tgz
│   ├── containerd-config.toml
│   ├── containerd-2.1.4-linux-amd64.tar.gz
│   ├── containerd.service
│   └── runc.amd64
└── kube-images
    ├── docker.io
    │   └── calico
    │       ├── cni:v3.30.3.tar
    │       ├── csi:v3.30.3.tar
    │       ├── node-driver-registrar:v3.30.3.tar
    │       ├── node:v3.30.3.tar
    │       ├── pod2daemon-flexvol:v3.30.3.tar
    │       └── typha:v3.30.3.tar
    └── registry.k8s.io
        ├── kube-proxy:v1.34.1.tar
        └── pause:3.10.1.tar
```

每个工作节点顺序执行脚本 1, 2, 3, 7，然后再执行主节点生成的 `kubeadm join …… ` 命令信息，即可加入集群。

> 注：
>
> 脚本 7 是可选的，未执行将会自动从网络下载镜像，如果网络条件好，完全可以不执行导入。
>
> 经测试，执行脚本 7 导入镜像时可能会提示镜像不完整，此时需回到主节点再次运行脚本 6。

至此，集群基础搭建的所有工作都已完成。



## 一切顺利结束

回到主节点，执行命令：

```shell
watch -n 2 kubectl get nodes
```

幸运的话，稍等片刻，将会看到所有节点都变成 `Ready` 状态：

```shell
NAME            STATUS   ROLES           AGE   VERSION
k8s-control-1   Ready    control-plane   22h   v1.34.1
k8s-worker-1    Ready    <none>          21h   v1.34.1
k8s-worker-2    Ready    <none>          21h   v1.34.1
```

**Kubernetes** 集群搭建比较繁杂，每次都得折腾半天，所以写了这些脚本。

我本地测试，搭配已提前上传好镜像的私有仓库，顺利的话大概十分钟就可以全部搞定。

最后，祝大伙的集群搭建过程一切顺利！