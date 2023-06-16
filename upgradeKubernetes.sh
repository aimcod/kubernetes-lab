# based on this https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
sudo sed -i.bak 's/exclude=kube\*/#exclude=kube\*/' /etc/yum.repos.d/kubernetes.repo

for ver in 4 5 6 7
do

VERSION=$(yum list --showduplicates kubeadm --disableexcludes=kubernetes -y | grep 1.2$ver| tail -n 1 | head -n 1 | cut -d' ' -f24 | cut -d'-' -f1)
if [ $(echo $VERSION | cut -d'.' -f2) -le $(rpm -qa | grep kubeadm | cut -d'.' -f2) ]
then
echo kubeadm-$VERSION is already installed. Skipping rope...
continue
else
sudo yum install -y kubeadm-$VERSION --disableexcludes=kubernetes
fi

if [ ! -z "$(kubectl get node $(hostname | tr '[:upper:]' '[:lower:]') | grep control-plane)" ]

then
echo Upgrading Control Plane Node!
read -p "Press any key to continue:"

        sudo kubeadm version

        sudo kubeadm upgrade plan

        read -p "Please review the upgrade plan details above and press a key to continue if you agree it's safe."

        sudo kubeadm upgrade apply v$VERSION
else

        sudo kubeadm upgrade node
fi

kubectl drain $(hostname | tr '[:upper:]' '[:lower:]') --ignore-daemonsets
sudo yum install -y kubelet-$VERSION kubectl-$VERSION --disableexcludes=kubernetes
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo kubeadm init phase kubelet-start
kubectl uncordon  $(hostname | tr '[:upper:]' '[:lower:]')

kubectl get nodes

read -p "Please review the previou upgrade step, make sure all notes are on $VERSION, then press any key to continue!"

done
sudo sed -i.bak 's/#exclude=kube\*/exclude=kube\*/' /etc/yum.repos.d/kubernetes.repo
