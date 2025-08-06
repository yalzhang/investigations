#!/bin/bash

set -e

KEY=$1
TRUSTEE_SSH_PORT=2222
VM_SSH_PORT=2223
STABLE_IMAGE="$(pwd)/fedora-coreos-42.20250705.3.0-qemu.x86_64.qcow2"
CUSTOM_IMAGE="$(pwd)/fcos-cvm-qemu.x86_64.qcow2"
TRUSTEE_PORT=8080

if [ -z "$KEY" ]; then
	echo "Please provide the public key"
	exit 1
fi

if [[ ! -f "${STABLE_IMAGE}" ]]; then
    # Download a fixed stable image that matches the one used for the container build with trustee
    wget "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/42.20250705.3.0/x86_64/fedora-coreos-42.20250705.3.0-qemu.x86_64.qcow2.xz"
    unxz "fedora-coreos-42.20250705.3.0-qemu.x86_64.qcow2.xz"
fi

scripts/install_vm.sh \
	-n trustee \
	-b configs/trustee.bu \
	-k "$(cat $KEY)" \
	-f \
	-p ${TRUSTEE_SSH_PORT} \
	-i ${STABLE_IMAGE} \
	-t ${TRUSTEE_PORT}

until curl http://127.0.0.2:${TRUSTEE_PORT}; do
  echo "Waiting for KBS to be available..."
  sleep 1
done
until ssh core@localhost \
	-p ${TRUSTEE_SSH_PORT} \
	-i "${KEY%.*}" \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	'sudo /usr/local/bin/populate_kbs.sh'; do
	echo "Waiting for KBS to be populate"
	sleep 1
done

scripts/install_vm.sh \
	-n vm \
	-b configs/luks.bu \
	-k "$(cat $KEY)" \
	-f \
	-p ${VM_SSH_PORT} \
	-i ${CUSTOM_IMAGE}
