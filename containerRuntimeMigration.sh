#base article here https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/change-runtime-containerd/

kubectl drain $(hostname | tr '[:upper:]' '[:lower:]') --ignore-daemonsets &
echo waiting 30 seconds for node $(hostname) to be drained...
sleep 30
sudo systemctl stop kubelet
sudo systemctl disable docker --now
sudo yum remove docker-ce docker-ce-cli -y
sudo modprobe overlay
sudo modprobe br_netfilter
sudo cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo cat << EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo yum install containerd -y
sudo mkdir  -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's/disabled_plugins.*/#disabled_plugins/' /etc/containerd/config.toml
sudo sed -i 's/cgroupDriver: cgroupfs/cgroupDriver: systemd/' /var/lib/kubelet/config.yaml
sudo systemctl restart containerd
sudo sed -i.bak 's/KUBELET_KUBEADM_ARGS=\".*/KUBELET_KUBEADM_ARGS=\"--container-runtime=remote  --container-runtime-endpoint=unix:\/\/\/run\/containerd\/containerd.sock\"/' /var/lib/kubelet/kubeadm-flags.env

#we should check if the patch went through, as I found on one cluster, it did not, which affected further operations.
kubectl patch no  $(hostname | tr '[:upper:]' '[:lower:]') --patch '{"metadata": {"annotations": {"kubeadm.alpha.kubernetes.io/cri-socket": "unix:///run/containerd/containerd.sock"}}}'
#Manually running the patch at a later time succeeded with no issues.


sudo systemctl start kubelet

kubectl uncordon  $(hostname | tr '[:upper:]' '[:lower:]')

kubectl get nodes -o wide

sudo rm /var/run/docker{shim.sock,.sock}

sudo sh -c 'echo "#!/bin/sh" > /sbin/docker && chmod 0100 /sbin/docker'
