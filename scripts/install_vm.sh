#!/bin/bash

STREAM="stable"
VM_NAME="fcos-kbs"
VCPUS="2"
RAM_MB="5210"
DISK_GB="10"
PORT="2222"
OVMF_CODE=${OVMF_CODE:-"/usr/share/edk2/ovmf/OVMF_CODE_4M.secboot.qcow2"}
OVMF_VARS_TEMPLATE=${OVMF_VARS_TEMPLATE:-"/usr/share/edk2/ovmf/OVMF_VARS_4M.secboot.qcow2"}
TRUSTEE_PORT=""

set -xe

IMAGE="${HOME}/.local/share/libvirt/images/fedora-coreos-${STREAM}.qcow2"

force=false
dir=trustee
while getopts "k:b:n:f p:s:d:t:i:" opt; do
  case $opt in
	k) key=$OPTARG ;;
	b) butane=$OPTARG ;;
	f) force=true ;;
	n) VM_NAME=$OPTARG ;;
	p) PORT=$OPTARG ;;
	s) STREAM=$OPTARG ;;
	t) TRUSTEE_PORT=$OPTARG ;;
	i) IMAGE=$OPTARG ;;
	\?) echo "Invalid option"; exit 1 ;;
  esac
done

if [ -z "${key}" ]; then
	echo "Please, specify the public ssh key"
	exit 1
fi
if [ -z "${butane}" ]; then
	echo "Please, specify the butane configuration file"
	exit 1
fi


if [ ! -e  "${IMAGE}" ] ; then
	image=$(podman run --pull=newer --rm -v "${HOME}/.local/share/libvirt/images/":/data -w /data \
		quay.io/coreos/coreos-installer:release download -s $STREAM -p qemu -f qcow2.xz --decompress)
	mv "${HOME}/.local/share/libvirt/images/$image" $IMAGE
fi

mkdir -p tmp
butane_name="$(basename ${butane})"
IGNITION_FILE="tmp/${butane_name%.bu}.ign"
IGNITION_CONFIG="$(pwd)/${IGNITION_FILE}"
bufile="./tmp/${butane_name}"
sed "s|<KEY>|$key|g" $butane > ${bufile}
butane_args=()
if [[ -d ${butane%.bu} ]]; then
	butane_args=("--files-dir" "${butane%.bu}")
fi
podman run --interactive --rm --security-opt label=disable \
	--volume "$(pwd)":/pwd \
	--volume "${bufile}":/config.bu:z \
	--workdir /pwd \
	quay.io/coreos/butane:release \
	--pretty --strict /config.bu --output "/pwd/${IGNITION_FILE}" \
	"${butane_args[@]}"

IGNITION_DEVICE_ARG=(--qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_CONFIG}")

chcon --verbose --type svirt_home_t ${IGNITION_CONFIG}

if [ "$force" = "true" ]; then
	virsh destroy ${VM_NAME} || true
	virsh undefine ${VM_NAME} --nvram --managed-save || true
fi
args=""
if [ ! -z "$TRUSTEE_PORT" ]; then
	args=",portForward1.range.start=${TRUSTEE_PORT},portForward1.range.to=8080,portForward1.proto=tcp"
fi
virt-install --name="${VM_NAME}" --vcpus="${VCPUS}" --memory="${RAM_MB}" \
	--os-variant="fedora-coreos-$STREAM" --import --graphics=none \
	--disk="size=${DISK_GB},backing_store=${IMAGE}" \
	--network backend.type=passt,portForward0.range.start=${PORT},portForward0.range.to=22,portForward0.proto=tcp${args} \
	--noautoconsole \
	--boot uefi,loader=${OVMF_CODE},loader.readonly=yes,loader.type=pflash,nvram.template=${OVMF_VARS_TEMPLATE} \
	--tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
	"${IGNITION_DEVICE_ARG[@]}"
