#!/bin/bash

IMG=fcos-cvm
ociarchive=${IMG}.tar

set -xe

TMPDIR=$(mktemp -d)
git clone --depth 1 https://github.com/coreos/custom-coreos-disk-images ${TMPDIR}

sudo podman build -t ${IMG} -f encrypt-disk/files/Containerfile  encrypt-disk/files
sudo skopeo copy containers-storage:localhost/fcos-cvm:latest oci-archive:${ociarchive}
sudo -E ${TMPDIR}/custom-coreos-disk-images.sh --platform qemu \
	--ociarchive fcos-cvm.tar \
	--osname fedora-coreos
rm -rf "$TMPDIR"
sudo chown qemu:qemu ${ociarchive}-qemu.x86_64.qcow2
