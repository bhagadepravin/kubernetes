#!/bin/bash
# By: Pravin Bhagade

set -e
set -E

RED=$'\e[0;31m'
BLUE='\033[0;94m'
GREEN=$'\e[0;32m'
YELLOW='\033[0;33m'
NC=$'\e[0m'

logSuccess() {
    printf "${GREEN}✔ $1${NC}\n" 1>&2
}
logStep() {
    printf "${BLUE}➜ $1${NC}\n" 1>&2
}
logWarn() {
    printf "${YELLOW}$1${NC}\n" 1>&2
}
logError() {
    printf "${RED}$1${NC}\n" 1>&2
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
}

function install_docker {

    if docker --version >/dev/null; then
        logStep "Docker already installed - skipping ...\n"
    else
        logStep "Installing docker ..."
    sudo yum -y -q install yum-utils device-mapper-persistent-data lvm2
    [ -e /etc/yum.repos.d/docker-ce.repo ] && mv /etc/yum.repos.d/docker-ce.repo /etc/yum.repos.d/docker-ce.repo_bk
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    echo "Running..... yum clean all && yum update all"
    yum clean all 2>/dev/null >/dev/null && yum update all 2>/dev/null >/dev/null 
    
    logSuccess "Added Docker Repo\n"
        yum install -y -q docker-ce containerd docker-ce-cli wget git vim mlocate >/dev/null
        if [ $? -ne 0 ]; then
            logError "Error while installing docker\n"
        fi
    fi
    logSuccess "Docker is Installed\n"

    systemctl daemon-reload
    systemctl enable docker >/dev/null
    systemctl restart docker
    rm -rf /etc/containerd/config.toml
    systemctl restart containerd

    logSuccess "Started docker service\n"
}

function install_k8 {

    if kubectl version --short 2>/dev/null >/dev/null && kubectl get nodes | grep control-plane >/dev/null; then
        logStep "Kubernetes already installed - skipping ...\n"
    else
        logStep "Installing Kubernetes.......\n"
        
        logWarn "Disabling Swap\n"
        swapoff -a
        sed -i 's/^\(.*swap.*\)$/#\1/' /etc/fstab

        logWarn "Disabling Selinux\n"
        setenforce 0
        sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

        logWarn "Enable br_netfilter kernel module and make persistent\n"
        sudo modprobe br_netfilter 2>/dev/null >/dev/null
        sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables" 2>/dev/null >/dev/null
        sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-ip6tables" 2>/dev/null >/dev/null
        sudo sh -c "echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf" 2>/dev/null >/dev/null
        sudo sh -c "echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.conf" 2>/dev/null >/dev/null

        logWarn "Enable ipv4 forward\n"
        sed -i "/enp0s3/d" /etc/sysctl.conf 2>/dev/null >/dev/null
        sysctl -w net.ipv4.ip_forward=1 2>/dev/null >/dev/null
        sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf 2>/dev/null >/dev/null
        sudo sysctl -p /etc/sysctl.conf >/dev/null
        yum install -y -q kubelet kubeadm kubectl 2>/dev/null >/dev/null
        systemctl enable kubelet.service
        systemctl daemon-reload
        systemctl restart kubelet

        logWarn "Pulling kubeadm images\n"
        kubeadm config images pull >/dev/null
        logStep "Installing Kubernetes Inprogress.......\n"

        NETWORK_OVERLAY_CIDR_NET=$(curl -s https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml | grep -E '"Network": "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}"' | cut -d'"' -f4)

        sudo kubeadm init --pod-network-cidr=${NETWORK_OVERLAY_CIDR_NET}

        logSuccess "Kubernetes is Installed\n"

        logStep "Enabling kubectl bash-completion"
        sudo yum -y -q install bash-completion 2>/dev/null >/dev/null
        source <(kubectl completion bash)" >>~/.bashrc 

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

        logStep "Remove "node-role.kubernetes.io/master:NoSchedule taint", if its a single node cluster and you want deploy pods on control plane as well..\n"
        logError "kubectl taint nodes $(hostname) node-role.kubernetes.io/master:NoSchedule-\n"
        logError "kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-\n"

        if [ $? -ne 0 ]; then
            logError "Error while installing Kubernetes\n"
        fi
    fi

}

add_repo
install_docker
install_k8

# Optional not enabled

function tear_down {
    sudo kubeadm reset --force
    systemctl stop kubelet.service
    docker ps -aq | xargs -I '{}' docker stop {}
    docker ps -aq | xargs -I '{}' docker rm {}
    df | grep /var/lib/kubelet | awk '{ print $6 }' | xargs -I '{}' umount {}
    rm -rf /var/lib/kubelet && rm -rf /etc/kubernetes/ && rm -rf /var/lib/etcd
    yum remove -y -q kubernetes etcd kubelet kubeadm kubectl docker-ce containerd docker-ce-cli
    rm -rf /bin/docker
    ip link del docker0
}
