# Generating Node Decryption Secrets for RHCOS

**Authors:** demeng@redhat.com \
**Jira Issue:** [COCL-34](https://issues.redhat.com/browse/COCL-34)

### Step 1: Prerequisites
Ensure you have:
- `oc` CLI configured and logged into OpenShift cluster
- `openssl` installed (or TPM/HSM tools if using hardware)
- Valid `KUBECONFIG` configuration
- Trustee-Operator deployed with KBSConfig CR

### Step 2: Configure Environment Variables
```bash
export NODE_NAME="worker-123" 
export CLEAN_NODE_NAME=$(echo "$NODE_NAME" | tr -cd '[:alnum:]')
export TRUSTEE_NAMESPACE="trustee-operator-system"
export PRIVATE_KEY_FILE="./private_key_${CLEAN_NODE_NAME}.pem"
export PUBLIC_KEY_FILE="./public_key_${CLEAN_NODE_NAME}.pem"
export SECRET_NAME="trustee-secrets-${CLEAN_NODE_NAME}"
export HC_SECRET_NAME="trustee-hc-secrets-${CLEAN_NODE_NAME}"
```

### Step 3: Generate Ed25519 Key Pair
```bash
# Use software key (default)
openssl genpkey -algorithm ed25519 -out "$PRIVATE_KEY_FILE"
openssl pkey -in "$PRIVATE_KEY_FILE" -pubout -out "$PUBLIC_KEY_FILE"
```

### Step 4: Create Key Pair Secret
```bash
oc get secret "$SECRET_NAME" -n "$TRUSTEE_NAMESPACE" &> /dev/null || \
oc create secret generic "$SECRET_NAME" \
  --from-file=privateKey="$PRIVATE_KEY_FILE" \
  --from-file=publicKey="$PUBLIC_KEY_FILE" \
  -n "$TRUSTEE_NAMESPACE"
```

### Step 5: Create HC Secret with Random Value
```bash
# Generate secure random keys using base64 or openssl
export HC_SECRET_VALUE=$(openssl rand -hex 16)

oc get secret "$HC_SECRET_NAME" -n "$TRUSTEE_NAMESPACE" &> /dev/null || \
oc create secret generic "$HC_SECRET_NAME" \
  --from-literal=key1="${HC_SECRET_VALUE}" \
  -n "$TRUSTEE_NAMESPACE"
```

### Step 6: Get KBSConfig Resource Name
```bash
export CR_NAME=$(oc get kbsconfig -n "$TRUSTEE_NAMESPACE" -o=jsonpath='{.items[0].metadata.name}')
```

### Step 7: Register HC Secret to KBSConfig
```bash
# Check if the value already exists to prevent duplicate addition (idempotence processing)
PATCH_ALREADY=$(oc get kbsconfig "$CR_NAME" -n "$TRUSTEE_NAMESPACE" -o=jsonpath="{.spec.kbsSecretResources[*]}" | grep -w "$HC_SECRET_NAME" || true)

if [[ -z "$PATCH_ALREADY" ]]; then
  oc patch kbsconfig "$CR_NAME" -n "$TRUSTEE_NAMESPACE" --type=json \
    -p="[{'op': 'add', 'path': '/spec/kbsSecretResources/-', 'value': '${HC_SECRET_NAME}'}]"
else
  echo "KBSConfig already contains $HC_SECRET_NAME, skipping patch."
fi
```

### Step 8: (Optional) Clean Up Key Files
```bash
rm -f "$PRIVATE_KEY_FILE" "$PUBLIC_KEY_FILE"
```