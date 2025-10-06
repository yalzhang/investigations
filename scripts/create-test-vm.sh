#!/bin/bash

set -euo pipefail
# set -x

if [[ "${#}" -ne 1 ]]; then
	echo "Usage: $0 <path-to-ssh-public-key>"
	exit 1
fi

KEY=$1
CUSTOM_IMAGE="$(pwd)/fcos-cvm-qemu.x86_64.qcow2"

scripts/install_vm.sh \
	-n vm \
	-b configs/luks.bu \
	-k "$(cat "$KEY")" \
	-f \
	-i "${CUSTOM_IMAGE}" \
	-m 4096
