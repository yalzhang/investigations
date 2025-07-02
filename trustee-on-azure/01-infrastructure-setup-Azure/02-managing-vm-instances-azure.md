# Managing VM Instances and Images on Azure

**Authors:** demeng@redhat.com \
**Jira Issues:** 
- [VIRTWINKVM-1122](https://issues.redhat.com/browse/VIRTWINKVM-1122)
- [COCL-40](https://issues.redhat.com/browse/COCL-40)

**References:**
- [VM image for Azure](https://github.com/confidential-containers/cloud-api-adaptor/blob/main/src/cloud-api-adaptor/azure/build-image.md)
- [Provisioning Fedora CoreOS on Azure](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-azure/)
- [Azure: Launch a confidential VM](https://github.com/coreos/fedora-coreos-docs/pull/671/files)
- [Install Azure CLI on Linux](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux)

## Step 1: Install the Azure CLI
```bash
# RHEL9 host could prefer the following instructions, other versions of host could refer to the above link.
mkdir Azure; cd Azure/
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
sudo dnf install azure-cli
```

## Step 2: Upload Image Version to Azure
(Note: There is also a section 'upload image to Azure' below, but we prefer to use image version to create VM, not image.)
```bash
az login # login az first follow the prompts

export AZURE_SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"
export AZURE_REGION="eastus"

# Create Resource Group

export AZURE_RESOURCE_GROUP="${RESOURCE_GROUP}" 
az group create --name "${AZURE_RESOURCE_GROUP}" --location "${AZURE_REGION}"

# Shared image gallery 

export GALLERY_NAME="demeng_imagegallery" 
az sig create --gallery-name "${GALLERY_NAME}" --resource-group "${AZURE_RESOURCE_GROUP}" --location "${AZURE_REGION}"

# Create the "Image Definition" by running the following command:

export GALLERY_IMAGE_DEF_NAME="rhcos-image" 
az sig image-definition create   --resource-group "${AZURE_RESOURCE_GROUP}"   --gallery-name "${GALLERY_NAME}"   --gallery-image-definition "${GALLERY_IMAGE_DEF_NAME}"   --publisher GreatPublisher   --offer GreatOffer   --sku GreatSku   --os-type "Linux"   --os-state "Generalized"   --hyper-v-generation "V2"   --location "${AZURE_REGION}"   --architecture "x64"   --features SecurityType=ConfidentialVmSupported 

# Create Storage Account

export AZURE_STORAGE_ACCOUNT="${STORAGE_ACCOUNT}" 
az storage account create -name $AZURE_STORAGE_ACCOUNT      -resource-group $AZURE_RESOURCE_GROUP     --location $AZURE_REGION     --sku Standard_ZRS     --encryption-services blob 

# Create storage container

export AZURE_STORAGE_CONTAINER=vhd
az storage container create     --account-name $AZURE_STORAGE_ACCOUNT     --name $AZURE_STORAGE_CONTAINER     --auth-mode login

# Get Storage Key

AZURE_STORAGE_KEY=$(az storage account keys list --resource-group $AZURE_RESOURCE_GROUP --account-name $AZURE_STORAGE_ACCOUNT --query "[?keyName=='key1'].{Value:value}" --output tsv)
echo $AZURE_STORAGE_KEY

# Upload VHD file to Azure Storage

az storage blob upload  --container-name $AZURE_STORAGE_CONTAINER --name podvm.vhd --file ./qcow2/demeng_podvm_test.vhd

# Get VHD URI

AZURE_STORAGE_EP=$(az storage account list -g $AZURE_RESOURCE_GROUP --query "[].{uri:primaryEndpoints.blob} | [? contains(uri, '$AZURE_STORAGE_ACCOUNT')]" --output tsv)
export AZURE_STORAGE_EP="https://${STORAGE_ACCOUNT}.blob.core.windows.net/"
VHD_URI="${AZURE_STORAGE_EP}${AZURE_STORAGE_CONTAINER}/podvm.vhd"
echo $VHD_URI
https://${STORAGE_ACCOUNT}.blob.core.windows.net/vhd/podvm.vhd

# Create Azure VM Image Version

az sig image-version create    --resource-group $AZURE_RESOURCE_GROUP    --gallery-name $GALLERY_NAME     --gallery-image-definition $GALLERY_IMAGE_DEF_NAME    --gallery-image-version 0.0.2    --target-regions $AZURE_REGION    --os-vhd-uri "$VHD_URI"    --os-vhd-storage-account $AZURE_STORAGE_ACCOUNT

AZURE_IMAGE_ID=$(az sig image-version  list --resource-group  $AZURE_RESOURCE_GROUP --gallery-name $GALLERY_NAME --gallery-image-definition $GALLERY_IMAGE_DEF_NAME --query "[].{Id: id}" --output tsv)

echo $AZURE_IMAGE_ID
"""
Output: 
/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/galleries/demeng_imagegallery/images/rhcos-image/versions/0.0.2 /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/galleries/demeng_imagegallery/images/rhcos-image/versions/0.0.2
"""

# Check the image versions you created

az sig image-version list   --resource-group "${AZURE_RESOURCE_GROUP}"   --gallery-name "${GALLERY_NAME}"   --gallery-image-definition "${GALLERY_IMAGE_DEF_NAME}"   -o table

# Create Azure VM (UEFI mode: vTPM + Secure_boot) base on image version

az vm create   -n "${az_vm_name}"   -g "${AZURE_RESOURCE_GROUP}" --image /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/galleries/demeng_imagegallery/images/rhcos-image/versions/0.0.2 --admin-username core   --custom-data "$(cat ${ignition_path})" --enable-vtpm true   --size Standard_DC2as_v5 --enable-secure-boot true  --security-type ConfidentialVM --os-disk-security-encryption-type VMGuestStateOnly  --boot-diagnostics-storage demengstoragelrs
```

## Step 3: (Optional) Upload Image to Azure
```bash
az_image_name="rhcos-9.6.20250512-0-azure.x86_64"
az_image_blob="${az_image_name}.vhd"
export VHD_URI=https://${STORAGE_ACCOUNT}.blob.core.windows.net/vhd/rhcos-9.6.20250512-0-azure.x86_64

# Upload image blob

az storage blob upload  --container-name $AZURE_STORAGE_CONTAINER --name rhcos-9.6.20250512-0-azure.x86_64.vhd --file rhcos-9.6.20250512-0-azure.x86_64.vhd

# Create the image

az image create -n "${az_image_name}" --resource-group ${AZURE_RESOURCE_GROUP} --source ${VHD_URI} --location ${AZURE_REGION} --os-type Linux --hyper-v-generation V2

# Delete the uploaded blob

az storage blob delete --connection-string "$cs" -c "${az_container}" -n "${az_image_blob}"

# Create VM based on the image:

az_vm_name="my-fcos-vm"
ignition_path="./config.ign"
az vm create -n "${az_vm_name}" -g "${az_resource_group}" --image "${az_image_name}" --admin-username core --custom-data "$(cat ${ignition_path})"
```

## Step 4: (Optional) Create a New Storage Account for Debugging
```bash
# Create a new storage account that allows Standard_LRS 

az storage account create \
  --name demengstoragelrs \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --location eastus \
  --sku Standard_LRS

# After VM creation, find the FULL log by accessing the content of 'Storage Account'

Boot Diagnostics logs and screenshots are stored in a container in the Storage Account you provided. The path is usually:

Follow the instructions:
1. Login to 'Azure Portal'
2. Search 'Storage Account'（eg: demengstoragelrs）
3. Click the 'Containers' in the left side menu
4. Find a container similar to bootdiagnostics-demeng-rhcos-testvm-ovmf3-xxxxxx
5. Click 'Download' to download the serial log
```

## Step 5: (Optional) Configure Static External IP for kbs-service
```bash
[user@host ~]$ az network public-ip create \
  --name my-static-ip \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --sku standard \
  --allocation-method static
[Coming breaking change] In the coming release, the default behavior will be changed as follows when sku is Standard and zone is not provided: For zonal regions, you will get a zone-redundant IP indicated by zones:["1","2","3"]; For non-zonal regions, you will get a non zone-redundant IP indicated by zones:null.
{
  "publicIp": {
    "ddosSettings": {
      "protectionMode": "VirtualNetworkInherited"
    },
    "etag": "W/\"3955bac9-4902-4376-bb8b-178db06f8f1b\"",
    "id": "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/my-static-ip",
    "idleTimeoutInMinutes": 4,
    "ipAddress": "172.178.61.32",
    "ipTags": [],
    "location": "eastus",
    "name": "my-static-ip",
    "provisioningState": "Succeeded",
    "publicIPAddressVersion": "IPv4",
    "publicIPAllocationMethod": "Static",
    "resourceGroup": "${RESOURCE_GROUP}",
    "resourceGuid": "24a1612c-791e-4459-a687-6b8ab8d71b7b",
    "sku": {
      "name": "Standard",
      "tier": "Regional"
    },
    "type": "Microsoft.Network/publicIPAddresses"
  }
}

[user@host ~]$ az network public-ip show   --resource-group ${AZURE_RESOURCE_GROUP}   --name my-static-ip   --query ipAddress   --output tsv

172.178.61.32


[user@host ~]$ cat kbs-service_new.yaml 
apiVersion: v1
kind: Service
metadata:
  name: kbs-service
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-resource-group: "${RESOURCE_GROUP}"
    service.beta.kubernetes.io/azure-pip-name: "my-static-ip"
  namespace: trustee-operator-system
  ownerReferences:
  - apiVersion: confidentialcontainers.org/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: KbsConfig
    name: kbsconfig-sample
    uid: a859231f-4e26-4bb5-a5a5-bc7b8a1338c8 
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  selector:
    app: kbs
  type: LoadBalancer
  externalTrafficPolicy: Cluster
  allocateLoadBalancerNodePorts: false

[user@host ~]$ oc apply -f kbs-service_new.yaml 
```