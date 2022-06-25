#!/bin/bash
# By: Pravin Bhagade

logSuccess() {
    printf "${GREEN}✔ $1${NC}\n" 1>&2
}
logStep() {
    printf "${BLUE}✔ $1${NC}\n" 1>&2
}
logWarn() {
    printf "${YELLOW}$1${NC}\n" 1>&2
}

function add_repo {

    [ -e /etc/yum.repos.d/kubernetes.repo ] && mv /etc/yum.repos.d/kubernetes.repo /etc/yum.repos.d/kubernetes.repo_bk

    cat <<EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

    logSuccess "Added Kubernetes Repo\n"

    sudo yum -y -q install yum-utils device-mapper-persistent-data lvm2
    [ -e /etc/yum.repos.d/docker-ce.repo ] && mv /etc/yum.repos.d/docker-ce.repo /etc/yum.repos.d/docker-ce.repo_bk
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum clean all && yum update all && yum install -y -q wget git vim iptables
    logSuccess "Added Docker Repo\n"
}

function install_docker {

    if which docker >/dev/null; then
        logStep "Docker already installed - skipping ...\n"
    else
        logStep "Installing docker ..."
        yum install -y docker-ce
        if [ $? -ne 0 ]; then
            error "Error while installing docker\n"
        fi
    fi
    logSuccess "Docker is Installed\n"

    systemctl daemon-reload
    systemctl enable docker
    systemctl restart docker
    logSuccess "Started docker service\n"
}

function prep_node {
    logWarn "Disabling Swap\n"
    swapoff -a
    sed -i 's/^\(.*swap.*\)$/#\1/' /etc/fstab

    logWarn "Disabling iptables configuration as it will break kubernetes services (API, coredns, etc...)\n"
    sudo sh -c "cp /etc/sysconfig/iptables /etc/sysconfig/iptables.ORIG && iptables --flush && iptables --flush && iptables-save > /etc/sysconfig/iptables"
    sudo systemctl restart iptables.service

    logWarn "Disabling Selinux\n"
    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sestatus

    logWarn "Enable br_netfilter kernel module and make persistent\n"
    sudo modprobe br_netfilter
    sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables"
    sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-ip6tables"
    sudo sh -c "echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf"
    sudo sh -c "echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.conf"

    logWarn "Enable ipv4 forward\n"
    sysctl -w net.ipv4.ip_forward=1
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
    sudo sysctl -p /etc/sysctl.conf

}

function install_k8 {
    logStep "Installing Kubernetes.......\n"
    yum install -y -q kubelet kubeadm kubectl
    systemctl enable kubelet.service
    systemctl daemon-reload
    systemctl restart kubelet

    logWarn "Pulling kubeadm images\n"
    kubeadm config images pull
    logStep "Installing Kubernetes Inprogress.......\n"
    rm -rf /etc/containerd/config.toml
    systemctl restart containerd

    NETWORK_OVERLAY_CIDR_NET=$(curl -s https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml | grep -E '"Network": "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}"' | cut -d'"' -f4)
    echo "$NETWORK_OVERLAY_CIDR_NET"

    sudo kubeadm init --pod-network-cidr=${NETWORK_OVERLAY_CIDR_NET}

    logSuccess "Kubernetes is Installed\n"

    logStep "Enabling kubectl bash-completion"
    sudo yum -y install bash-completion
    echo "source <(kubectl completion bash)"
    echo "source <(kubectl completion bash)" >>~/.bashrc

    logStep "Copy the cluster configuration to the regular users home directory\n"
    [ -e $HOME/.kube ] && mv $HOME/.kube $HOME/.kube_bk
    mkdir -p $HOME/.kube
    sudo cp -r /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    logStep "Deploying the weave Network Overlay\n"
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
    # kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    logSuccess "Check the readiness of nodes\n"
    kubectl get nodes
}

# kubectl cluster-info
# kubeadm token create --print-join-command

########################
# === Reset Cluster === #
#########################
# Reset Cluster
# sudo kubeadm reset --force
# yum remove  kubelet kubeadm kubectl docker-ce containerd

# Clean up iptable remnants
# sudo sh -c "iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X"

# Clean up network overlay remnants
# sudo ip link delete cni0
# sudo ip link delete flannel.1
# sudo ip link delete docker0
