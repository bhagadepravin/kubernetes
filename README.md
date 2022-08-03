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

First kotadm deploys "kotsadm-minio-0" pod which create pvc, which needs 10G storage, which above storage.yaml will take care of it.
After that "kotsadm-postgres-0" pod is launched which needs 1G storage, which above storage.yaml will take care of it.
Total 4 pods are launced as below, after all 4 pods are is in running state, then "Torch" services pods are launced.


kotsadm-5658bc6c67-9mgrp            0/1     Init:2/4            0          27s
kotsadm-minio-0                     1/1     Running             0          90s
kotsadm-operator-669b588bb4-4gcrw   0/1     ContainerCreating   0          26s
kotsadm-postgres-0                  1/1     Running             0          58s

>>>>>>                                                                 

NAME                                READY   STATUS    RESTARTS   AGE
kotsadm-5658bc6c67-9mgrp            1/1     Running   0          2m34s
kotsadm-minio-0                     1/1     Running   0          3m37s
kotsadm-operator-669b588bb4-4gcrw   1/1     Running   0          2m33s
kotsadm-postgres-0                  1/1     Running   0          3m5s

>>>>>
kubectl get po -n torch-auto
>
[root@torchtest ~]# kubectl get po -n torch-auto
NAME                                  READY   STATUS              RESTARTS   AGE
ad-analysis-service-77749bc48-hgz9p   0/1     ContainerCreating   0          8s
ad-catalog-568948bb84-hmbf5           0/1     Init:0/1            0          8s
ad-catalog-db-787dbb9546-vtcb7        0/1     Pending             0          8s
ad-dashplots-79d8944fdf-n5wpv         0/1     Init:0/1            0          8s
ad-notification-7d96fc4759-4n5qd      0/1     ContainerCreating   0          8s
ad-torch-ml-84c6df6645-xmqdq          0/1     ContainerCreating   0          8s
admin-central-795d5cd6b6-sdbxn        0/1     ContainerCreating   0          8s
admin-central-ui-7c68486757-wr99d     0/1     ContainerCreating   0          8s
keycloak-0                            0/1     Init:0/1            0          7s
kotsadm-5658bc6c67-9mgrp              1/1     Running             0          3m19s
kotsadm-minio-0                       1/1     Running             0          4m22s
kotsadm-operator-669b588bb4-4gcrw     1/1     Running             0          3m18s
kotsadm-postgres-0                    1/1     Running             0          3m50s
nats-7746474b96-l6k78                 0/1     Pending             0          8s
redis-5498d54679-qh2ft                0/1     ContainerCreating   0          7s
torch-api-gateway-58bc4bb56b-955mh    0/1     Pending             0          7s
torch-glossary-78d76444ff-klz4h       0/1     ContainerCreating   0          7s
torch-monitors-5fbb8bb6b4-fdfb8       0/1     Pending             0          7s
torch-monitors-5fbb8bb6b4-fg4cl       0/1     Pending             0          7s
torch-pipeline-b84f6d849-8hfwd        0/1     Pending             0          7s
torch-reporting-657886c5f8-2cf85      0/1     Pending             0          6s
torch-reporting-657886c5f8-n2ptz      0/1     Init:0/1            0          6s
torch-swagger-6fbd9b8446-26skn        0/1     Pending             0          6s
torch-ui-6f6464cbd6-9bkkr             0/1     Pending             0          6s
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
