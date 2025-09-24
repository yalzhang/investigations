#!/bin/bash

set -euxo pipefail

SECRET_PATH="${SECRET_PATH:=default/machine/root}"

# Setup attestation policy
podman cp /opt/policy.rego kbs-client:/policy.rego
kbs-client set-attestation-policy --policy-file policy.rego --type rego --id default_cpu

# Set ressource access policy
kbs-client set-resource-policy --affirming

# Upload resource: LUKS root key
cat > secret << EOF
{ "key_type": "oct", "key": "2b442dd5db4478367729ef8bbf2e7480" }
EOF
podman cp secret kbs-client:/secret
kbs-client set-resource --resource-file /secret --path "${SECRET_PATH}"

# Setup reference values
kbs-client set-sample-reference-value tpm_svn "1"

# Use PCR values from the current host as reference values
# Skip PCR 14 for now
for i in {4,7}; do
    value=$(sudo tpm2_pcrread sha256:${i} | awk -F: '/0x/ {sub(/.*0x/, "", $2); gsub(/[^0-9A-Fa-f]/, "", $2); print tolower($2)}')
    kbs-client set-sample-reference-value "tpm_pcr${i}" "${value}"
done

# Check reference values
kbs-client get-reference-values
