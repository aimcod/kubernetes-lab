#note I already had swap deployed. E.G.: sed -i s/"\/swapfile"/"#\/swapfile"/ /etc/fstab

#run as root.

firewall-cmd --permanent --zone=trusted --add-port=6443/tcp 
firewall-cmd --permanent --zone=trusted --add-port=2379-2380/tcp
firewall-cmd --permanent --zone=trusted --add-port=10251/tcp
firewall-cmd --permanent --zone=trusted --add-port=10252/tcp
firewall-cmd --permanent --zone=trusted --add-port=10250/tcp
firewall-cmd --permanent --zone=trusted --add-port=30000-32767/tcp
firewall-cmd --permanent --zone=trusted --add-port=80/tcp
firewall-cmd --permanent --zone=trusted --add-port=443/tcp
firewall-cmd --permanent --zone=trusted --add-port=22/tcp
firewall-cmd --reload
firewall-cmd --list-all
modprobe overlay
modprobe br_netfilter
cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
cat << EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo apt update
sudo apt install containerd
mkdir  -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sed -i s/SystemdCgroup = false/SystemdCgroup = true/ /etc/containerd/config.toml
systemctl restart containerd

#the following two lines are based on the official K8s native package manager installation documentation.
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt-cache policy kubelet | head -n 20 
#^this is not necessary. We're actually using the command subsitution below, to get the second to last version
#note that the author of the course performs this in order to demonstrate a k8s upgrade later on.
#I will post my own upgrade script later on, as I have I made for work.

VERSION=$(apt-cache policy kubelet | head -n 7 | tail -n 1 | cut -d' ' -f 6)
apt install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION

apt-mark hold kubelet kubeadm kubectl containerd
systemctl enable --now containerd kubelet

#don't go past this point if you're on a worker node.

kubeadm init

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml

kubectl get nodes

kubectl get pods -A

#we can generate a join command with a 364 day ttl. by default ttl is 24h. after that, we'd have to generate a new token if we want to add extra nodes.
#--ttl 0 will create a permanent token.
kubeadm token create --ttl 8760h --print-join-command

#we can delete the first in the list token by running:
kubeadm token delete $(kubeadm token list | awk 'FNR==2 {print $1}')



