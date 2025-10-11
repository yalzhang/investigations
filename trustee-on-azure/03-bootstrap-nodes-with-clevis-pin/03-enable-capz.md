# Enable capz
Related task: [COCL-126 Create confidential node on Azure with capz](https://issues.redhat.com/browse/COCL-126) 

OpenShift supports adding new nodes via two APIs:
- Machine API (MAPI): Natively supported by OpenShift.
- Cluster API (CAPI): Community-preferred and more common in Kubernetes environments.

*Note*: On Azure, CAPI (CAPZ) is available as a Tech Preview starting from OpenShift 4.21.

This guide explains how to enable CAPZ on a standard Azure OpenShift cluster and use it to create a confidential node that joins a standard (non-confidential) cluster.

Procedure:
1. Install an OpenShift 4.21 nightly build that includes Cluster API as a Tech Preview.

2. Enable the Tech Preview feature gate to automatically deploy the Cluster API components.

3. Create the AzureMachineTemplate and MachineSet resources with confidential VM settings.

## 1. Install cluster with 4.21 nightly build
As cluster api is only supported on Azure since 4.21 as techpreview, so let's install a openshift cluster with 4.21 nightly build. 

Step 1: Download the Installer
1. Visit the nightly release page: 
  https://openshift-release.apps.ci.l2s4.p1.openshiftapps.com/#4.21.0-0.nightly
2. Select a 4.21 nightly build. For example:
   https://openshift-release-artifacts.apps.ci.l2s4.p1.openshiftapps.com/4.21.0-0.nightly-2025-09-25-082813 

Step 2: Append Pull Secret for Nightly Build
1. Navigate to:
  https://docs.ci.openshift.org/docs/how-tos/use-registries-in-build-farm/#how-do-i-log-in-to-pull-images-that-require-authentication
2. Click "app.ci" and login;
3. Click your name on the up-right corner, click "copy login command";
4. Copy "oc login xxxx", run it in your terminal;
5. Run "oc registry login", you will get the secret of registry.ci.openshift.org;
6. Merge the secret of registry.ci.openshift.org with your previous secret;

Install the cluster with the 4.21 nightly installer and modified pull secret. For example, with below install-config.yaml:
```
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    azure:
      type: Standard_B2as_v2
      settings:
        securityType: TrustedLaunch
        trustedLaunch:
          uefiSettings:
            secureBoot: Enabled
            virtualizedTrustedPlatformModule: Enabled
  replicas: 1
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    azure:
      type: Standard_B4as_v2
      settings:
        securityType: TrustedLaunch
        trustedLaunch:
          uefiSettings:
            secureBoot: Enabled
            virtualizedTrustedPlatformModule: Enabled
  replicas: 1
```
## 2. Enable tech preview featuregate
After cluster installed successfully, enable the techpreview featuregate:
```
$ oc version 
Client Version: 4.21.0-0.nightly-2025-09-25-082813
Kustomize Version: v5.6.0
Server Version: 4.21.0-0.nightly-2025-09-25-082813
Kubernetes Version: v1.33.5

$ oc edit featuregate cluster (update the spec.featuregate to be as below)
spec:
  featureSet: TechPreviewNoUpgrade
```
Wait for a while, check the cluster api is installed successfully
```
$ oc get cluster -n openshift-cluster-api
NAME                          CLUSTERCLASS   PHASE         AGE   VERSION
aa-421-normal-techpre-fxdjx                  Provisioned   87s   

$ oc get secret capz-manager-cluster-credential   -n openshift-cluster-api
NAME                              TYPE     DATA   AGE
capz-manager-cluster-credential   Opaque   1      110s

$ oc get azureclusteridentity    -n openshift-cluster-api 
NAME                          TYPE               AGE
aa-421-normal-techpre-fxdjx   ServicePrincipal   2m10s

$  oc get azurecluster  -n openshift-cluster-api 
NAME                          CLUSTER                       READY   REASON   AGE
aa-421-normal-techpre-fxdjx   aa-421-normal-techpre-fxdjx                    2m22s
```
## 3. Create the Machine with confidential VM settings
Prepare the AzureMachineTemplate file with confidential VM settings, named as `aa_421_azuremachinetemplate.yaml`:
```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureMachineTemplate
metadata:
  name: capi-machine-template
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
        id: "/subscriptions/1b34f80b-b456-49c3-8aa1-5dddeb9b4ab5/resourceGroups/fjintest111-ggrbv-rg/providers/Microsoft.Compute/galleries/gallery_fjintest111_ggrbv/images/fjintest111-ggrbv-gen2/versions/latest"
      sshPublicKey: "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUlzeUdTcGFVeFVndzBLWG5tZTZIWWc1UkxoNnlNNTRYMDUvQkFidzhwMlogeWFsemhhbmdAbGFwdG9wCg=="
      securityProfile:  # for confidential vm
        securityType: ConfidentialVM
        uefiSettings:
          secureBootEnabled: true
          vTpmEnabled: true
      networkInterfaces:  # use the subnet of your current cluster
        - subnetName: "aa-421-techpreview-jjrk9-worker-subnet"
          acceleratedNetworking: false  # disable acceleratedNetworking
```
Prepare the machineset yaml file refer to the AzureMachineTemplate defined above, named as `machineset.yaml`:
```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineSet
metadata:
  name: capi-ms
  namespace: openshift-cluster-api
spec:
  clusterName: aa-421-techpreview-jjrk9   # specify the cluster name 
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
         dataSecretName: worker-user-data   # it includes ignition for worker node
      clusterName: aa-421-techpreview-jjrk9   # cluster name
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: AzureMachineTemplate
        name: capi-machine-template  # refer to the machine template defined above
```
Create the resources:
```
$ oc apply -f aa_421_azuremachinetemplate.yaml

$ oc apply -f machineset.yaml

$ oc get azuremachine -n openshift-cluster-api
NAME            READY   SEVERITY   REASON     STATE      AGE
capi-ms-8qmkz   False   Info       Creating   Updating   16m

$ oc get machine -n openshift-cluster-api
NAME            CLUSTER                    NODENAME   PROVIDERID   PHASE     AGE   VERSION
capi-ms-8qmkz   aa-421-techpreview-jjrk9                           Pending   18m   
```
Wait for a while, check the machine. It should be created and running, and join the cluster. 
capi-ms-8qmkz is the new node, which is a confidential vm:
```
$ oc get azuremachine -n openshift-cluster-api
NAME            READY   SEVERITY   REASON   STATE       AGE
capi-ms-8qmkz   True                        Succeeded   32m

$ oc get machine -n openshift-cluster-api
NAME            CLUSTER                    NODENAME        PROVIDERID                                                                                                                                                         PHASE     AGE   VERSION
capi-ms-8qmkz   aa-421-techpreview-jjrk9   capi-ms-8qmkz   azure:///subscriptions/1b34f80b-b456-49c3-8aa1-5dddeb9b4ab5/resourceGroups/aa-421-techpreview-jjrk9-rg/providers/Microsoft.Compute/virtualMachines/capi-ms-8qmkz   Running   33m   

$ oc get azuremachine capi-ms-8qmkz -o yaml | yq e '.spec.securityProfile, .spec.vmSize' -
securityType: ConfidentialVM
uefiSettings:
  secureBootEnabled: true
  vTpmEnabled: true
Standard_DC4ads_v5

$ oc get nodes 
NAME                                            STATUS   ROLES                  AGE     VERSION
aa-421-techpreview-jjrk9-master-0               Ready    control-plane,master   6h41m   v1.33.5
aa-421-techpreview-jjrk9-worker-eastus1-74vwd   Ready    worker                 6h10m   v1.33.5
capi-ms-8qmkz                                   Ready    worker                 5m47s   v1.33.5
```
Scale down to delete the machine:
```
$ oc get machineset -n openshift-cluster-api
NAME      CLUSTER                    REPLICAS   READY   AVAILABLE   AGE   VERSION
capi-ms   aa-421-techpreview-jjrk9   1          1       1           36m   

$ oc scale --replicas=0 machineset capi-ms  -n openshift-cluster-api
machineset.cluster.x-k8s.io/capi-ms scaled

$ oc get nodes 
NAME                                            STATUS   ROLES                  AGE     VERSION
aa-421-techpreview-jjrk9-master-0               Ready    control-plane,master   6h45m   v1.33.5
aa-421-techpreview-jjrk9-worker-eastus1-74vwd   Ready    worker                 6h15m   v1.33.5
```

*Notes*:
- Accelerated network should be disabled to use Confidential VM, since the VMsize like Standard_DC4ads_v5 does not support it;
- As the current node of the cluster is not a confidential VM, we can not use the same image, so I get the image id from another confidential cluster;

*Reference*:
- [polaroin case OCP-75884](https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-75884)
- https://github.com/openshift/enhancements/blob/master/enhancements/machine-api/cluster-api-integration.md 
- https://capz.sigs.k8s.io/reference/v1beta1-api.html?highlight=machine#azuremachinespec 