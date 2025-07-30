# Measuring the Image for Attestation

**Authors:** demeng@redhat.com, fjin@redhat.com\
**Jira Issue:** [COCL-34](https://issues.redhat.com/browse/COCL-34) \

### Step 1: Prerequisites
- RHEL 9.6 base custom image for Azure (supports SEV-SNP)
- Prepare a rhel960 VM for installing trustee-guest-components packages from brewweb, and after the installation is complete, extract the binary file ‘/usr/bin/trustee-attester’. This binary file will be copied to the path that was used to build the custom azure-image.
- Compiled kbs-client:
  ```bash
  [user@host ~]$ git clone https://github.com/confidential-containers/trustee.git
  [user@host ~]$ cd trustee/kbs && make cli ATTESTER=az-snp-vtpm-attester && make install-cli
  ```

### Step 2: Get PCR Values via kbs-client
```bash
will update here soon.

```

### Step 3: Check kernel command line on worker node (first-boot)
```bash
[user@host ~]$ cat /proc/cmdline

BOOT_IMAGE=(hd0,gpt3)/boot/ostree/rhcos-d3b213b9994c90f713851e8177355518097e0660ae51e274067d754e5a43de36/vmlinuz-5.14.0-570.16.1.el9_6.x86_64 rw ostree=/ostree/boot.1/rhcos/d3b213b9994c90f713851e8177355518097e0660ae51e274067d754e5a43de36/0 ignition.platform.id=azure console=tty0 console=ttyS0,115200n8 rd.luks.name=9a3a6f9a-ef4d-424e-97a1-8dc1bab480db=root root=UUID=d7ac62d8-e501-4ec9-a3db-4244dbb54e95 rw rootflags=prjquota boot=UUID=5341b204-fee4-4ac5-a6ed-cd988da26edc
```

### Step 4: Check and save `rvps-reference-values.yaml/attestation-policy.yaml` and backup them
```bash
[user@host ~]$ oc get cm,secret -n ${TRUSTEE_OPERATOR_NAMESPACE} | grep -E "rvps|attestation"
```

### Step 5: Set certain PCR value in `rvps-reference-value`, update attestation policy to validate the PCR, do attestation
```yaml
[user@host ~]$ cat rvps-reference-values.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rvps-reference-values
  namespace: trustee-operator-system
data:
  reference-values.json: |
    [
      {
        "name": "svn",
        "expiration": "2026-01-01T00:00:00Z",
        "hash-value": [
          {
            "alg": "sha256",
            "value": "1"
          }
        ]
      },
      {
        "name": "pcr04",
        "expiration": "2026-01-01T00:00:00Z",
        "hash-value": [
          {
            "alg": "sha256",
            "value": "b727139f0825cbd272b410561c1e87017ed11b2daaae24c06efd81630dce5276"
          }
        ]
      }
    ]

[user@host ~]$ oc apply -f rvps-reference-values.yaml

[user@host ~]$ cat attestation-policy.yaml
...skipped..
    ##### AZ SNP TODO
    hardware := 2 if {
      input.azsnpvtpm.tpm.pcr04 in data.reference.pcr04
    }

[user@host ~]$ oc apply -f attestation-policy.yaml
```

### Step 6: Check trustee-log
```bash
[user@host ~]$ oc get pods
[user@host ~]$ oc logs pod/trustee-deployment-64595c7845-zsbc9 -n trustee-operator-system -f
```

### Step 7: Set a wrong PCR value in `rvps-reference-value`, do attestation. It failed.

### Step 8: Configure more PCRs in `rvps`, update attestation policy accordingly, attestation succeeded; Change one of PCRs to wrong value, and the attestation failed.