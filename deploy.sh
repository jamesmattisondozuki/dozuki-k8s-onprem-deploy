#!/bin/bash

CUSTOMER_NAME="$1"

if [[ "$#" -ne "1" ]]; then
  echo Must have customer name as arg.
  exit 1
fi

helm install $RELEASE oci://registry-1.docker.io/bitnamicharts/memcached
tar czvf chart.tgz chart/
helm install onprem chart.tgz --replace --debug
