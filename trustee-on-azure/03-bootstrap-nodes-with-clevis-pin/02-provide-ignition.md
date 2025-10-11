# Provide ignition files
There are 3 ignition files involved:
* luks.ign: The top-level wrapper, merges the below two, and adds trustee client key, autologin, etc.
* pin-trustee.ign: Defines encryption (LUKS) and filesystem format.
* worker.ign: Base OpenShift worker configuration (cluster-provided). Don’t modify this.

The VM will boot with luks.ign, and merge the pin-trustee.ign and worker.ign which provided by a web server on the openshift cluster.

## ignition files
### worker.ign
When the Machineset scales up, it need the ignition file (bootstrap config) to tell the node how to configure itself — install kubelet, connect to cluster API, pull certs, etc. The Ignition config is passed as userDataSecret in the Machineset definition. This userDataSecret contains a base64-encoded Ignition JSON blob. We can get it from the cluster:
```
$ oc get machineset dev-normal-shared-jtmln-worker-eastus1 -n openshift-machine-api \
  -o jsonpath='{.spec.template.spec.providerSpec.value.userDataSecret.name}'
worker-user-data

$ oc get secret worker-user-data -n openshift-machine-api \
  -o jsonpath='{.data.userData}' | base64 --decode > worker.ign
  
(check the worker.ign in case the keyword changes, you can try jsonpath='{.data.value}', seems it changes to jsonpath='{.data.value}' on 4.21)
```
### pin-trustee.bu(ign)
Reuse configs/remote-ign/pin-trustee.bu, get files from ./ignition-files and do some modification:

### luks.bu(ign)
Reuse configs/luks.bu,  
<WEB_SERVER_URL>: the route addr of the web server, like `web-server-trustee-operator-system.apps.dev-normal-shared.cc.azure.dog8.cloud`, make sure we can get the file with "wget http://web-server-trustee-operator-system.apps.dev-normal-shared.cc.azure.dog8.cloud/pin-trustee.ign"
<trustee_clinet_KEY>: the privateKey paired with the trustee kbs-auth-public-key. we have created the secret "kbs-client-secret", 
now we have files as below:
```
$ cd ignition-files

$ ls
luks.bu  pin-trustee.bu  worker.ign
```
## Deploy web server
1. Deploy a web server on openshift to provide worker.ign and pin-trustee.ign files to the client.
Deploy the web-server (use yaml file ), get the route url:
```
$ oc apply -f web-server.yaml 

$ oc get route web-server
NAME         HOST/PORT                                                                        PATH   SERVICES     PORT   TERMINATION   WILDCARD
web-server   web-server-trustee-operator-system.apps.aa-421-shared-capz.cc.azure.dog8.cloud          web-server   8080                 None
```
Then update the *.bu files, convert them to ign files, and create the configmap:
luks.bu:
- <WEB_SERVER_URL>: The HOST/PORT of the route webserver
- <KEY>: The public key for you to login the new node with core user

pin-trustee.bu:
- <KBS_EXTERNAL_IP>: the KBS service external ip address

convert the ignition files then create the configmap:
```
podman run --rm -i -v $(pwd):/work:z quay.io/confidential-clusters/butane:clevis-pin-trustee \
  --pretty --strict -o /work/luks.ign /work/luks.bu

podman run --rm -i -v $(pwd):/work:z quay.io/confidential-clusters/butane:clevis-pin-trustee \
  --pretty --strict -o /work/pin-trustee.ign /work/pin-trustee.bu

oc create configmap http-ignition-config --from-file=pin-trustee.ign \
  --from-file=worker.ign -n trustee-operator-system

oc rollout restart deployment.apps/web-server 
```
Then check the web server, ensure the ignition files can be fetched successfully and the content is correct:
```
$ oc get pod -n trustee-operator-system --selector=app=web-server
NAME                         READY   STATUS    RESTARTS   AGE
web-server-6c744db74-5pc67   1/1     Running   0          47m

$ wget http://web-server-trustee-operator-system.apps.aa-421-shared-capz.cc.azure.dog8.cloud/worker.ign

$ wget http://web-server-trustee-operator-system.apps.aa-421-shared-capz.cc.azure.dog8.cloud/pin-trustee.ign
```
Next step, refer to 04-bootstrap-nodes-with-clevis-pin.md for how to boot a new node with these ignition files.