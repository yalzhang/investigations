#!/bin/bash

STREAM="stable"
VM_NAME="fcos-kbs"
VCPUS="2"
RAM_MB="5210"
DISK_GB="10"
OVMF_CODE=${OVMF_CODE:-"/usr/share/edk2/ovmf/OVMF_CODE_4M.secboot.qcow2"}
OVMF_VARS_TEMPLATE=${OVMF_VARS_TEMPLATE:-"/usr/share/edk2/ovmf/OVMF_VARS_4M.secboot.qcow2"}
key=""

URL="--connect=qemu:///system"

set -euo pipefail
# set -x

force=false
while getopts "k:b:n:fi:" opt; do
  case $opt in
	k) key=$OPTARG ;;
	b) butane=$OPTARG ;;
	f) force=true ;;
	n) VM_NAME=$OPTARG ;;
	i) image=$OPTARG ;;
	\?) echo "Invalid option"; exit 1 ;;
  esac
done

usage() {
	echo "Usage: $0 -z <path-ssh-pubkey> -b <path-to-butane-config> -z <path-to-qcow2-image>"
}

if [ -z "${key}" ]; then
	echo "Please, specify the public ssh key"
	usage
	exit 1
fi
if [ -z "${butane}" ]; then
	echo "Please, specify the butane configuration file"
	usage
	exit 1
fi
if [ -z "${image}" ]; then
	echo "Please, specify the image to use"
	usage
	exit 1
fi

mkdir -p tmp
butane_name="$(basename ${butane})"
IGNITION_FILE="tmp/${butane_name%.bu}.ign"
IGNITION_CONFIG="$(pwd)/${IGNITION_FILE}"
bufile="./tmp/${butane_name}"
if [[ "$VM_NAME" == "vm" ]]; then
	IP="$(./scripts/get-ip.sh trustee)"
	sed "s|<KEY>|$key|g" $butane | sed "s/<IP>/$IP/" > ${bufile}
elif [[ "$VM_NAME" == "existing-trustee" ]]; then
	sed "s|<KEY>|key|g;
	     s|<IP>|$(ip route | grep virbr0 | cut -d' ' -f9)|g;
	     s|pin-trustee.ign|ignition-clevis-pin-trustee|g" "$butane" > "$bufile"
else
	sed "s|<KEY>|$key|g" $butane > ${bufile}
fi

butane_args=()
if [[ -d ${butane%.bu} ]]; then
	butane_args=("--files-dir" "${butane%.bu}")
fi
podman run --interactive --rm --security-opt label=disable \
	--volume "$(pwd)":/pwd \
	--volume "${bufile}":/config.bu:z \
	--workdir /pwd \
	quay.io/confidential-clusters/butane:clevis-pin-trustee \
	--pretty --strict /config.bu --output "/pwd/${IGNITION_FILE}" \
	"${butane_args[@]}"

IGNITION_DEVICE_ARG=(--qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_CONFIG}")

chcon --verbose --type svirt_home_t ${IGNITION_CONFIG}

if [ "$force" = "true" ]; then
	virsh "${URL}" destroy ${VM_NAME} || true
	virsh "${URL}" undefine ${VM_NAME} --nvram --managed-save || true
fi

virt-install "${URL}" \
	--name="${VM_NAME}" --vcpus="${VCPUS}" --memory="${RAM_MB}" \
	--os-variant="fedora-coreos-$STREAM" --import --graphics=none \
	--disk="size=${DISK_GB},backing_store=${image}" \
	--noautoconsole \
	--boot uefi,loader=${OVMF_CODE},loader.readonly=yes,loader.type=pflash,nvram.template=${OVMF_VARS_TEMPLATE} \
	--tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
	"${IGNITION_DEVICE_ARG[@]}"
