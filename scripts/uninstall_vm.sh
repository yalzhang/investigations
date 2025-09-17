#!/bin/bash

set -euo pipefail
# set -x

URL="--connect=qemu:///system"

while getopts "n:" opt; do
  case $opt in
	n) vm_name=$OPTARG ;;
	\?) echo "Invalid option"; exit 1 ;;
  esac
done

if [ -z "${vm_name}" ]; then
	echo "Usage: $0 -n <vm-name>"
	exit 1
fi

virsh "${URL}" destroy ${vm_name} || true
virsh "${URL}" undefine ${vm_name} --nvram --managed-save
