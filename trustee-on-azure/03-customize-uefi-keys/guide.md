Steps:
1. Get the keys and certs from the qemu vm
2. Prepare the ARM template
3. Deploy the template
4. Create a vm with new image version, check if the keys and values are expected

Get the keys:
Boot the test vm with fcos 42 in the investigation project
```shell
$ sudo rpm-ostree install efitools
$ sudo systemctl reboot

$ sudo -i
/// Export a single variable (export PK as ESL format)
# efi-readvar -v PK -o PK.esl
# efi-readvar -v KEK -o KEK.esl
# efi-readvar -v db  -o db.esl
# efi-readvar -v dbx -o dbx.esl

////Extract each x509 certificate (DER format) from ESL.
# mkdir -p certs/PK certs/KEK certs/DB certs/DBX

# sig-list-to-certs PK.esl  certs/PK/PK
# sig-list-to-certs KEK.esl certs/KEK/KEK
# sig-list-to-certs db.esl  certs/DB/DB
# sig-list-to-certs dbx.esl certs/DBX/DBX

# ls -R /root/certs
/root/certs:
DB  DBX  KEK  PK

/root/certs/DB:
DB-0.der  DB-1.der  DB-2.der  DB-3.der

/root/certs/DBX:
DBX-0.hash    DBX-130.hash  DBX-163.hash  DBX-196.hash	DBX-228.hash  DBX-260.hash  DBX-293.hash  DBX-325.hash	DBX-358.hash  DBX-390.hash  DBX-422.hash  DBX-69.hash
.....
DBX-292.hash  DBX-324.hash  DBX-357.hash	DBX-39.hash   DBX-421.hash  DBX-68.hash

/root/certs/KEK:
KEK-0.der  KEK-1.der  KEK-2.der

/root/certs/PK:
PK-0.der

/// Convert the DER certificate to Base64 (without PEM header/footer) for use in the certificate field of Azure JSON.

# base64 -w0 /root/certs/DB/DB-0.der > certs/DB/db-0.der.b64
# base64 -w0 /root/certs/DB/DB-1.der > certs/DB/db-1.der.b64
# base64 -w0 /root/certs/DB/DB-2.der > certs/DB/db-2.der.b64
# base64 -w0 /root/certs/DB/DB-3.der > certs/DB/db-3.der.b64

# base64 -w0 /root/certs/PK/PK-0.der  > certs/PK/PK-0.der.b64

# base64 -w0 /root/certs/KEK/KEK-0.der  > certs/KEK/KEK-0.der.b64
# base64 -w0 /root/certs/KEK/KEK-1.der  > certs/KEK/KEK-1.der.b64
# base64 -w0 /root/certs/KEK/KEK-2.der  > certs/KEK/KEK-2.der.b64

```


use the generate_securityProfile.sh to generate the securityprofile block:
```
(make sure in the correct directory)
$ sh generate_securityProfile.sh > securityProfile.json
# Get the ARM_template_image_version.json from https://learn.microsoft.com/en-us/azure/virtual-machines/trusted-launch-secure-boot-custom-uefi#arm-template
$ jq '.properties.securityProfile = input.securityProfile' ARM_template_image_version.json  securityProfile.json > merged.json
```

Create the full ARM template:
```
jq '{ 
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "variables": {},
  "resources": [ . ],
  "outputs": {}
}' merged.json > arm_template_final.json

```
Some updates on the arm_template_final.json
1. Delete the 'dependsOn', 'replicationMode' element, since we have image dinition already
```
jq 'del(
      .resources[]?.dependsOn,
      .resources[]?.properties?.publishingProfile?.replicationMode
    )' arm_template_final.json > new-template.json

mv new-template.json arm_template_final.json
```
2. Use latest apiVersion "2025-03-03" 
   ```
   jq '.apiVersion = "2025-03-03"' arm_template_final.json > tmp.json && mv tmp.json arm_template_final.json

   ```
3. Add the parameters part
   ```
    jq '.parameters = {
    "galleryName": {"type":"string"},
    "imageDefinitionName": {"type":"string"},
    "versionName": {"type":"string"},
    "location": {"type":"string"},
    "defaultReplicaCount": {"type":"int"},
    "regionReplications": {"type":"array"},
    "excludedFromLatest": {"type":"bool"},
    "sourceVhdStorageAccountId": {"type":"string"},
    "sourceVhdUri": {"type":"string"},
    "allowDeletionOfReplicatedLocations": {"type":"bool"}
    }' arm_template_final.json > arm_template_final_temp.json && mv arm_template_final_temp.json arm_template_final.json
    ```

4. . update the resources.storage.profile
```
jq '.properties.storageProfile = {
      "osDiskImage": {
        "source": {
          "storageAccountId": "[parameters(\"sourceVhdStorageAccountId\")]",
          "uri": "[parameters(\"sourceVhdUri\")]"
        }
      }
    }' arm_template_final.json > tmp.json && mv tmp.json arm_template_final.json
```

5. Prepare for the parameters.json

Run the cmd to create the image version:
```
$ az deployment group create   \
    --resource-group yalan-rg-20250930 \
    --template-file arm_template_final.json \
    --parameters parameters.json 
{"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/1b34f80b-b456-49c3-8aa1-5dddeb9b4ab5/resourceGroups/yalan-rg-20250930/providers/Microsoft.Resources/deployments/arm_template_final","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"InvalidParameter","target":"galleryImageVersion.properties.securityProfile.uefiSettings.additionalSignatures","message":"Exceeded the maximum number of UEFI Key elements of type 'sha256'.  The maximum allowed is '256' and '430' was provided.  Please reduce the number of UEFI keys provided."}]}}
```

With 256 dbx files, redo it and pass

Create a vm using this image version, and login to check the value

```
az vm create   \
    --resource-group dev-normal-shared-jtmln-rg   \
    --name yalan_uefikey   \
    --image /subscriptions/1b34f80b-b456-49c3-8aa1-5dddeb9b4ab5/resourceGroups/yalan-rg-20250930/providers/Microsoft.Compute/galleries/yalan_Gallery/images/yalan-fcos-clevis-v2/versions/5.0.1  \
    --size Standard_DC2ads_v5   \
    --security-type ConfidentialVM   \
    --os-disk-security-encryption-type VMGuestStateOnly   \
    --enable-vtpm true    \
    --boot-diagnostics-storage  https://yalanstroageaccount.blob.core.windows.net/  \
    --custom-data /home/yalzhang/butane/verify.ign
```
check on the azure vm:
```
core@yalanuefikey501:~$ sudo mokutil --dbx | wc -l
256
core@yalanuefikey501:~$ sudo tpm2_pcrread sha256:7
  sha256:
    7 : 0x87EA19BC8E9BF02035035D0E261CA8ADDBBC7061E0DEB789B642D7A8B53082AB
```
the pcr values changes: 
- original azure vm: 0xAB106842509649106881AC864D8EA4086B3F3BFC3FCC69F25E18083FFCAA6888
- qemu vm:           0xB3A56A06C03A65277D0A787FCABC1E293EAA5D6DD79398F2DDA741F7B874C65D
- new azure vm with updated uefi keys:      0x87EA19BC8E9BF02035035D0E261CA8ADDBBC7061E0DEB789B642D7A8B53082AB
- qemu vm with 256 entries dbx:             0x99B02D372E39885D81DD3FC03FE3A4C1CF1049B72394596988063532B265728E

The difference between the new azure vm pcr value and the qemu vm comes from 2 parts:
1. The Azure vm use 256 dbx entries, not the qemu vm's 430 entries;
2. For PK and KEK, they are with the same x509 cert, but different GUID, since we only replace the cert, and Azure the will the default GUID, which is different from the qemu vm.





