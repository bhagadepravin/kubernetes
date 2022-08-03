# Kubernetes // **Troubleshooting**

#### Torch Setup
```bash
# Install Kubernetes 1.21

# Below curl cmd will install docker and kubernetes.
curl -sSL https://raw.githubusercontent.com/bhagadepravin/kubernetes/k8-1.21/k8-setup.sh | bash

kubectl get nodes

# Setup torch.

# We need to configure storage provider first with storageclass as empty.
# It will create 2 pv with storage 10G and 1G with volumemode as FileSystem and storageclass as empty

curl -sSL https://raw.githubusercontent.com/bhagadepravin/kubernetes/main/storage.yaml | bash

kubectl get pv 

# now install torch.

rm -rf torch.sh && wget https://bitbucket.org/pravinbhagade/automations/raw/5d44c96faae741702081c6d7ea7a241ef3afe772/torch_complete.sh && mv -f torch_complete.sh torch.sh && chmod +x torch.sh && ./torch.sh

# run 
./torch.sh install_torch_eks

# as we have K8 already installed, so we can use above cmd to setup torch in torch-auto namespace
```

K8 Setup on CentOS 7

* **Master Node**
```bash
curl -s https://raw.githubusercontent.com/bhagadepravin/kubernetes/main/k8-setup.sh | sh -s
```

Kubernetes version 1.17.3
```bash
curl -s  https://raw.githubusercontent.com/bhagadepravin/kubernetes/k8-1.17.3-0/k8-setup.sh | sh -s
```
* **Worker Node**
```bash
curl -s https://raw.githubusercontent.com/bhagadepravin/kubernetes/main/k8-worker-setup.sh | sh -s
```

### Commands
```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
 ```
```bash
journalctl -b -f -u kubelet.service
kubeadm token create --print-join-command
```

## **Aliases**
```bash
vim ~/.bash_profile

# kubectl aliases
    alias k='kubectl'
    alias k="kubectl"
    alias kc="kubectl create -f"
    alias kg="kubectl get"
    alias pods="kubectl get pods"
    alias allpods="kubectl get pods --all-namespaces"
    alias rcs="kubectl get rc"
    alias svcs="kubectl get services"
    alias dep="kubectl get deployment"
    alias kd="kubectl describe"
    alias kdp="kubectl describe pod "
    alias kds="kubectl describe service "
    alias nodes="kubectl get nodes"
    alias klogs="kubectl logs"
    alias ns="kubectl get ns"
    alias deploys="kubectl get deployment"
    alias events="kubectl get events"
    alias kexec="kubectl exec -it "
    alias secrets="kubectl get secrets"
    alias igs="kubectl get ingress"
    alias contexts="kubectl config get-contexts"
    alias ktop="kubectl top nodes"
```    

## Contexts
A context is a cluster, namespace and user.

* Get a list of contexts.

$ `kubectl config get-contexts`
```bash
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin
```
* Get the current context.

`$ kubectl config current-context`
```bash
kubernetes-admin@kubernetes
```
* Switch current context.

`kubectl config use-context docker-desktop`

* Set default namesapce

`kubectl config set-context $(kubectl config current-context) --namespace=my-namespace`

To switch between contexts, you can also install and use (kubectx)[https://github.com/ahmetb/kubectx].

### Changing docker cgroup

```bash
systemctl cat docker

# Change the Docker cgroup to systemd by editing the Docker service with the following command:
ExecStart=/usr/bin/dockerd --exec-opt native.cgroupdriver=systemd

systemctl daemon-reload
systemctl restart docker

# docker info

--------------------------
Failed to run kubelet" err="failed to run Kubelet: misconfiguration: kubelet cgroup driver: \"systemd\" is different from docker cgroup driver: \"cgroupfs\"


journalctl -b -f -u kubelet.service

# A minimal example of configuring the field explicitly:

vi kubeadm-config.yaml

# kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: v1.23.0
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: cgroupfs

# Such a configuration file can then be passed to the kubeadm command:

kubeadm init --config kubeadm-config.yaml

or 
sudo sed -i "s/^\(KUBELET_EXTRA_ARGS=\)\(.*\)$/\1\"--cgroup-driver=$(sudo docker info | grep -i cgroup | cut -d" " -f2 | tail -n1)\2\"/" /etc/sysconfig/kubelet
```
