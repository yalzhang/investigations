# PCR4

It measures the boot process, including attempted boot devices, and boot
code loaded and executed from the device.


## Events
- `EV_EFI_ACTION`: sha256 digest of the `Calling EFI Application from
  Boot Option` string.
- `EV_SEPARATOR`: Value `0000000` measured prior to the invocation of
  the first Ready to Boot call.
- `EV_EFI_BOOT_SERVICES_APPLICATION`: Authenticode hash of the shim
  binary.
- `EV_EFI_BOOT_SERVICES_APPLICATION`: Authenticode hash of the grub
  binary.
- `EV_EFI_BOOT_SERVICES_APPLICATION`: Authenticode hash of vmlinuz.


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
