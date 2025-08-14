#!/bin/bash

IMG=fcos-cvm

set -xe

TMPDIR=$(mktemp -d)
git clone --depth 1 https://github.com/coreos/custom-coreos-disk-images ${TMPDIR}

sudo podman build -t ${IMG} -f fedora-coreos/Containerfile fedora-coreos
sudo skopeo copy containers-storage:localhost/fcos-cvm:latest oci-archive:${IMG}
sudo -E ${TMPDIR}/custom-coreos-disk-images.sh --platform qemu \
	--ociarchive ${IMG} \
	--osname fedora-coreos
rm -rf "$TMPDIR"
sudo chown qemu:qemu ${IMG}-qemu.x86_64.qcow2
