# PCR8

In the GRUB case, this PCR contains the grub commands and the kernel
command line.


## Events


### GRUB

In the case GRUB is used to boot the system, it extends PCR8 with a
bunch of EV_IPL events with the grub commands needed to boot the system.
All of them contain an event string, which consists of a prefix and the
command. The prefix can be `grub_cmd: `, `kernel_cmdline: ` or
`module_cmdline: `. The hash digest that extends the PCR on each event
is the event string without the prefix.

These are the logged events in the experiment:

- EV_IPL: "grub_cmd: [ -e (md/md-boot) ]\0"
- EV_IPL: "grub_cmd: [ -f (hd0,gpt2)/EFI/fedora/bootuuid.cfg ]\0"
- EV_IPL: "grub_cmd: [ -n  ]\0" EV_IPL: "grub_cmd: search --label boot --set prefix --no-floppy\0"
- EV_IPL: "grub_cmd: [ -d (hd0,gpt3)/grub2 ]\0"
- EV_IPL: "grub_cmd: set prefix=(hd0,gpt3)/grub2\0"
- EV_IPL: "grub_cmd: configfile (hd0,gpt3)/grub2/grub.cfg\0"
- EV_IPL: "grub_cmd: [ -d (md/md-boot)/grub2 ]\0"
- EV_IPL: "grub_cmd: [ -f (hd0,gpt3)/grub2/bootuuid.cfg ]\0"
- EV_IPL: "grub_cmd: [ -n  ]\0"
- EV_IPL: "grub_cmd: search --label boot --set boot --no-floppy\0"
- EV_IPL: "grub_cmd: set root=hd0,gpt3\0"
- EV_IPL: "grub_cmd: [ -f (hd0,gpt3)/grub2/grubenv ]\0"
- EV_IPL: "grub_cmd: load_env -f (hd0,gpt3)/grub2/grubenv\0"
- EV_IPL: "grub_cmd: [ -f (hd0,gpt3)/grub2/console.cfg ]\0"
- EV_IPL: "grub_cmd: source (hd0,gpt3)/grub2/console.cfg\0"
- EV_IPL: "grub_cmd: serial --speed=115200\0"
- EV_IPL: "grub_cmd: terminal_input serial console\0"
- EV_IPL: "grub_cmd: terminal_output serial console\0"
- EV_IPL: "grub_cmd: [ xy = xy ]\0"
- EV_IPL: "grub_cmd: menuentry_id_option=--id\0"
- EV_IPL: "grub_cmd: source (hd0,gpt3)/grub2/05_ignition.cfg\0"
- EV_IPL: "grub_cmd: set ignition_firstboot=\0"
- EV_IPL: "grub_cmd: [ -f /ignition.firstboot ]\0"
- EV_IPL: "grub_cmd: set ignition_network_kcmdline=\0"
- EV_IPL: "grub_cmd: source /ignition.firstboot\0"
- EV_IPL: "grub_cmd: set ignition_firstboot=ignition.firstboot \0"
- EV_IPL: "grub_cmd: [ xy = xy ]\0"
- EV_IPL: "grub_cmd: set timeout_style=menu\0"
- EV_IPL: "grub_cmd: set timeout=1\0"
- EV_IPL: "grub_cmd: [ -f (hd0,gpt3)/grub2/user.cfg ]\0"
- EV_IPL: "grub_cmd: blscfg\0"
- EV_IPL: "grub_cmd: load_video\0"
- EV_IPL: "grub_cmd: [ xy = xy ]\0"
- EV_IPL: "grub_cmd: insmod all_video\0"
- EV_IPL: "grub_cmd: set gfxpayload=keep\0"
- EV_IPL: "grub_cmd: insmod gzio\0"
- EV_IPL: "grub_cmd: linux (hd0,gpt3)/boot/ostree/fedora-coreos-c92920b5bb738472611283bf81bb2592a8d52dae661a0548d711c953f464fedb/vmlinuz-6.14.11-300.fc42.x86_64\
    \ rw ignition.firstboot mitigations=auto,nosmt ostree=/ostree/boot.1/fedora-coreos/c92920b5bb738472611283bf81bb2592a8d52dae661a0548d711c953f464fedb/0\
    \ ignition.platform.id=qemu console=tty0 console=ttyS0,115200n8\0"
- EV_IPL: "kernel_cmdline: (hd0,gpt3)/boot/ostree/fedora-coreos-c92920b5bb738472611283bf81bb2592a8d52dae661a0548d711c953f464fedb/vmlinuz-6.14.11-300.fc42.x86_64\
    \ rw ignition.firstboot mitigations=auto,nosmt ostree=/ostree/boot.1/fedora-coreos/c92920b5bb738472611283bf81bb2592a8d52dae661a0548d711c953f464fedb/0\
    \ ignition.platform.id=qemu console=tty0 console=ttyS0,115200n8\0"
- EV_IPL: "grub_cmd: initrd (hd0,gpt3)/boot/ostree/fedora-coreos-c92920b5bb738472611283bf81bb2592a8d52dae661a0548d711c953f464fedb/initramfs-6.14.11-300.fc42.x86_64.img\0"


## References

- https://trustedcomputinggroup.org/wp-content/uploads/TCG-PC-Client-Platform-Firmware-Profile-Version-1.06-Revision-52_pub-3.pdf
- https://github.com/uapi-group/specifications/blob/main/specs/linux_tpm_pcr_registry.md
