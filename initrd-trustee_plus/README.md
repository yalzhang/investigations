# Initrd Trustee Integration

This guide demonstrates how to create an initrd image that communicates with a Trustee service to fetch encryption keys and decrypt a root image. This setup is particularly useful for confidential computing scenarios where secure key management is essential.

## Steps

1. Compile trustee-attester
```bash
git clone https://github.com/confidential-containers/guest-components.git
cd attestation-agent
cargo build -p kbs_protocol --bin trustee-attester --no-default-features --features "background_check,passport,openssl,bin,snp-attester"
```

If all succeeds, the binary will be `target/debug/trustee-attester`

2. Copy the binary to /usr/bin/trustee-attester and do a trial run, make sure you are able to fetch secrets from your trustee setup:
```bash
trustee-attester --url http://kbs-service.trustee-operator-system:8080 get-resource --path default/keyvaluepairs/key1
```

3. Files overview:

* `dracut/dracut.conf`
  - Ensures the sev_guest module is part of the initrd image we will build
  - Copy to `/etc/dracut.conf`

* `dracut/65aaclient/`
  - Contains `module-setup.sh` that includes all custom required binaries in the initrd image
  - Review the script to verify all required binaries/config files are included
  - Copy the entire directory to `/usr/lib/dracut/modules.d/`

* `scripts/aa-client-service.sh`
  - Contains the primary logic for the trustee demo
  - Copy to `/usr/bin/aa-client-service.sh`

* `systemd/aa-client.service`
  - The systemd service file
  - Copy to `/usr/lib/systemd/system/`

4. Guest setup:
For best results, *install* a guest VM from scratch. Manually partition the disk and make sure to enable LUKS for the root. For simplicity, choose standard partition although LVM should work.

5. Once all files are in place, make a backup of your initrd image so that you can select it from grub if things go wrong. Finally, regenerate the initrd image: `dracut -f`

6. Use lsinitrd to make sure the newly generated initrd image has everything we need.
For example, to check if the trustee-attester binary is included:
```bash
$ lsinitrd /boot/initramfs-5.14.0-553.el9.x86_64.img | grep trustee-attester
-rwxr-xr-x   1 root     root     21374320 Nov 28 11:55 usr/bin/trustee-attester
```

To check, if the sev-guest kernel module is present:
```bash
$ lsinitrd /boot/initramfs-5.14.0-553.el9.x86_64.img | grep sev
drwxr-xr-x   2 root     root            0 Nov 28 11:55 usr/lib/modules/5.14.0-553.el9.x86_64/kernel/drivers/virt/coco/sev-guest
-rw-r--r--   1 root     root        13424 Nov 28 11:55 usr/lib/modules/5.14.0-553.el9.x86_64/kernel/drivers/virt/coco/sev-guest/sev-guest.ko.xz
```

7. Reboot to the newly generated initrd image.

8. Debugging: The `aa-client-service.sh` script uses "info" statements for logging. To debug issues:
* Replace "info" statements with "echo" for more verbose output
* Collect boot logs using: `journalctl -b > boot.log`
* Common issues to check:
  - Verify network connectivity to Trustee service
  - Check if SEV attestation is working properly
  - Ensure all required binaries are present in initrd
  - Verify LUKS configuration






