
import sys
import uuid
from uefi_firmware.uefi import FirmwareVariableStore, FirmwareVariable

# The standard GUID for the UEFI Global Variable namespace, used for Secure Boot keys.
EFI_GLOBAL_VARIABLE_GUID = uuid.UUID("8be4df61-93ca-11d2-aa0d-00e098032b8c")

def update_dbx_in_nvram(nvram_path, esl_path):
    """
    Reads a UEFI NVRAM file, replaces the 'dbx' variable with data from an
    ESL file, and writes the changes back. This version is adapted to find the
    correct parsing method for the installed library.
    """
    try:
        with open(nvram_path, 'rb') as f:
            nvram_data = f.read()
        
        with open(esl_path, 'rb') as f:
            new_dbx_data = f.read()

    except IOError as e:
        print(f"Error reading files: {e}")
        return False

    print(f"Successfully read NVRAM file ({len(nvram_data)} bytes) and ESL file ({len(new_dbx_data)} bytes).")

    # Create an empty FirmwareVariableStore object.
    store = FirmwareVariableStore()
    
    # Dynamically find the correct parsing method.
    # Different versions of the library use different method names.
    parser_method = None
    for method_name in ['process', 'parse', 'from_buffer', 'load']:
        if hasattr(store, method_name) and callable(getattr(store, method_name)):
            print(f"Found parsing method: '{method_name}'")
            parser_method = getattr(store, method_name)
            break
    
    if not parser_method:
        # Fallback for older libraries where __init__ might be used after all
        try:
            print("No parsing method found, attempting to re-initialize with data...")
            store = FirmwareVariableStore(nvram_data)
        except TypeError:
             print("Error: Could not find a suitable method to parse the NVRAM data.")
             print("The installed 'uefi-firmware' library version is incompatible.")
             return False
    else:
        # Call the found parsing method
        parser_method(nvram_data)

    # Default attributes for dbx are typically: Non Volatile, Boot Service Access, Runtime Access
    dbx_attributes = 0x07 
    
    # Find and remove the existing 'dbx' variable.
    existing_dbx_index = -1
    for i, var in enumerate(store.variables):
        if var.name == 'dbx' and str(var.guid).lower() == str(EFI_GLOBAL_VARIABLE_GUID).lower():
            print(f"Found existing 'dbx' variable with attributes: {hex(var.attributes)}")
            dbx_attributes = var.attributes
            existing_dbx_index = i
            break
    
    if existing_dbx_index != -1:
        print("Removing existing 'dbx' variable.")
        store.variables.pop(existing_dbx_index)
    else:
        print("Warning: No existing 'dbx' variable found. A new one will be added.")

    # Create a new FirmwareVariable object
    new_dbx_variable = FirmwareVariable(
        name='dbx',
        guid=EFI_GLOBAL_VARIABLE_GUID,
        data=new_dbx_data,
        attributes=dbx_attributes
    )

    # Add the new variable to the store's list
    store.variables.append(new_dbx_variable)
    print("Added new 'dbx' variable to the data structure.")

    # Generate the new binary NVRAM data using the 'build' method
    new_nvram_data = store.build()

    try:
        with open(nvram_path, 'wb') as f:
            f.write(new_nvram_data)
        print(f"Successfully wrote {len(new_nvram_data)} bytes back to {nvram_path}")
    except IOError as e:
        print(f"Error writing updated NVRAM file: {e}")
        return False
        
    return True

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: python3 {sys.argv[0]} <path_to_nvram_file> <path_to_esl_file>")
        sys.exit(1)
    
    nvram_file = sys.argv[1]
    esl_file = sys.argv[2]
    
    print("--- Starting NVRAM DBX Update ---")
    if update_dbx_in_nvram(nvram_file, esl_file):
        print("--- Update successful! ---")
    else:
        print("--- Update failed! Please restore from your backup. ---")
        sys.exit(1)
