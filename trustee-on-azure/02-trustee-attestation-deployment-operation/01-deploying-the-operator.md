# Deploying and Configuring the Trustee-Operator

**Authors:** demeng@redhat.com \
**Jira Issue:** [COCL-40](https://issues.redhat.com/browse/COCL-40) \
**References:**
- [Setting up OpenShift Confidential Clusters on Azure](https://developers.redhat.com/articles/2025/04/01/how-set-openshift-confidential-clusters-azure)
- [Trustee Operator Documentation](https://github.com/confidential-containers/trustee-operator)

## Provisioning the Openshift on Azure first.

## Deploy trustee-operator

### Prerequisites
Ensure you have `golang`, `kubectl`, `make` available in the `$PATH`.

Clone the [trustee-operator repository](https://github.com/confidential-containers/trustee-operator):

```bash
git clone https://github.com/confidential-containers/trustee-operator.git
cd trustee-operator
```

### Step 1: Deploying Prebuilt Operator Image
To deploy the latest prebuilt image, run the following command:

```bash
make deploy IMG=quay.io/confidential-containers/trustee-operator:latest
```

Verify if the controller is running by executing the following command:

```bash
kubectl get pods -n trustee-operator-system --watch
```

You should see a similar output as below:

```bash
NAME                                                   READY   STATUS    RESTARTS   AGE
trustee-operator-controller-manager-6797b78467-zndkv   1/1     Running   0          111s
```

### Step 2: Deploying CRDs, ConfigMaps, and Secrets

This is an example deployment. Review the config files and change them as per your requirements.

```sh
cd config/samples/all-in-one
# or config/samples/microservices for the microservices mode

# create authentication keys
openssl genpkey -algorithm ed25519 > privateKey
openssl pkey -in privateKey -pubout -out kbs.pem

# create all the needed resources
kubectl apply -k .
```

Verify if the trustee deployment is running by executing the following command:

```sh
kubectl get pods -n trustee-operator-system --selector=app=kbs
```

You should see a similar output as below:

```bash
NAME                                  READY   STATUS    RESTARTS   AGE
trustee-deployment-78bd97f6d4-nxsbb   3/3     Running   0          4m3s
```

The default installation uses empty reference values. You must add real values by updating
the `rvps-reference-values` ConfigMap like shown in the example below:

```yaml
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
        "expired": "2026-01-01T00:00:00Z",
        "hash-value": [
          {
            "alg": "sha256",
            "value": "1"
          }
        ]
      }
    ]
```

The default installation creates a sample K8s secret named `kbsres1` to be made available to clients.
Take a look at [patch-kbs-resources.yaml](config/samples/microservices/patch-kbs-resources.yaml) and update it
with the K8s secrets that you want to deliver to clients via Trustee.

### Uninstallation

Ensure you are in the root folder of the project before running the uninstall commands.

#### Uninstall CRDs

To delete the CRDs from the cluster:

```bash
make uninstall
```

#### Undeploy Controller

Undeploy the controller from the cluster:

```bash
make undeploy
```
