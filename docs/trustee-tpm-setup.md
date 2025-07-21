# Introduction

Instructions to use TPM attester for remote attestation with Trustee. This is primarily meant to
experiment with Trustee attestation and resource policies based on TPM PCRs
which can then be adapted for a confidential environment (eg. Azure CVM with vTPM).

For creating fcos VM, please refer to the following [guide](../README.md).

## Trustee server setup

### Setup services

Ensure you have `docker`, `docker-compose`, `rust`, `make` installed.

Clone the repo.

```sh
git clone https://github.com/bpradipt/trustee.git
cd trustee
git checkout -b tpm-verifier origin/tpm-verifier
```

Setup authentication keys.
We'll need these keys when using `kbs-client` to interact with Trustee services.

```sh
openssl genpkey -algorithm ed25519 > kbs/config/private.key
openssl pkey -in kbs/config/private.key -pubout -out kbs/config/public.pub
```

Run Trustee services.

This will start KBS, AS and RVPS services

```sh
docker-compose up -d
```

### Build and install kbs-client

```sh
cd kbs
make cli
sudo make install-cli
```

The `kbs-client` binary will be available at `/usr/local/bin/kbs-client`

### Set KBS server address

Get the IP address of the Trustee host.

```sh
device=$(ip r | awk '/^default/{print $5}')
ip_address=$(test -n "$device" && ip addr show "$device" | awk '/inet /{print $2}' | cut -d/ -f1)
export KBS_SERVER="$ip_address"
echo "$KBS_SERVER"
```

### Upload resource to Trustee

Note: All paths are relative to the top level code directory (`trustee`).

Generate a dummy resource data file.

```sh
cat > kbs/test/dummy_data << EOF
1234567890abcde
EOF
```

Upload the resource to Trustee

```sh
kbs-client --url http://"$KBS_SERVER":8080 \
           config --auth-private-key kbs/config/private.key \
           set-resource --resource-file kbs/test/dummy_data \
           --path default/test/dummy
```

### Set Attestation Policy

This is an example attestation policy using `tpm_svn` and `tpm_pcr11` as part of TPM TCB.
Adapt is as needed based on the claims you want to validate.

Create the attestation policy file.

```sh
cat << 'EOF' > tpm_policy_cpu.rego
package policy

import rego.v1

default hardware := 97
default configuration := 36

##### Sample


executables := 3 if {
	input.sample.launch_digest in data.reference.launch_digest
}

hardware := 2 if {
	input.sample.svn in data.reference.svn
	input.sample.platform_version.major == data.reference.major_version
	input.sample.platform_version.minor >= data.reference.minimum_minor_version
}

##### TPM
hardware := 2 if {
	input.tpm.svn in data.reference.tpm_svn
}

executables := 3 if {
	input.tpm.pcrs[11] in data.reference.tpm_pcr11
}

configuration := 2 if {
	input.tpm.pcrs[11] in data.reference.tpm_pcr11
}
EOF

```

Set the attestation policy in Trustee.

```sh
kbs-client --url http://"$KBS_SERVER":8080 \
           config --auth-private-key kbs/config/private.key \
           set-attestation-policy \
           --policy-file tpm_policy_cpu.rego
```

### Set Resource Policy

Set an affirming resource policy.

```sh
kbs-client --url http://"$KBS_SERVER":8080 \
           config --auth-private-key kbs/config/private.key \
           set-resource-policy --affirming
```

### Register reference values for use with attestation

Following example sets reference for `tpm_pcr11` and `tpm_svn`, which is used
in the attestation policy

```sh
export PCR11=<set-digest-value>
kbs-client --url http://"$KBS_SERVER":8080 \
           config --auth-private-key kbs/config/private.key \
           set-sample-reference-value tpm_pcr11 "$PCR11"

kbs-client --url http://"$KBS_SERVER":8080 \
           config --auth-private-key kbs/config/private.key \
           set-sample-reference-value tpm_svn "1"
```

Verify the reference values

```sh
kbs-client --url http://"$KBS_SERVER":8080 \
           config --auth-private-key kbs/config/private.key \
           get-reference-values
```

### Verify

Run the following to retrieve the resource.

```sh
sudo kbs-client --url http://"$KBS_SERVER":8080 \
     get-resource --path default/test/dummy
```

If everything is setup correctly you should see the base64 encoded dummy data returned.

```sh
MTIzNDU2Nzg5MGFiY2RlCg==
```

## Trustee client setup

You'll need to copy the `kbs-client` to the client system having TPM.

Following command copies the kbs-client from Trustee host to a CoreOS VM.

```sh
export SSH_KEY_PATH=<set>
export COREOS_VM_IP=<set>

scp -P 2222 -i "$SSH_KEY_PATH"  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/bin/kbs-client core@"$COREOS_VM_IP":~/kbs-client
```

### Retrieve the resource

Run the following command on the Trustee client. Remember to set the `KBS_SERVER`
environment variable.

```sh
sudo kbs-client --url http://"$KBS_SERVER":8080 \
     get-resource --path default/test/dummy
```
