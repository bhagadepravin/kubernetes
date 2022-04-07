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
```
