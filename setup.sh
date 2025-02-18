#!/bin/bash

if ! test -f /etc/os-release; then
  echo "Fatal: must install on either a RedHat based, or Ubuntu-based system."
  exit 1
fi

source /etc/os-release

if [[ "$ID" == "ubuntu" ]]; then
  INSTALLER="apt-get -y install "
  UPDATE_CMD="apt-get -y update"
else
  INSTALLER="yum -y install "
  UPDATE_CMD="yum -y update"
fi

$UPDATE_CMD

$INSTALLER python3 python3-pip curl wget dialog

#### WELCOME PAGE
welcome_page () {
  dialog --checklist "Select actions:" \
  20 70 10 \
  "bootstrap-k8s" "Setup k8s cluster?" "on" \
  "edit-config" "Interactively edit deployment values?"   "on" \
  "deploy" "Deploy Dozuki onprem system?" "on" | read -a actions

  echo "${actions[@]}"
}

edit_config () {
  
}
