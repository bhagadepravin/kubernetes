# Kubernetes // **Troubleshooting**


### commands
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
"Failed to run kubelet" err="failed to run Kubelet: misconfiguration: kubelet cgroup driver: \"systemd\" is different from docker cgroup driver: \"cgroupfs\"


journalctl -b -f -u kubelet.service

A minimal example of configuring the field explicitly:

vi kubeadm-config.yaml

# kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: v1.23.0
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: cgroupfs
Such a configuration file can then be passed to the kubeadm command:

kubeadm init --config kubeadm-config.yaml
```
