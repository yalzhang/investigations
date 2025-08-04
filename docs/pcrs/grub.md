# Platform Configuration Registries (PCRs) on attestation

This document is not written to explain what a PCR is or how it works,
as there is a wide variety of documents and articles covering that topic
already available in the public.

This document aims to explain what measurements extend each PCR in the
case of a Fedora CoreOS node. Also, it covers which of those PCRs could
be used during the attestation of confidential cluster nodes.


# Methodology

This document is based on the results obtained on an experiment. A
Fedora CoreOS Virtual Machine is booted with an emulated TPM, UEFI
(OVMF), and enabled secure boot.

The experiment VM can be installed in your system by running
[scripts/install_vm.sh](/scripts/install_vm.sh). Note that you will need to
add your public ssh key into the butane config that is created through
that file. Also note that this it relies on libvirt, butane and
virt-install, so you will need to make sure that those are properly
installed in your system.

Once booted, the TPM eventlog and PCR values are extracted by

```{bash}
$ tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements
```

The TPM event log lets us inspect which measurements extend each of the
PCRs, where the measurement is coming from, and the measured digest of
each of those measurements.

Finally, the VM can be uninstalled from your system by runing
[scripts/uninstall_vm.sh](/scripts/uninstall_vm.sh).


# Results

The eventlog obtained through this little experiment is in
[eventlog.yaml](experiment/results/eventlog-grub.yaml).


# PCRs and their meaning

This is a list of the PCRs that we observe being extended in the system
described above. A further breakdown of the analysis can be found under
the files dedicated to each PCR, linked below:

- [PCR0](pcr0.md): Early platform firmware. It will depend upon the
  infrastructure/VM provider and the firmware used in it.
- [PCR1](pcr1.md): Data and configuration of the binaries measured in
  PCR0.
- [PCR2](pcr2.md): UEFI drivers and applications.
- [PCR3](pcr3.md): UEFI driver and application data.
- [PCR4](pcr4.md): Boot process, attempted boot devices and boot code
  loaded and executed from the device.
- [PCR5](pcr5.md): GPT/partition table.
- [PCR6](pcr6.md): Reserved for use by the host platform manufacturer.
  It's use may or may not be defined.
- [PCR7](pcr7.md): Secure boot state.
- [PCR8](pcr8.md): Grub commands and kernel command line (if the system
  is booting via grub).
- [PCR9](pcr9.md): Files read by grub (if the system is booting via
  grub).
- [PCR14](pcr14.md): MOK certificates.


## Expected PCR behavior accross boots and nodes and predictability

There are some PCR values that will or will not vary from one node to
another, or from one boot to the next one. In the following table we
collect what we expect to happen in those situations. Note we are
assuming that upgrades aren't happening accross boots. Another column
could cover that.

| PCR | Measurement                            | Consistent across nodes | Consistent across boots | Notes                                                                                | Predictable?            |
| :-- | :----                                  | :----                   | :----                   | :----                                                                                | :----                   |
| 0   | FW code                                | Yes                     | Yes                     |                                                                                      | Depends on the platform |
| 1   | FW config                              | Yes                     | Yes                     |                                                                                      | Depends on the platform |
| 2   | EFI executables and apps on the system | Yes                     | Yes                     |                                                                                      | Depends on the platform |
| 3   | EFI executable configuration           | Yes                     | Yes                     |                                                                                      | Depends on the platform |
| 4   | Boot loader and additional drivers     | Yes                     | Yes                     |                                                                                      | Yes                     |
| 5   | GPT                                    | No                      | Yes                     |                                                                                      |                         |
| 6   | Manufacturer measurements              | No                      | Yes                     | Up to VM provider/manufacturer to decide how to fill this.                           | Depends on the platform |
| 7   | Secure boot state                      | Yes                     | Yes                     |                                                                                      | Yes                     |
| 8   | Grub commands                          | No                      | No                      | Kernel command line among a big list of grub commands.                               | Not at the moment       |
| 9   | Files read by grub                     | No                      | No                      | The difficult bit is predicting which files grub is going to read.                   | Not at the moment       |
| 14  | Shim/MOK                               | Yes                     | Yes                     | Predictable, assuming MOK certificates aren't updated.                               | Partly                  |


# Conclusions

PCRS 4, 7 and 14 are the ones that are predictable, do not depend on the
platform and cover most of the key aspects needed to trust the boot
chain.


# Gaps

The kernel command line is another step in the boot chain that we are
not able to predict at the moment, if the system booting is doing it via
GRUB.


# References
- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
- https://gitlab.com/vkuznets/encrypt-rhel-image/-/blob/master/encrypt-rhel-image.py
