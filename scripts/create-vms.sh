#!/bin/bash

set -e

KEY=$1
TRUSTEE_SSH_PORT=2222
VM_SSH_PORT=2223
IMAGE=$(pwd)/fcos-cvm.tar-qemu.x86_64.qcow2
TRUSTEE_PORT=8080

if [ -z "$KEY" ]; then
	echo "Please provide the public key"
	exit 1
fi

scripts/install_vm.sh  -n trustee  -b trustee/config.bu -k "$(cat $KEY)" -f  -p ${TRUSTEE_SSH_PORT} \
	-i ${IMAGE} -d trustee -t ${TRUSTEE_PORT}

until curl http://127.0.0.2:${TRUSTEE_PORT}; do
  echo "Waiting for KBS to be available..."
  sleep 1
done
until ssh core@localhost -p ${TRUSTEE_SSH_PORT} -i coreos.key \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  'sudo /usr/local/bin/populate_kbs.sh'; do
	echo "Waiting for KBS to be populate"
	sleep 1
done

scripts/install_vm.sh  -n vm  -b encrypt-disk/config.bu -k "$(cat $KEY)" -f  -p ${VM_SSH_PORT} \
	-i ${IMAGE}
