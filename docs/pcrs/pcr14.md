# PCR14

It measures MOK certificates.


## Events

The event digests measure the contents of the UEFI variables listed
below:

- EV_IPL: "MokList\0"
- EV_IPL: "MokListX\0"
- EV_IPL: "MokListTrusted\0"


## Note

In a system that is already running, the extended values can be
extracted by calculating the sha256 hash of the files under
`/sys/firmware/efi/mok-variables/`. At some point we will look into how
to predict the measured values out of a list of certificates, but not
yet.


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
