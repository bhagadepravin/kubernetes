#!/bin/bash

### Add K8 repository

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

### ### Add Docker repository.
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 

yum -y update && yum install -y yum-utils device-mapper-persistent-data lvm2 wget git vim docker-ce

## Create /etc/docker directory.
mkdir /etc/docker

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart Docker
systemctl daemon-reload
systemctl enable docker
systemctl restart docker

# Disable swap
swapoff -a
sed -i 's/^\(.*swap.*\)$/#\1/' /etc/fstab 

sestatus
# load netfilter probe specifically
modprobe br_netfilter

# disable SELinux. If you want this enabled, comment out the next 2 lines. But you may encounter issues with enabling SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y kubelet kubeadm && systemctl enable kubelet.service


# Enable IP Forwarding
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Restarting services
systemctl daemon-reload
systemctl restart kubelet
kubeadm config images pull


echo "reboot if selinux was enabled"
echo "kubeadm init"
# kubeadm reset
# kubeadm token create --print-join-command

# export kubever=$(kubectl version | base64 | tr -d '\n')
# kubectl apply -f https://cloud.weave.works/k8s/net?k8s-version=$kubever

# kubelet troubleshoting # journalctl -b -f -u kubelet.service
# make sure you call kubeadm init/join with e.g. --v=2 to have more details on what's going on.
