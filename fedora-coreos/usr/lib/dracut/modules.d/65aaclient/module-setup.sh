#!/bin/bash

check() {
    # Always include the module for now
    return 0
}

depends() {
    echo crypt systemd network
    return 0
}

install () {
    inst $systemdsystemunitdir/aa-client.service
    inst /usr/libexec/aa-client
    inst /usr/bin/trustee-attester

    inst curl
    inst cryptsetup
    inst tr
    inst lsblk
    inst mktemp
    inst base64
    inst /usr/lib/systemd/systemd-reply-password

    systemctl -q --root "$initdir" add-wants initrd.target aa-client.service

    # need to figure out why systemd-unit-file get x mode
    chmod -x $systemdsystemunitdir/aa-client.service

    # need network -- figure out how to do it without chaning the command line
    echo "rd.neednet=1" >  "${initdir}/etc/cmdline.d/65aa-client.conf"
}
