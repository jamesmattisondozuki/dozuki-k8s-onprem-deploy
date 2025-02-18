#!/bin/bash
underline () {
	echo -e "\e[4m$@\e[0m"# Variables
}                             TARBALL="docker-images-bundle.tar"

if [[ ! -f "$TARBALL" ]]; then
  echo "Error: Decompressed tarball $TARBALL not found!"
  exit 1
fi

underline "Loading docker images into containerd. This may take quite a while."
echo Unpacking contents...
if ! ctr -n k8s.io images import $TARBALL --debug; then
  echo "Failed to import images!"
  exit 1
fi

underline "Images successfully loaded into containerd."
