# PCR0

It measures the early Platform Firmware.


## Events

- `EV_NO_ACTION`, with zero-digest, which is the first event in the
  event log according to the specification.
- `EV_S_CRTM_VERSION`: SRTM version identifier.
- `EV_EFI_PLATFORM_FIRMWARE_BLOB`: UEFI Boot services and UEFI Run Time
  Services.
- `EV_EFI_PLATFORM_FIRMWARE_BLOB`: UEFI Boot services and UEFI Run Time
  Services.
- `EV_SEPARATOR`: Value `0000000` measured prior to the invocation of
  the first Ready to Boot call.


## Notes

Note that these events are the result of booting a libvirt VM with OVMF
firmware. It may change depending on the infrastructure provider, be it
bare metal, any other hypervisor/firmware combination, or cloud
provider.


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
