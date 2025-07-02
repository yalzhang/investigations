#!/bin/bash
. /lib/dracut-lib.sh
set -x

# Configuration
KBS_URL="http://10.72.140.122:31968"
ROOT_DEVICE="/dev/vda4"
CRYPT_ROOT_NAME="luks-root"
BOOT_DEVICE="/dev/disk/by-label/boot"
BOOT_MOUNT="/mnt/boot_partition"
MARKER_FILE="${BOOT_MOUNT}/.trustee_done"
CRYPTTAB_FILE="/sysroot/etc/crypttab"
MAX_RETRY_ATTEMPTS=3
RETRY_DELAY=5

# temp configuration
TEMP_DIR=$(mktemp -d /tmp/secure_attestation_XXXXXX)
PASSPHRASE_FILE="${TEMP_DIR}/passphrase"
OLD_PASS_FILE="${TEMP_DIR}/old_passphrase"

# Make sure the safety of temp files
umask 077
# Clean function - make sure it is always executed
cleanup() {
    # Securely clean the sensitive data from memory
    if [ -n "${passphrase}" ]; then
        passphrase="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    fi
    
    # umount the mountpoint
    umount "${BOOT_MOUNT}" 2>/dev/null || true
    
    # Delete the temp files or directories
    rm -rf "${TEMP_DIR}"
    
    info "*** ATTESTATION SERVICE COMPLETED ***"
}
trap cleanup EXIT

fetch_passphrase() {
    local attempts=$MAX_RETRY_ATTEMPTS
    local count=0
    local result=""
    local status=0

    while [ $count -lt $attempts ] && [ -z "$result" ]; do
        info "Attempt $((count+1)): Fetching passphrase from ${KBS_URL}"
	
        if ! result=$(/usr/bin/trustee-attester --url "${KBS_URL}" get-resource --path default/rootdecrypt/key1 2>/dev/null); then
	    status=$?
	    info "Attestation failed with status $status"
            sleep $RETRY_DELAY
	elif [ -n "$result" ]; then
            info "Successfully retrieved passphrase"
            break
        else
            info "Empty response received"
            sleep $RETRY_DELAY
        fi
        
        count=$((count+1))
    done
    
    if [ -z "$result" ]; then
        info "Failed to retrieve passphrase after $attempts attempts"
        return 1
    fi
    
    echo "$result"
    return 0
}

replace_luks_key() {
    local device=$1
    local new_key=$2

    info "Getting current LUKS key"
    . clevis-luks-common-functions
    local pt=$(clevis_luks_unlock_device "${device}")
    echo -n "${pt}" > "${OLD_PASS_FILE}"
    chmod 600 "${OLD_PASS_FILE}"
    pt="xxxxxxxxxx"  # Erase the passphrase from memory

    if ! /usr/sbin/cryptsetup --verbose open --test-passphrase "${device}" --key-file="${OLD_PASS_FILE}"; then
        info "Failed to verify old key" 
        return 1
    fi

    info "Replacing LUKS key"
    /usr/sbin/cryptsetup luksAddKey "${device}" --key-file="${OLD_PASS_FILE}" "${new_key}" || return 1
    /usr/sbin/cryptsetup luksKillSlot "${device}" 1 --key-file="${new_key}" || return 1

    info "Do verification of new LUKS key"
    if ! /usr/sbin/cryptsetup --verbose open --test-passphrase "${device}" --key-file="${new_key}"; then
        info "Failed to verify new key"
        return 1
    fi

    info "Removing LUKS token"
    /usr/sbin/cryptsetup token remove "${device}" --token-id 0

    info "Create marker file"
    touch "${MARKER_FILE}"
    info "LUKS key replacement completed successfully"
}

# Main execution
info "*** ATTESTATION SERVICE FOR DISK ENCRYPTION ***"

# Check if root is already decrypted
if [ -e "/dev/mapper/${CRYPT_ROOT_NAME}" ]; then
    info "Root device already decrypted"
    exit 0
fi

# Fetch passphrase
passphrase_base64=$(fetch_passphrase)
[ -z "$passphrase_base64" ] && { info "No passphrase received"; exit 1; }

passphrase=$(echo "$passphrase_base64" | base64 -d | tr -cd '[:print:]')
echo -n "$passphrase" > "${PASSPHRASE_FILE}"
chmod 600 "${PASSPHRASE_FILE}"

# Mount boot partition
mkdir -p "${BOOT_MOUNT}"
if ! mount -o rw "${BOOT_DEVICE}" "${BOOT_MOUNT}" 2>/dev/null; then
    info "Warning: Could not mount boot partition - assuming first boot"
    BOOT_MOUNTED=false
else
    BOOT_MOUNTED=true
fi

if $BOOT_MOUNTED && [ -f "${MARKER_FILE}" ]; then
    info "Normal boot: Decrypting root filesystem"
    info "ATTESTATION SERVICE: Decrypting root filesystem with fetched key"
    if /usr/sbin/cryptsetup --verbose open ${ROOT_DEVICE} ${CRYPT_ROOT_NAME} --key-file=${PASSPHRASE_FILE}; then
        info "ATTESTATION SERVICE: Successfully decrypted root filesystem"
    else
        info "ATTESTATION SERVICE: Failed to decrypt root filesystem"
    	exit 1
    fi
else
    info "First boot: Replacing LUKS key"
    replace_luks_key "${ROOT_DEVICE}" "${PASSPHRASE_FILE}" || exit 1

    # Prevent the system from calling systemd-cryptsetup@root.service 
    # to decrypt LUKS devices during other-boots.
    if [ -f "${CRYPTTAB_FILE}" ]; then
        info "Clearing crypttab file"
        echo > "${CRYPTTAB_FILE}" || info "Warning: Could not clear crypttab file"
    else
        info "Warning: Crypttab file not found at ${CRYPTTAB_FILE}"
    fi
fi
