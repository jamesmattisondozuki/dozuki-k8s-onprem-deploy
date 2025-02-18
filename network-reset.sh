#!/bin/bash

#
# Forcibly reset the Kubernetes network backend. Completely removes it, flushes iptables, reinstalls Flannel
# 

read -p "Really reset the Kubernetes network backend?" YN
case "$YN" in
	y|Y|Yes|yes)
		echo "Ok. Resetting."
		;;
	*)
		echo "Not making changes."
		exit 0
		;;
esac

ifconfig cni0 down
ip link delete cni0
ifconfig flannel.1 down
ip link delete flannel.1

iptables -F
iptables -F -t nat
systemctl restart kubelet
systemctl restart containerd


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

modprobe ip_conntrack
modprobe br_netfilter
modprobe overlay

systemctl restart containerd
systemctl restart kubelet

kubectl delete secret -n kube-flannel sh.helm.release.v1.flannel.v1 

helm install flannel --set podCidr="10.244.0.0/16" --namespace kube-flannel flannel/flannel --replace
