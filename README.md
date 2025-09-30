# Investigations for Confidential Clusters

Work in progress documents about Confidential Clusters.

## Start fcos VM
```bash
scripts/install_vm.sh  -b config.bu -k "$(cat coreos.key.pub)"
```

## Remove fcos VM
```bash
scripts/uninstall_vm.sh  -n <vm_name>"
```

## Example with local VMs, attestation and disk encryption

Currently, ignition does not support encrypting the disk using trustee (see this 
[RFC](https://github.com/coreos/ignition/issues/2099) for more details). Therefore, we need to build a custom initramfs
which contains the trustee attester, and the KBS information hardcoded in the setup script.

Build the Fedora CoreOS or Centos Stream CoreOS image with the custom initrd:
```bash
cd coreos
# Centos Stream CoreOS image
just os=scos build oci-archive osbuild-qemu
# Fedora CoreOS image
just build oci-archive osbuild-qemu
```

In this example, we use 2 VMs, the first for running the trustee server while the second VM has been attested and its
root disk is encrypted using the secret stored in Trustee.

As already mentioned, the information are hardcoded in the initial script since we lack ignition support. Hence, if the
entire setup feels rigid and manual, it will improve in the future with the ignition extension.

Both VMs are created from the same image in order to retrieve the PCR registers from the TPM. This step and the VM can
be avoided once we are able to pre-calculate the PCRs.

The script `create_vms.sh`:
  1. launches the first VM with Trustee
  2. waits until Trustee is reachable at port `8080`
  3. populates the KBS with the reference values, the attestation policy for register 4, 7, and 14, and the secret
  4. creates the second VM which will perform the attestation in order to encrypt its root disk

```bash
scripts/create-vms.sh coreos.key.pub 
```

### Example with the Confidential Clusters operator and a local VM

If you have deployed Confidential Clusters with Trustee, and its KBS and register server are available at ports `8080` and `8000`, and the VM PCR values are configured with Trustee, you can instead run

```bash
scripts/create-existing-trustee.sh coreos.key.pub
```

to only create the test VM, not the Trustee VM.
This assumes that libvirt's bridge to connect to your host is `virbr0`.
This bridge may not exist on your system yet, in which case you can simply run the script again.
If you are using `firewalld`, this may require allowing the respective ports:

```bash
firewall-cmd --zone=libvirt --add-port=8080/tcp --permanent
firewall-cmd --zone=libvirt --add-port=8000/tcp --permanent
firewall-cmd --reload
```
