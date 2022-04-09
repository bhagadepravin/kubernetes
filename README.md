# Kubernetes // **Troubleshooting**

K8 Setup on CentOS 7

* **Master**
```bash
curl -s https://raw.githubusercontent.com/bhagadepravin/kubernetes/main/k8-setup.sh | sh -s
```
* **Worker**
```bash
curl -s https://raw.githubusercontent.com/bhagadepravin/kubernetes/main/k8-worker-setup.sh | sh -s
```

### commands
```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
 ```
```bash
journalctl -b -f -u kubelet.service
kubeadm token create --print-join-command
```


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
