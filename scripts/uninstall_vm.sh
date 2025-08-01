#!/bin/bash

set -xe

while getopts "n:" opt; do
  case $opt in
	n) vm_name=$OPTARG ;;
	\?) echo "Invalid option"; exit 1 ;;
  esac
done

if [ -z "${vm_name}" ]; then
	echo "Please, specify the VM name"
	exit 1
fi

virsh destroy ${vm_name} || true
virsh undefine ${vm_name} --nvram --managed-save
