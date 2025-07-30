# PCR9

Files read by grub.


## Events

The events contain the digest of the file contents.

- `EV_IPL`: "(hd0,gpt2)/EFI/fedora/grub.cfg\0"
- `EV_IPL`: "(hd0,gpt2)/EFI/fedora/grub.cfg\0"
- `EV_IPL`: "(hd0,gpt3)/grub2/grub.cfg\0"
- `EV_IPL`: "(hd0,gpt3)/grub2/grubenv\0"
- `EV_IPL`: "(hd0,gpt3)/grub2/console.cfg\0"
- `EV_IPL`: "(hd0,gpt3)/grub2/05_ignition.cfg\0"
- `EV_IPL`: "/ignition.firstboot\0"
- `EV_IPL`: "(hd0,gpt3)/loader/entries//ostree-1.conf\0"
- `EV_IPL`: "(hd0,gpt3)/boot/ostree/fedora-coreos-c92920b5bb738472611283bf81bb2592a8d52dae661a0548d711c953f464fedb/vmlinuz-6.14.11-300.fc42.x86_64\0"
- `EV_IPL`: "(hd0,gpt3)/boot/ostree/fedora-coreos-c92920b5bb738472611283bf81bb2592a8d52dae661a0548d711c953f464fedb/initramfs-6.14.11-300.fc42.x86_64.img\0"


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
