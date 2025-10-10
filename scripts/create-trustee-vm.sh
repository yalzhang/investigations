#!/bin/bash

set -euo pipefail
# set -x

if [[ "${#}" -ne 1 ]]; then
	echo "Usage: $0 <path-to-ssh-public-key>"
	exit 1
fi

KEY=$1
STABLE_IMAGE="/var/lib/libvirt/images/fedora-coreos-42.20250705.3.0-qemu.x86_64.qcow2"

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
	-i "${STABLE_IMAGE}"
