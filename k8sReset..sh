sudo kubeadm reset -f
rm -rf $HOME/.kube
sudo rm -rf /root/.kube
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/kubernetes
sudo systemctl restart kubelet containerd
