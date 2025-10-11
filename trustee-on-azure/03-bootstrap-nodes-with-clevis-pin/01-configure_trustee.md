# Trustee operator configuration
Apply the trustee configuration as in this project to the openshift cluster.
1. Deploy the trustee operator on the cluster;
```
$ git clone git@github.com:confidential-containers/trustee-operator.git
$ cd trustee-operator
$ make deploy IMG=quay.io/confidential-containers/trustee-operator:latest
$ kubectl get pods -n trustee-operator-system --watch
NAME                                                   READY   STATUS    RESTARTS   AGE
trustee-operator-controller-manager-767986499f-b77m6   1/1     Running   0          27s
```
2. Update the image part of deployment.apps/trustee-operator-controller-manager:
- KBS_IMAGE_NAME_MICROSERVICES
- AS_IMAGE_NAME

```
 $ oc get deployment.apps/trustee-operator-controller-manager -o yaml  -n trustee-operator-system
    spec:
      containers:
      - args:
        - --metrics-bind-address=:8443
        - --leader-elect
        - --health-probe-bind-address=:8081
        command:
        - /manager
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        - name: KBS_IMAGE_NAME
          value: registry.redhat.io/build-of-trustee/trustee-rhel9@sha256:dddf41eb16c4c58d4977639df03311825abb11153ca6b678c93e604152a6a6e6
          # ghcr.io/confidential-containers/key-broker-service:built-in-as-v0.13.0
        - name: KBS_IMAGE_NAME_MICROSERVICES
          value: quay.io/afrosi_rh/kbs-grpc-as:latest  //update to be image in configs/trustee/etc/containers/systemd/kbs.container
        - name: AS_IMAGE_NAME
          value: quay.io/afrosi_rh/coco-as-grpc:latest //update to be image in configs/trustee/etc/containers/systemd/as-grpc.container
        - name: RVPS_IMAGE_NAME
          value: ghcr.io/confidential-containers/staged-images/rvps:latest //same with the one in configs/trustee/etc/containers/systemd/rvps.container, no update
        - name: OPERATOR_CONDITION_NAME
          value: trustee-operator.v0.4.2
        image: registry.redhat.io/build-of-trustee/trustee-rhel9-operator@sha256:fe8e23de14ad088c79b1bd5e7aab08a1b88a86679effcbf174be81e761bd9d6d
```
3. Configure the trustee: 
   There is an example deployment in trustee-on-azure/03-bootstrap-nodes-with-clevis-pin/trustee-configure-files. Review the config files and change it as per your requirements. 
   ```
   cd trustee-configure-files
   # create authentication keys
   openssl genpkey -algorithm ed25519 > privateKey
   openssl pkey -in privateKey -pubout -out kbs.pem
   oc create secret generic kbs-auth-public-key \
      --from-file=kbs.pem \
      -n trustee-operator-system
   # create all the needed resources
   oc apply -k .
   ```
*Note*: the pcr values in trustee-on-azure/03-bootstrap-nodes-with-clevis-pin/trustee-configure-files/04-rvps-reference-values.yaml is got by tpm_pcrread on the qemu test vm aftet it boot sucessfully in the qemu 2 VMs demo. The qemu test vm and the Azure vm use the same base fcos image, and build the the same Container file, refer to coreos/justfile, for azure VM, just replace the platform from 'qemu' to 'azure' in the last step `osbuild-qemu`. 

4. Check the deployment is ready:
```
$ oc get all -n trustee-operator-system
Warning: apps.openshift.io/v1 DeploymentConfig is deprecated in v4.14+, unavailable in v4.10000+
NAME                                                       READY   STATUS    RESTARTS       AGE
pod/trustee-deployment-6dbc6d6cb4-xdxtv                    3/3     Running   1 (2m2s ago)   2m4s
pod/trustee-operator-controller-manager-7849985c75-wpnnb   1/1     Running   0              48m

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP    PORT(S)    AGE
service/kbs-service   ClusterIP   172.30.64.178   74.179.216.49  8080/TCP   7m59s

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trustee-deployment                    1/1     1            1           8m
deployment.apps/trustee-operator-controller-manager   1/1     1            1           56m
......
```
5. Test it with client pod
Save to `client-pod.yaml`:
```
apiVersion: v1
kind: Pod
metadata:
  name: kbs-client-pod
  namespace: trustee-operator-system
spec:
  containers:
  - name: client
    image: quay.io/confidential-containers/kbs-client:v0.15.0
    command: ["/bin/sh", "-c", "sleep infinity"]
    volumeMounts:
    - name: client-secret-volume
      mountPath: "/etc/client-secret"
      readOnly: true
  volumes:
  - name: client-secret-volume
    secret:
      secretName: kbs-client-secret
```
Test the trustee server with the client pod:
```
#  Step 1: Create the client secret from your existing private key:
oc create secret generic kbs-client-secret \
--from-file=privateKey  \
-n trustee-operator-system

# Step 2: Deploy the client pod (if it's not already running):
oc apply -f client-pod.yaml

# Step 3: Run the `get-resource` command:
$ oc exec -n trustee-operator-system kbs-client-pod -- kbs-client --url http://kbs-service:8080 get-resource --path "default/machine/root" 
[2025-10-17T12:57:05Z WARN  attester] No TEE platform detected. Sample Attester will be used.
             If you are expecting to collect evidence from inside a confidential guest,
             either your guest is not configured correctly, or your attestation client
             was not built with support for the platform.
    
             Verify that your guest is a confidential guest and that your client
             (such as kbs-client or attestation-agent) was built with the feature
             corresponding to your platform.
    
             Attestation will continue using the fallback sample attester.
[2025-10-17T12:57:05Z WARN  kbs_protocol::client::rcar_client] Authenticating with KBS failed. Perform a new RCAR handshake: ErrorInformation {
        error_type: "https://github.com/confidential-containers/kbs/errors/TokenNotFound",
        detail: "Attestation Token not found",
    }
MmI0NDJkZDVkYjQ0NzgzNjc3MjllZjhiYmYyZTc0ODA=
```

Let's boot a VM on Azure with the build fcos image with clevis pin, to try the attestion. Follow the other documents.