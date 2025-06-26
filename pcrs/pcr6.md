# PCR6

It is reserved for use by the host platform manufacturer.


## Events
- `EV_SEPARATOR`: Value `0000000` measured prior to the invocation of
  the first Ready to Boot call.


## Notes

Note that as it is reserved for the host platform manufacturer, this PCR
will vary from one platform to another. According to the
[spec](https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf),
the purpose of the PCR may or may not be defined.


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
