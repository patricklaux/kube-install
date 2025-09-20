#!/bin/bash
#
# sync files and scripts from master to each worker-node.

set -euxo pipefail

USER=patrick
NODES=("192.168.50.135" "192.168.50.136")
FILES_DIR="/home/$USER/workspace/kube-install"

read -s -p "Enter password(for all nodes): " SSHPASS
echo
export SSHPASS

# Step 1: Key distribution
for node in "${NODES[@]}"; do
  ssh-keyscan "$node" >> ~/.ssh/known_hosts
done

for node in "${NODES[@]}"; do
  sshpass -e ssh-copy-id $USER@$node || { echo "SSH copy failed on $node"; exit 1; }
done

# Step 2: Sync files and scripts
REMOTE_SCRIPTS=("1-prepare-system.sh" "2-install-containerd.sh" "3-install-kube-tools.sh")
for node in "${NODES[@]}"; do
  ssh $USER@$node "cd /home/$USER && mkdir -p workspace/kube-install/containerd/"
  for script in "${REMOTE_SCRIPTS[@]}"; do
    scp $FILES_DIR/$script $USER@$node:$FILES_DIR/
    ssh $USER@$node "chmod 770 $FILES_DIR/$script"
  done
  scp $FILES_DIR/containerd/* $USER@$node:$FILES_DIR/containerd/
done

echo "sync files and scripts successfully! Please login remote node and execute script."
