## with MAPI
You can create a new machineset, or update the current existing machineset directly. 
Create a secret to wrap the luks.ign:
```
oc create secret generic luks-ign \
  --from-file=userData=luks.ign \
  -n openshift-machine-api
```
`machineset-clevis-worker-eastus1.yaml`
```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
    machine.openshift.io/GPU: "0"
    machine.openshift.io/memoryMb: "8192"
    machine.openshift.io/vCPU: "2"
  generation: 40
  labels:
    machine.openshift.io/cluster-api-cluster: dev-normal-shared-jtmln
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
  name: dev-normal-clevis-worker-eastus1
  namespace: openshift-machine-api
spec:
  authoritativeAPI: MachineAPI
  replicas: 0
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: dev-normal-shared-jtmln
      machine.openshift.io/cluster-api-machineset: dev-normal-clevis-worker-eastus1
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: dev-normal-shared-jtmln
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: dev-normal-clevis-worker-eastus1
    spec:
      authoritativeAPI: MachineAPI
      lifecycleHooks: {}
      metadata: {}
      providerSpec:
        value:
          apiVersion: machine.openshift.io/v1beta1
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          diagnostics:
            boot:
              customerManaged:
                storageAccountURI: https://yalanstroageaccount.blob.core.windows.net/
              storageAccountType: CustomerManaged
          image:
            resourceID: /resourceGroups/yalan-rg-20250930/providers/Microsoft.Compute/galleries/yalan_Gallery/images/fcos_clevis_image/versions/0.0.1
          kind: AzureMachineProviderSpec
          location: eastus
          managedIdentity: dev-normal-shared-jtmln-identity
          metadata:
            creationTimestamp: null
          networkResourceGroup: dev-normal-shared-jtmln-rg
          osDisk:
            diskSettings: {}
            diskSizeGB: 128
            managedDisk:
              securityProfile:
                diskEncryptionSet: {}
                securityEncryptionType: VMGuestStateOnly
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: dev-normal-shared-jtmln
          resourceGroup: dev-normal-shared-jtmln-rg
          securityProfile:
            settings:
              confidentialVM:
                uefiSettings:
                  secureBoot: Enabled
                  virtualizedTrustedPlatformModule: Enabled
              securityType: ConfidentialVM
          subnet: dev-normal-shared-jtmln-worker-subnet
          userDataSecret:
            name: luks-ign  # refer to the new secret
          vmSize: Standard_DC2ads_v5
          vnet: dev-normal-shared-jtmln-vnet
          zone: "2"
```
Deploy the new machineset, and scale up:
```
oc apply -f machineset-clevis-worker-eastus1.yaml
oc scale --replicas='1' machineset dev-normal-clevis-worker-eastus1
```
Check the VM status

## with CAPI
Create the secret:
```
oc create secret generic luks-ign \
  --from-file=value=luks.ign \
  -n openshift-cluster-api
```
Create AzureMachineTemplate:
`azuremachinetemplate.yaml`
```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureMachineTemplate
metadata:
  name: capi-machine-fcos-clevis
  namespace: openshift-cluster-api
spec:
  template:
    spec:
      location: eastus # keep consistent with the cluster
      identity: None
      vmSize: Standard_DC4ads_v5 # use a vmSize support confidential VM
      # this diagnostics part is for debug purpose
      diagnostics:
        boot: 
          storageAccountType: UserManaged
          userManaged:
            storageAccountURI: https://yalanstroageaccount.blob.core.windows.net/
      osDisk:
        diskSizeGB: 128
        osType: Linux
        managedDisk:
          storageAccountType: Premium_LRS
          securityProfile:    # needed for confidential vm
            securityEncryptionType: VMGuestStateOnly
      # use a image supports confidential vm
      image:
        id: "/subscriptions/1b34f80b-b456-49c3-8aa1-5dddeb9b4ab5/resourceGroups/yalan-rg-20250930/providers/Microsoft.Compute/galleries/yalan_Gallery/images/fcos_clevis_image/versions/0.0.1"
      sshPublicKey: "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUlzeUdTcGFVeFVndzBLWG5tZTZIWWc1UkxoNnlNNTRYMDUvQkFidzhwMlogeWFsemhhbmdAbGFwdG9wCg=="
      securityProfile:  # for confidential vm
        securityType: ConfidentialVM
        uefiSettings:
          secureBootEnabled: true
          vTpmEnabled: true
      networkInterfaces:  # use the subnet of your current cluster
        - subnetName: "aa-421-shared-capz-2fxvd-worker-subnet"
          acceleratedNetworking: false  # disable acceleratedNetworking
```

Create the machineset:
`machineset.yaml`
```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineSet
metadata:
  name: capi-ms-fcos-clevis
  namespace: openshift-cluster-api
spec:
  clusterName: aa-421-shared-capz-2fxvd   # specify the cluster name 
  replicas: 1
  selector:
    matchLabels: 
      test: example
  template:
    metadata:
      labels:
        test: example
    spec:
      bootstrap:
         dataSecretName: luks-ign   # it includes ignition for worker node
      clusterName: aa-421-shared-capz-2fxvd   # cluster name
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: AzureMachineTemplate
        name: capi-machine-fcos-clevis  # refer to the machine template defined above
```