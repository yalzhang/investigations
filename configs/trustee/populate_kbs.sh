#!/bin/bash

set -xe

KBS=kbs:8080
SECRET_PATH=${SECRET_PATH:=default/machine/root}
KEY=${KEY:=/opt/confidential-containers/kbs/user-keys/private.key}

podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-sample-reference-value tpm_svn "1"
for i in {4,7,14}; do
    value=$(sudo tpm2_pcrread sha256:${i} | awk -F: '/0x/ {sub(/.*0x/, "", $2); gsub(/[^0-9A-Fa-f]/, "", $2); print tolower($2)}')
	podman exec -ti kbs-client \
		 kbs-client --url http://${KBS}  config \
			--auth-private-key ${KEY} \
			set-sample-reference-value tpm_pcr${i} "${value}"
done

# Check reference values
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		get-reference-values


# Create attestation policy
cat << 'EOF' > tpm.rego
package policy
import rego.v1
default hardware := 97
default configuration := 36

##### TPM
hardware := 2 if {
	input.tpm.svn in data.reference.tpm_svn
}

tpm_pcrs_valid if {
  input.tpm.pcrs[4] in data.reference.tpm_pcr4
  input.tpm.pcrs[7] in data.reference.tpm_pcr7
  input.tpm.pcrs[14] in data.reference.tpm_pcr14
}

executables := 3 if tpm_pcrs_valid
configuration := 2 if tpm_pcrs_valid

##### Final decision
allow if {
  hardware == 2
  executables == 3
  configuration == 2
}
EOF

podman cp tpm.rego kbs-client:/tpm.rego
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-attestation-policy \
		--policy-file tpm.rego \
		--type rego --id default_cpu

# Upload resource
cat > test_data << EOF
{ "key_type": "oct", "key": "2b442dd5db4478367729ef8bbf2e7480" }
EOF
podman cp test_data kbs-client:/secret
podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-resource --resource-file /secret \
		--path ${SECRET_PATH}

podman exec -ti kbs-client \
	kbs-client --url http://${KBS}  config \
		--auth-private-key ${KEY} \
		set-resource-policy --affirming
