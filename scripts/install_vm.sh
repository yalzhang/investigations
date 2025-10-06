#!/bin/bash

set -euo pipefail
# set -x

force=false
while getopts "k:b:n:fi:m:" opt; do
  case $opt in
	k) key=$OPTARG ;;
	b) butane=$OPTARG ;;
	f) force=true ;;
	n) VM_NAME=$OPTARG ;;
	i) image=$OPTARG ;;
	m) RAM_MB=$OPTARG ;;
	\?) echo "Invalid option"; exit 1 ;;
  esac
done

key="${key:-}"
butane="${butane:-}"
VM_NAME="${VM_NAME:-fcos-kbs}"
image="${image:-}"
RAM_MB="${RAM_MB:-2048}"

OVMF_CODE=${OVMF_CODE:-"/usr/share/edk2/ovmf/OVMF_CODE_4M.secboot.qcow2"}
OVMF_VARS_TEMPLATE=${OVMF_VARS_TEMPLATE:-"/usr/share/edk2/ovmf/OVMF_VARS_4M.secboot.qcow2"}
OVMF_VARS_DEFAULT="${OVMF_VARS:-$PWD/OVMF_VARS_CUSTOM.qcow2}"

OVMF_VARS="tmp/OVMF_VARS_${VM_NAME}.qcow2"

STREAM="stable"
VCPUS="2"
DISK_GB="20"
URL="--connect=qemu:///system"

usage() {
	echo "Usage: $0 -k <path-ssh-pubkey> -b <path-to-butane-config> -i <path-to-qcow2-image>"
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

args=()

# Setup custom Secure Boot vars only if the file exists
if [[ -f "${OVMF_VARS_DEFAULT}" ]]; then
	cp "${OVMF_VARS_DEFAULT}" "${OVMF_VARS}"

	loader="loader=${OVMF_CODE},loader.readonly=yes,loader.type=pflash,loader_secure=yes"
	nvram="nvram=${OVMF_VARS},nvram.template=${OVMF_VARS_TEMPLATE}"
	features="firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=yes"

	args+=("--boot")
	args+=("uefi,${loader},${nvram},${features}")

	args+=("--tpm")
	args+=("backend.type=emulator,backend.version=2.0,model=tpm-tis")

	# Automatically connect to the console for this case
	args+=('--autoconsole')
	args+=('text')
else
	args+=("--boot")
	args+=("uefi,loader=${OVMF_CODE},loader.readonly=yes,loader.type=pflash,nvram.template=${OVMF_VARS_TEMPLATE}")

	args+=("--tpm")
	args+=("backend.type=emulator,backend.version=2.0,model=tpm-tis")

	args+=('--noautoconsole')
fi

virt-install "${URL}" \
	--name="${VM_NAME}" \
	--vcpus="${VCPUS}" \
	--memory="${RAM_MB}" \
	--os-variant="fedora-coreos-$STREAM" \
	--import \
	--disk="size=${DISK_GB},backing_store=${image}" \
	"${IGNITION_DEVICE_ARG[@]}" \
	"${args[@]}"
