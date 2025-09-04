# Performing and handling node CoreOS updates

In Confidential Clusters, we must be able to adapt reference values to changes in the nodes of the cluster.
Notably, kernel or UKI updates, as well as updates to EFI and GRUB, require a recompute of the PCR values.
When machines are managed by the container platform, such as in OpenShift and its machine config operator, we can use that platform's technologies to watch for updates; then a recompute can be triggered as long as the versions updated to are approved.
Such updates may then happen by general container platform updates or by custom image application.
This doc shows how to update a kernel on OKD to test this use case.

## Layering

OpenShift uses bootable container images for its nodes, and supports layering atop these images in-cluster to update them.
However, we assume that this feature is **not** enabled, and will use _out-of-cluster layering_ to generate a node image.
We will base the layers on top of the image currently used for the cluster nodes, and specify its URL in a MachineConfig object.

## Performing the update

Based on [OCP doc: Using out-of-cluster layering to apply a custom layered image](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/machine_configuration/mco-coreos-layering#coreos-layering-configuring_mco-coreos-layering).

### Retrieve currently used image

> In principle, you could operate using any CoreOS image, but this upgrade path is unsupported and not guaranteed to work.

In this example, we will update the kernel of a sole master node.
Retrieve the desired machine config pool and its rendered machine config.

```sh
$ oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-1c6c4ea5376f9349020b0070f791fe10   True      False      False      1              1                   1                     0                      26h
worker   rendered-worker-4fa0fbb08f65ab40664cb17eb4e8f57a   True      False      False      0              0                   0                     0                      26h
$ mc=$(oc get mcp master -ojson | jq -r .spec.configuration.name)
```

Fetch the OS image URL of that config.

```sh
$ oc describe mc $mc
# ...
  Os Image URL: quay.io/okd/scos-content@sha256:3813e6608a999756931d3d621932af9662860e71a552b2670f9fe320bf0d3585
$ img_url=$(oc get mc $mc -ojson | jq -r .spec.osImageURL)
```

### Find a kernel to update to

> Using the kernel version given in the example here may be a downgrade by the time you read this. This may still work, but upgrades can be more reliable. The version might also not exist in the repository any more.

For CentOS Stream 9, go to [the repository](https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/) and find a kernel version, e.g. `5.14.0-605`.

### Create an image

> Other setups may require a pull secret (`oc -n openshift-config get secrets pull-secret -o json | jq -r '.data[".dockerconfigjson"]' | base64 -d`) or make it possible to push to a cluster registry.

Using the URLs from above:

```Dockerfile
# Containerfile
FROM quay.io/okd/scos-content@sha256:3813e6608a999756931d3d621932af9662860e71a552b2670f9fe320bf0d3585
RUN rpm-ostree override replace http://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/kernel-{,core-,modules-,modules-core-,modules-extra-}5.14.0-605.el9.x86_64.rpm && \ 
    rpm-ostree cleanup -m && \
    ostree container commit
```

Push to a registry available from the cluster:

```sh
$ podman build -t quay.io/my-registry/scos-kernel-layer -f Containerfile
# ...
Successfully tagged quay.io/my-registry/scos-kernel-layer:latest
72080da26ffcc57f479860c447d661ddc956a9419437905739ada0d5ca7f1a30
$ podman push quay.io/my-registry/scos-kernel-layer
```

### Create and apply a machine config

```yaml
# machineconfig.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: os-layer-custom
spec:
  osImageURL: quay.io/my-registry/scos-kernel-layer@sha256:72080da26ffcc57f479860c447d661ddc956a9419437905739ada0d5ca7f1a30
```

```sh
$ oc apply -f machineconfig.yaml
```

The new machine config, as well as the render stemming from it, should exist.

```sh
$ oc get mc
NAME                                               GENERATEDBYCONTROLLER                      IGNITIONVERSION   AGE
# ...
os-layer-custom                                                                                                 6m45s
rendered-master-15886c901b07549efacdde5fe731ff3c   7ef676ce0b13a25c6572d4595d92fd487dbc98b5   3.5.0             6m36s
rendered-master-1c6c4ea5376f9349020b0070f791fe10   7ef676ce0b13a25c6572d4595d92fd487dbc98b5   3.5.0             26h
```

The machine config pool should now also use this new render.

```sh
$ oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-15886c901b07549efacdde5fe731ff3c   False     True       False      1              1                   1                     0                      26h
worker   rendered-worker-4fa0fbb08f65ab40664cb17eb4e8f57a   True      False      False      0              0                   0                     0                      26h
```

The machine config pool should then converge to being updated.

```sh
$ oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-15886c901b07549efacdde5fe731ff3c   True      False      False      1              1                   2                     0                      26h
worker   rendered-worker-4fa0fbb08f65ab40664cb17eb4e8f57a   True      False      False      0              0                   0                     0                      26h
```

Verify the kernel has updated on the node.

```sh
$ oc get nodes
NAME                                       STATUS   ROLES                         AGE   VERSION
cocl-ctlplane-0.confidential-cluster.org   Ready    control-plane,master,worker   26h   v1.32.4
$ oc get node cocl-ctlplane-0.confidential-cluster.org -ojson | jq .status.nodeInfo.kernelVersion
"5.14.0-605.el9.x86_64"
```

## Watching for the update

Use a watcher/informer on `.spec.osImageURL` of all machine configs to take note of images to be added.
