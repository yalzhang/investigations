#!/bin/bash

set -euo pipefail
# set -x

if [[ "${#}" -ne 1 ]]; then
	echo "Usage: $0 <path-to-ssh-public-key>"
	exit 1
fi

KEY=$1

./scripts/create-trustee-vm.sh "$KEY"

./scripts/populate-trustee-kbs.sh "$KEY"

./scripts/create-test-vm.sh "$KEY"
