# PCR5

It measures the GPT/Partition table.


## Events
- `EV_SEPARATOR`: Value `0000000` measured prior to the invocation of
  the first Ready to Boot call.
- `EV_EFI_GPT_EVENT`: According to spec, it shall contain the tagged
  hash of the GPT Table. The event must contain a UEFI_GPT_DATA
  structure (see table 15 in the [TCG PC Client Platform Firmware
  Profile
  Specification](https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf)).
- `EV_EFI_ACTION`: sha256 hash digest of the `Exit Boot Services
  Invocation` string.
- `EV_EFI_ACTION`: sha256 hash digest of the `Exit Boot Services
  Returned with Success` string.


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
