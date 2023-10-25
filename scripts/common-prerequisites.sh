#!/bin/sh

# update an upgrade package list and install curl
apt-get update
apt-get -y upgrade
apt-get install -y apt-transport-https ca-certificates curl

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Enable br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sysctl --system

# Install Containerd
CONTAINERD_VERSION="1.7.4"
RUNC_VERSION="1.1.9"
CNI_PLUGINS_VERSION="1.3.0"

# Install containerd
curl -Lo /tmp/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz \
         https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar Cxzvf /usr/local /tmp/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Install runc
curl -Lo /tmp/runc.amd64 https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc

# clean up containerd and runc files
rm -rf /tmp/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz /tmp/runc.amd64

# install containerd config
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
curl -Lo /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/cri/master/contrib/systemd-units/containerd.service  
systemctl daemon-reload
systemctl enable --now containerd
systemctl status containerd --no-pager

# Kubeadm, Kubelet, and Kubectl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://dl.k8s.io/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Install Helm 3 for CNI install later
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh