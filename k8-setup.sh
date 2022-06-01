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

yum clean all && yum update all  && yum install -y wget git vim docker-ce iptables

## Create /etc/docker directory.
mkdir /etc/docker

# Setup daemon.
#cat > /etc/docker/daemon.json <<EOF
#{
#  "exec-opts": ["native.cgroupdriver=systemd"],
#  "log-driver": "json-file",
#  "log-opts": {
#    "max-size": "100m"
#  },
#  "storage-driver": "overlay2",
#  "storage-opts": [
#    "overlay2.override_kernel_check=true"
 # ]
#}
#EOF

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

yum install -y kubelet kubeadm kubectl && systemctl enable kubelet.service 
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
echo "kubeadm config images pull"
kubeadm config images pull

echo "reboot if selinux was enabled"

NETWORK_OVERLAY_CIDR_NET=`curl -s https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml | grep -E '"Network": "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}"' | cut -d'"' -f4`
echo "$NETWORK_OVERLAY_CIDR_NET"

sudo kubeadm init --pod-network-cidr=${NETWORK_OVERLAY_CIDR_NET}


#echo " Install K9s"
#curl -sS https://webinstall.dev/k9s | bash
#cp /root/.local/opt/k9s-*/bin/k9s /usr/bin/ 
#source ~/.bash_profile


yum install epel-release -y
yum install -y snapd
systemctl enable --now snapd.socket
ln -s /var/lib/snapd/snap /snap
service snapd start
snap install k9s


# Enable kubectl bash-completion
sudo yum -y install bash-completion
echo "source <(kubectl completion bash)"
echo "source <(kubectl completion bash)" >> ~/.bashrc


# Copy the cluster configuration to the regular users home directory
mkdir -p $HOME/.kube
sudo cp -r /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Deploy the Flannel Network Overlay
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# check the readiness of nodes
kubectl get nodes

# check that coredns, apiserver, etcd, and flannel pods are running
kubectl get pods --all-namespaces

echo "kubeadm token create --print-join-command"
kubectl cluster-info
kubeadm token create --print-join-command

########################
# === Reset Cluster === #
#########################
# Reset Cluster
# sudo kubeadm reset

# Clean up iptable remnants
# sudo sh -c "iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X"

# Clean up network overlay remnants
# sudo ip link delete cni0
# sudo ip link delete flannel.1



###########################
# === Troubleshooting === #
###########################
# If exposed deployment intermittently responds with "no route to host", run the following on the troublesome host
# sudo sh -c "iptables --flush && iptables --flush" && sudo systemctl restart docker.service

# If the previous command fixes the intermittent problem, there is most likely an iptables rule preventing incoming traffic to the ingress controller
#  sudo sh -c "cp /etc/sysconfig/iptables /etc/sysconfig/iptables.ORIG && iptables --flush && iptables --flush && iptables-save > /etc/sysconfig/iptables"
#  sudo systemctl restart iptables.service
#  sudo systemctl restart docker.service
# export kubever=$(kubectl version | base64 | tr -d '\n')
# kubectl apply -f https://cloud.weave.works/k8s/net?k8s-version=$kubever

# kubelet troubleshoting # journalctl -b -f -u kubelet.service
# make sure you call kubeadm init/join with e.g. --v=2 to have more details on what's going on.
