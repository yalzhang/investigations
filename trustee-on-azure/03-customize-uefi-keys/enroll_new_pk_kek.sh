#!/bin/bash

# --- Configuration ---
# The base NVRAM file to modify.
# Use "vars.qcow2" if you are chaining this after the dbx modification.
INPUT_VARS_QCOW2="/root/virt-firmware/vars.qcow2"

# The final output file name.
FINAL_OUTPUT_QCOW2="vars-final.qcow2"

# --- Certificate Files ---
# The single, primary certificate to enroll.
# This will become the new PK and the FIRST KEK, clearing all old ones.
ENROLL_CERT_FILE="/root/certs/PK/PK.pem"

# (Optional) A list of ADDITIONAL Key Exchange Key (KEK) certificates to ADD.
# These will be added AFTER the enrollment certificate.
# Leave this empty if you only want the enrollment cert in the KEK list.
# Example: ADDITIONAL_KEK_CERT_FILES=("/path/to/microsoft_kek.pem")
ADDITIONAL_KEK_CERT_FILES=(
  "/root/certs/KEK/KEK-0.pem"
  "/root/certs/KEK/KEK-1.pem"
  "/root/certs/KEK/KEK-2.pem"
)

# The GUID for the owner of these keys.
OWNER_GUID="77fa9abd-0359-4d32-bd60-28f4e78f784b"

# --- Temporary File Names ---
RAW_INPUT="original.raw"
RAW_MODIFIED="modified.raw"

# --- Script ---

set -e # Exit immediately if a command fails.

# --- Verification ---
if [ ! -f "${ENROLL_CERT_FILE}" ]; then
    echo "Error: Enrollment certificate file not found at ${ENROLL_CERT_FILE}"
    exit 1
fi
for cert in "${ADDITIONAL_KEK_CERT_FILES[@]}"; do
    if [ ! -f "${cert}" ]; then
        echo "Error: Additional KEK certificate file not found at ${cert}"
        exit 1
    fi
done

# Step 1: Convert the source qcow2 to a raw file.
echo "--- Step 1: Converting source qcow2 to raw format ---"
qemu-img convert -f qcow2 -O raw "${INPUT_VARS_QCOW2}" "${RAW_INPUT}"
echo "Successfully created ${RAW_INPUT}"
echo ""

# Step 2: Build and execute the command to enroll the new keys.
echo "--- Step 2: Clearing old PK/KEK and enrolling new certificate ---"
CMD=(virt-fw-vars -i "${RAW_INPUT}" -o "${RAW_MODIFIED}")

# Use --delete and --set-pk to clear old keys, then --add-kek to add new ones.
# This is required for older versions of virt-fw-vars that lack --enroll-guid.
CMD+=(--delete "KEK")
CMD+=(--set-pk "${OWNER_GUID}" "${ENROLL_CERT_FILE}")
CMD+=(--add-kek "${OWNER_GUID}" "${ENROLL_CERT_FILE}")

# (Optional) Add any other KEK certificates to the new, clean list.
for cert in "${ADDITIONAL_KEK_CERT_FILES[@]}"; do
    echo "Staging additional KEK for addition: ${cert}"
    CMD+=(--add-kek "${OWNER_GUID}" "${cert}")
done

# Execute the full command
echo "Executing virt-fw-vars..."
"${CMD[@]}"
echo "Successfully created ${RAW_MODIFIED}"
echo ""

# Step 3: Convert the final raw file back to qcow2 format.
echo "--- Step 3: Converting final raw file back to qcow2 ---"
qemu-img convert -f raw -O qcow2 "${RAW_MODIFIED}" "${FINAL_OUTPUT_QCOW2}"
echo "Successfully created final output: ${FINAL_OUTPUT_QCOW2}"
echo ""

# Step 4: Clean up the raw files.
echo "--- Step 4: Cleaning up temporary files ---"
rm "${RAW_INPUT}" "${RAW_MODIFIED}"
echo "Cleanup complete."
echo ""

echo "--------------------------------------------------------------------"
echo "Success! PK and KEK have been replaced in ${FINAL_OUTPUT_QCOW2}"
echo "The new KEK list contains ONLY the enrollment certificate"
echo "plus any additional ones you specified."
echo "--------------------------------------------------------------------"
