#!/bin/bash
set -e

#
# This script is used to bootstrap a Kubernetes cluster sufficient to deply
# the Dozuki app in an on-prem environment.
#
#

get_distro() {
  source /etc/os-release

  case $ID in
  ubuntu|debian)
    echo "deb"
    ;;
  rhel|centos)
    echo "rhel"
    ;;
  esac

}

NODE_NAME=node1

underline () {
	echo -e "\e[4m$*\e[0m"
}


show_help () {
cat << EOM
Usage: $0
  -r/--reset		  : Reset the currently running K8s cluster before setup?
  -n/--node-name  : Specify the hostname for this node. Default: node1
  -h/--help		    : Show this help menu
EOM
}


while [[ ! $# -eq 0 ]]; do
	case "$1" in
		"-r"|"--reset")
			RESET_FLAG=1
			underline Reset flag in effect\!
			;;
		"-v"|"--verbose"|"-d"|"--debug")
		  set -x
		  ;;
		"-n"|"--node-name")
			if [[ -z "$2" ]]; then
				echo "--node-name is expecting <node name> as argument!"
				exit 1
			fi
			NODE_NAME="$2"
			shift
			;;
		*)
			show_help
			echo "Invalid arg: $1"
			exit 1
			;;
	esac
	shift
done


install () {
  if [[ "$(get_distro)" == "deb" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get -y  install "$@"
  else
    yum -y install "$@"
  fi
  return $?
}

update () {
  if [[ "$(get_distro)" == "rhel" ]]; then
    yum -y update
  else
    apt-get -y update
    DEBIAN_FRONTEND=noninteraactive apt-get -y upgrade
  fi
  return $?
}


reset_cluster () {
	underline "Updating containerd config and restarting it..."
	containerd config default > /etc/containerd/config.toml
	sed 's/\ \ \ \ \ \ \ \ \ \ \ \ Systemd.*$/\ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup\ \=\ true/' -i /etc/containerd/config.toml
	systemctl restart containerd

	set +e
	underline "Resetting kubernetes cluster..."
	rm -rf /etc/cni
	rm -rf /var/lib/cni
	rm -rf /run/flannel

	if ip link show | grep -q cni0; then
		ifconfig cni0 down
		ip link delete cni0
		ifconfig flannel.1 down
		ip link delete flannel.1
	fi
	set -e
	kubeadm reset --force


	underline "Flushing iptables, restarting kubelet..."
	iptables -F
	iptables -F -t nat
	systemctl restart kubelet
	systemctl restart containerd

	underline "Adding required iptables rules..."
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

	underline "Activating kernel modules..."
	modprobe ip_conntrack
	modprobe br_netfilter
	modprobe overlay
}

install_packages () {

	# clean yum cache
	#yum clean all

	# update, and install dependencies
	#yum -y update

  update

	install wget curl net-tools  git gcc make

  if systemctl is-active firewalld; then
	  yum -y remove firewalld
	fi

	if systemctl is-active ufw; then
	  apt remove -y --purge ufw
	fi

	[[ "$(get_distro)" == "rhel" ]] && install iptables-services --allowerasing || install iptables-persistent

}

disable_swap() {
	swapoff -a
}

disable_selinux () {
	setenforce 0
	sed 's/^SELINUX-=.*$/SELINUX=disabled/g' -i /etc/selinux/config
}

install_docker () {
	mkdir -p /etc/docker
	cat > /etc/docker/daemon.json << EOM
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  }
}
EOM

		wget -O - http://get.docker.com | bash

	systemctl enable docker
	systemctl start docker

}

install_k8s () {
	hostnamectl set-hostname $NODE_NAME

	if [[ "$(get_distro)" == "rhel" ]]; then
	# This overwrites any existing configuration in /etc/yum.repos.d/kubernetes.repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
  install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

  else
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    install  apt-transport-https ca-certificates curl gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    update
    install kubelet kubeadm kubectl
  fi



	if ! grep "$VAL" /etc/sysctl.conf; then
		underline Writing sysctl.
		echo "$VAL"  >> /etc/sysctl.conf
		sysctl -p
	fi
	systemctl enable --now kubelet



	underline "Flushing iptables, restarting kubelet..."
	iptables -F
	iptables -F -t nat
	systemctl restart kubelet
	systemctl restart containerd

	underline "Adding required iptables rules..."
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

	underline "Activating kernel modules..."
	modprobe ip_conntrack
	modprobe br_netfilter
	modprobe overlay

	if ! grep -q net.bridge.bridge-nf-call-iptables /etc/sysctl.conf; then
		echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
		sysctl -p 
	fi

	containerd config default > /etc/containerd/config.toml

	iptables-save > /etc/sysconfig/iptables
	systemctl enable iptables --now
	systemctl reload iptables
	sed s'/            SystemdCgroup.*$/            SystemdCgroup = true/' -i /etc/containerd/config.toml
	cat > /var/lib/kubelet/kubeadm-flags.env <<- EOM
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock"
EOM
	systemctl daemon-reload
	systemctl restart kubelet
	systemctl restart containerd
	kubeadm init --pod-network-cidr=10.244.0.0/16 |& tee current-bootstrap-info.txt
	
	export KUBECONFIG=/etc/kubernetes/admin.conf
	mkdir -p ~/.kube
	cp /etc/kubernetes/admin.conf ~/.kube/config
	curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
	chmod +x kubectl
	mv kubectl /usr/bin/kubectl


}

initialize_network () {
	# Install the Flannel network backend.

	underline "Untainting controlplane..."
	kubectl taint nodes --all node-role.kubernetes.io/control-plane-

	underline "... Installing plugins."
	ARCH=$(uname -m)
	  case $ARCH in
	    armv7*) ARCH="arm";;
	    aarch64) ARCH="arm64";;
	    x86_64) ARCH="amd64";;
	  esac
	mkdir -p /opt/cni/bin
	curl -O -L https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-$ARCH-v1.6.0.tgz
	tar -C /opt/cni/bin -xzf cni-plugins-linux-$ARCH-v1.6.0.tgz

	underline "... Applying flannel CNI."
	# kubectl patch node node1  -p '{ "spec": {"podCIDR": "10.244.0.0/16"} }'
	kubectl create ns kube-flannel
	kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

	mkdir -p /run/flannel

	cat > /run/flannel/flannel.env <<- EOM
	FLANNEL_NETWORK=10.244.0.0/16
	FLANNEL_SUBNET=10.244.0.1/24
	FLANNEL_MTU=1450
	FLANNEL_IPMASQ=true
	EOM

	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	cp /run/flannel/flannel.env /run/flannel/subnet.env

	helm repo add flannel https://flannel-io.github.io/flannel/
	helm install flannel --set podCidr="10.244.0.0/16" --namespace kube-flannel flannel/flannel

	cat <<- EOM
	Kubernetes init complete.
	
	You must now run setup_volumes.py, then edit the volume.yaml file and apply it in order to complete this setup.
	
	EOM
}

install_certmanager_crds () {
	# install the custom resource definitions for the certmanager...
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.crds.yaml
}



if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "$RESET_FLAG" == "1" ]]; then
    reset_cluster
  fi

  install_packages
  disable_swap
  disable_selinux
  install_docker
  install_k8s
  initialize_network
  install_certmanager_crds
else
  echo sourced
fi
