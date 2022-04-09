#!/bin/bash

## Setup K8 on Centos 7 by Pravin Bhagade
### Add K8 repository
echo "Added K8 repo"

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
# Install dependencies for docker-ce
sudo yum -y install yum-utils device-mapper-persistent-data lvm2

echo "Added docker repo"
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 

sudo yum clean all && sudo yum -y makecache && yum install -y wget git vim docker-ce iptables

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

# Disable default iptables configuration as it will break kubernetes services (API, coredns, etc...)
sudo sh -c "cp /etc/sysconfig/iptables /etc/sysconfig/iptables.ORIG && iptables --flush && iptables --flush && iptables-save > /etc/sysconfig/iptables"
sudo systemctl restart iptables.service

sestatus

# disable SELinux. If you want this enabled, comment out the next 2 lines. But you may encounter issues with enabling SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum -y install epel-release vim git curl wget kubelet kubeadm kubectl && systemctl enable kubelet.service 
echo " Installed kubelet kubeadm kubectl"

# Load/Enable br_netfilter kernel module and make persistent
sudo modprobe br_netfilter
sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables"
sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-ip6tables"
sudo sh -c "echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf"
sudo sh -c "echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.conf"
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

# Restarting services
systemctl daemon-reload
systemctl restart kubelet

echo " join worker node"
