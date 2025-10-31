
import struct
import uuid
import glob
import os

# This is the standard UEFI "Image Security Database" GUID for the 'dbx' variable.
DBX_GUID = "d719b2cb-3d3a-4596-a3bc-dad00e67656f"

# Each signature needs an "owner" GUID. We can generate a new one or use a known one.
# For simplicity, we'll use a known Microsoft GUID, but it can be any valid GUID.
OWNER_GUID = "77fa9abd-0359-4d32-bd60-28f4e78f784b"

# Each signature entry consists of the owner GUID (16 bytes) + the SHA256 hash (32 bytes)
SIGNATURE_SIZE = 16 + 32

def create_esl_from_hashes(hash_dir, output_file):
    """
    Creates an EFI Signature List (ESL) file from a directory of .hash files.
    """
    hashes = []
    # Use a sorted list to ensure a consistent order
    hash_files = sorted(glob.glob(os.path.join(hash_dir, '*.hash')))
    
    if not hash_files:
        print(f"Error: No .hash files found in {hash_dir}")
        return

    print(f"Found {len(hash_files)} hash files to process.")

    for filename in hash_files:
        with open(filename, 'rb') as f:
            content = f.read()
            if len(content) == 32: # Ensure it's a SHA256 hash
                hashes.append(content)
            else:
                print(f"Warning: Skipping {filename}, as it is not 32 bytes long.")

    # The EFI_SIGNATURE_LIST header is 28 bytes
    # (GUID + ListSize + HeaderSize + SignatureSize)
    esl_header_size = 28
    total_size = esl_header_size + (len(hashes) * SIGNATURE_SIZE)

    print(f"Writing {len(hashes)} signatures to {output_file}...")

    with open(output_file, "wb") as f:
        # Write the EFI_SIGNATURE_LIST header
        # '<' means little-endian
        f.write(uuid.UUID(DBX_GUID).bytes_le)
        f.write(struct.pack("<III", total_size, 0, SIGNATURE_SIZE))

        # Write each EFI_SIGNATURE_DATA entry
        owner_guid_bytes = uuid.UUID(OWNER_GUID).bytes_le
        for h in hashes:
            f.write(owner_guid_bytes)
            f.write(h)

    print(f"Successfully created {output_file} with a total size of {total_size} bytes.")

if __name__ == "__main__":
    create_esl_from_hashes("certs/DBX", "dbx_256.esl")
