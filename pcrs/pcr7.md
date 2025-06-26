# PCR7

It measures the SecureBoot state.


## Events
- `EV_EFI_VARIABLE_DRIVER_CONFIG`: Contents of the SecureBoot variable.
  See table 14 on the
  [spec](https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf)
  for more information on the UEFI_VARIABLE_DATA structure.
- `EV_EFI_VARIABLE_DRIVER_CONFIG`: Contents of the PK UEFI variable
  data.
- `EV_EFI_VARIABLE_DRIVER_CONFIG`: Contents of the KEK UEFI variable
  data.
- `EV_EFI_VARIABLE_DRIVER_CONFIG`: Contents of the db UEFI variable
  data.
- `EV_EFI_VARIABLE_DRIVER_CONFIG`: Contents of the dbx UEFI variable
  data.
- `EV_SEPARATOR`: Value `0000000` measured prior to the invocation of
  the first Ready to Boot call.
- `EV_EFI_VARIABLE_AUTHORITY`: Hash of the db UEFI_VARIABLE_DATA
  structure. Shim measures the signators of all valid signatures.
- `EV_EFI_VARIABLE_AUTHORITY`: Hash of the SBatLevel UEFI_VARIABLE_DATA
  structure.
- `EV_EFI_VARIABLE_AUTHORITY`: Hash of the MokListRT UEFI_VARIABLE_DATA
  structure.


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
