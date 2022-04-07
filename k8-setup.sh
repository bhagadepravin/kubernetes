#!/bin/bash

yum check-update
yum install -y yum-utils device-mapper-persistent-data lvm2 wget git vim
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 
yum install docker-ce -y
systemctl start docker && systemctl enable docker && systemctl status docker
setenforce 0 && sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i '/swap/d' /etc/fstab && swapoff -a


cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum install -y kubelet kubeadm && systemctl enable kubelet.service

echo "kubeadm init"
# kubeadm reset
# kubeadm token create --print-join-command

# kubelet troubleshoting # journalctl -b -f -u kubelet.service
# make sure you call kubeadm init/join with e.g. --v=2 to have more details on what's going on.
