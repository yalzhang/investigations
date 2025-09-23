#!/bin/bash

set -euo pipefail
# set -x

if [[ "${#}" -ne 1 ]]; then
	echo "Usage: $0 <vm-name>"
	exit 1
fi

vm=$1
URL="--connect=qemu:///system"

mac="$(virsh "${URL}" --quiet domiflist "${vm}" | awk '{ print $5 }')"
virsh "${URL}" --quiet net-dhcp-leases default --mac "${mac}" | awk '{ print $5 }' | sed 's|/24||'
