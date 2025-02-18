#!/bin/bash

# 
# hard-reset.sh: Reset a single-node k8s cluster back to a virgin state. 
# This script has been generatlly deprecated in favor of `setup-k8s.sh --reset``
#
# Requirements:
#  - cluster consists of a single node
#  - containerd as backend
#  - kubeadm, kubectl already installed
#  - running RHEL-variant
#  - using Flannel as CNI 
#
set -x
set -e



# Since on RHEL, use the Systemd cgroup driver for containerd...
echo "Updating containerd config and restarting it..."
containerd config default > /etc/containerd/config.toml
sed 's/\ \ \ \ \ \ \ \ \ \ \ \ Systemd.*$/\ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup\ \=\ true/' -i /etc/containerd/config.toml
systemctl restart containerd


echo "Resetting cluster..."

echo "   Destroy all previous CNI config..."
# Destroy all the CNI config.
rm -rf /etc/cni
rm -rf /var/lib/cni
rm -rf /run/flannel

if ip link show | grep -q cni0; then
	ifconfig cni0 down
	ip link delete cni0
	ifconfig flannel.1 down
	ip link delete flannel.1
fi

echo "   Force-reset kubeadm..."
kubeadm reset --force


echo "Flushing iptables, restarting kubelet..."
iptables -F
iptables -F -t nat
systemctl restart kubelet
systemctl restart containerd

echo "Adding required iptables rules..."
iptables -A INPUT -p tcp --dport 6443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A FORWARD -p tcp --dport 6443 -j ACCEPT
iptables -A FORWARD -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

iptables -A INPUT -p udp -m udp -m multiport --dports 10250:10300 -j ACCEPT
iptables -A FORWARD -p udp -m udp -m multiport --dports 10250:10300 -j ACCEPT

echo "Activating kernel modules..."
modprobe ip_conntrack
modprobe br_netfilter
modprobe overlay

echo "Kubeadm INIT..."
kubeadm init --pod-network-cidr=10.244.0.0/16 --container-runtime-endpoint=unix:///run/containerd/containerd.sock |& tee kubeadm-init-output.log

# Allows pods to be schedule on the controlplane, since this is a single-node cluster.
echo "Untainting controlplane..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "Installing CNI..."
echo "   Installing plugins..."
ARCH=$(uname -m)
  case $ARCH in
    armv7*) ARCH="arm";;
    aarch64) ARCH="arm64";;
    x86_64) ARCH="amd64";;
  esac
mkdir -p /opt/cni/bin
curl -O -L https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-$ARCH-v1.6.0.tgz
tar -C /opt/cni/bin -xzf cni-plugins-linux-$ARCH-v1.6.0.tgz

echo "... Applying flannel CNI."
# kubectl patch node node1  -p '{ "spec": {"podCIDR": "10.244.0.0/16"} }'
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

mkdir -p /run/flannel

cat > /run/flannel/flannel.env << EOM
FLANNEL_NETWORK=10.244.0.0/24
FLANNEL_SUBNET=10.244.0.1/16
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOM

cp /run/flannel/flannel.env /run/flannel/subnet.env
helm repo add flannel https://flannel-io.github.io/flannel/
helm install flannel --set podCidr="10.244.0.0/16" --namespace kube-flannel flannel/flannel



watch "kubectl get po -A"
