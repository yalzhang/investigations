# PCR1

It measures firmware configuration data, related to the binaries
measured in PCR0.


## Events

- `EV_PLATFORM_CONFIG_FLAGS`:
- `EV_PLATFORM_CONFIG_FLAGS`:
- `EV_PLATFORM_CONFIG_FLAGS`:
- `EV_PLATFORM_CONFIG_FLAGS`:
- `EV_EFI_VARIABLE_BOOT`:
- `EV_EFI_VARIABLE_BOOT`:
- `EV_EFI_VARIABLE_BOOT`:
- `EV_EFI_VARIABLE_BOOT`:
- `EV_SEPARATOR`: Value `0000000` measured prior to the invocation of
  the first Ready to Boot call.


## Notes

The events measured in this PCR will change based on the platform
firmware, and its configuration.


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
