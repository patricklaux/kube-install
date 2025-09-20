# kube-install

Scripts and files for installing kubernetes




```shell
# 设置每台机器的主机名
# 192.168.50.130
sudo hostnamectl set-hostname k8s-control-1
# 192.168.50.135
sudo hostnamectl set-hostname k8s-worker-1
# 192.168.50.136
sudo hostnamectl set-hostname k8s-worker-2
```



```
sudo apt install sshpass

chmod +x node-sync-files.sh 0-wget-tools.sh 1-prepare-system.sh 2-install-containerd.sh 3-install-kube-tools.sh 4-init-master.sh 5-install-calico-network.sh
```







