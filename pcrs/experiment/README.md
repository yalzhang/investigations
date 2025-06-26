# Experiment: Looking at the PCR events on a FCOS 42 VM

This experiment boots a FCOS 42 VM with a TPM and OVMF. That way, the
behavior of the PCRs can be studied a bit closer.

To run the experiment, you can simply use
[scripts/install_vm.sh](/scripts/install_vm.sh). It should install and
boot the VM in your system, given you already installed `virt-install`
and `podman`.

To boot the system with secure boot enabled, run:

```bash
$ OVMF_CODE=/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd \
    OVMF_VARS_TEMPLATE=/usr/share/edk2/ovmf/OVMF_VARS.fd \
    ./scripts/install_vm.sh -k "$(cat <path_to_ssh_public_key>)" \
    -b ./config/simple.bu \
    -s next
```

After the boot, you can

```bash
$ tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements
```

To obtain the eventlog.

Feel free to make changes to the system, reboot it and observe changes.

Once you're done, [scripts/uninstall_vm.sh](/scripts/uninstall_vm.sh) should remove the
directory created by install-vm to fetch the Fedora CoreOS image.

## Results

We are also making the eventlog results obtained from the experiment
without modifying the FCOS image in any way, and can be obtained in
[results/eventlog-grub.md](results/eventlog-grub.md).
