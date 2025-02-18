#!/bin/bash

RELEASE="$1"

if [[ "$#" -ne "1" ]]; then
	echo "Require the deployment name as argument!"
	exit 1
fi

helm install $RELEASE oci://registry-1.docker.io/bitnamicharts/memcached

