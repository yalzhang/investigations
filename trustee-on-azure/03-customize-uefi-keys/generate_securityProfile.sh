#!/bin/bash
# Generate Azure JSON for custom UEFI keys with progress log to terminal
# JSON to stdout, logs to stderr
# Supports DBX only .hash files, automatic Base64 encoding

# File arrays
PK_FILES=(certs/PK/*.der.b64)
KEK_FILES=(certs/KEK/*.der.b64)
DB_FILES=(certs/DB/*.der.b64)
DBX_CERTS=(certs/DBX/*.der.b64)
DBX_HASHES=($(ls -v certs/DBX/*.hash))

# Handle no-match
[ "${PK_FILES[0]}" = "certs/PK/*.der.b64" ] && PK_FILES=()
[ "${KEK_FILES[0]}" = "certs/KEK/*.der.b64" ] && KEK_FILES=()
[ "${DB_FILES[0]}" = "certs/DB/*.der.b64" ] && DB_FILES=()
[ "${DBX_CERTS[0]}" = "certs/DBX/*.der.b64" ] && DBX_CERTS=()
[ "${DBX_HASHES[0]}" = "certs/DBX/*.hash" ] && DBX_HASHES=()

# Helper to output a JSON object for a given type and list of files
json_array_for_type() {
    local type=$1
    shift
    local files=($@)
    
    if [ ${#files[@]} -eq 0 ]; then
        return
    fi

    echo "          {"
    echo "            \"type\": \"$type\","
    echo "            \"value\": ["
    
    local last_index=$((${#files[@]}-1))
    for i in "${!files[@]}"; do
        local f="${files[$i]}"
        local comma=","
        if [ "$i" -eq "$last_index" ]; then
            comma=""
        fi

        if [ "$type" = "sha256" ]; then
            # DBX hash: base64 encode
            echo "              \"$(base64 -w 0 "$f")\"$comma"
        else
            # x509: already Base64
            echo "              \"$(cat "$f")\"$comma"
        fi
    done
    
    echo "            ]"
    echo "          }"
}

# Start JSON
echo '{'
echo '  "securityProfile": {'
echo '    "uefiSettings": {'
echo '      "signatureTemplateNames": ["NoSignatureTemplate"],
      "additionalSignatures": {'

# ---- PK ----
if [ ${#PK_FILES[@]} -gt 0 ]; then
    echo "Processing PK: ${PK_FILES[0]}" >&2
    echo '        "pk": {'
    echo '          "type": "x509",'
    echo '          "value": ['
    echo "            \"$(cat "${PK_FILES[0]}")\""
    echo '          ]'
    echo '        },'
fi

# ---- KEK ----
if [ ${#KEK_FILES[@]} -gt 0 ]; then
    echo "Processing KEK files..." >&2
    echo '        "kek": ['
    json_array_for_type "x509" "${KEK_FILES[@]}"
    echo '        ],'
fi

# ---- DB ----
if [ ${#DB_FILES[@]} -gt 0 ]; then
    echo "Processing DB files..." >&2
    echo '        "db": ['
    json_array_for_type "x509" "${DB_FILES[@]}"
    echo '        ],'
fi

# ---- DBX ----
if [ ${#DBX_CERTS[@]} -gt 0 ] || [ ${#DBX_HASHES[@]} -gt 0 ]; then
    echo "Processing DBX files..." >&2
    echo '        "dbx": ['
    
    if [ ${#DBX_CERTS[@]} -gt 0 ]; then
        json_array_for_type "x509" "${DBX_CERTS[@]}"
        if [ ${#DBX_HASHES[@]} -gt 0 ]; then
            echo ","
        fi
    fi

    if [ ${#DBX_HASHES[@]} -gt 0 ]; then
        json_array_for_type "sha256" "${DBX_HASHES[@]}"
    fi
    
    echo '        ]'
fi

echo '      }'
echo '    }'
echo '  }'
echo '}'

echo "JSON generation finished." >&2