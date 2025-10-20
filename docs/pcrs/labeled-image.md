# Labeling a bootable container image with PCR values

[cocl-operator](https://github.com/confidential-clusters/cocl-operator) is able to skip computation of the PCR values of a bootable container image, and thus its potential download, when the image is labeled with the PCRs expected for it using the `org.coreos.pcrs` label.
This guide shows how to manually attach such a label to an image.

# Retrieving the values

## Option 1: With the operator

The operator makes use of [image volumes](https://kubernetes.io/docs/tasks/configure-pod-container/image-volumes/), reading directly from the image that we will label.
An image reference that is accepted by the operator as an approved image will be stored to the `image-pcrs` ConfigMap in the operator's namespace.

For the image `quay.io/confidential-clusters/fedora-coreos@sha256:e71dad00aa0e3d70540e726a0c66407e3004d96e045ab6c253186e327a2419e5`, it could look like this:

```sh
$ kubectl describe configmap -n confidential-clusters image-pcrs
Name:         image-pcrs
Namespace:    confidential-clusters
Labels:       <none>
Annotations:  <none>

Data
====
image-pcrs.json:
----
{"quay.io/confidential-clusters/fedora-coreos@sha256:e71dad00aa0e3d70540e726a0c66407e3004d96e045ab6c253186e327a2419e5":{"first_seen":"2025-10-17T10:05:38.074795010Z","pcrs":[{"id":4,"value":"551bbd142a716c67cd78336593c2eb3b547b575e810ced4501d761082b5cd4a8","parts":[{"name":"EV_EFI_ACTION","hash":"3d6772b4f84ed47595d72a2c4c5ffd15f5bb72c7507fe26f2aaee2c69d5633ba"},{"name":"EV_SEPARATOR","hash":"df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"94896c17d49fc8c8df0cc2836611586edab1615ce7cb58cf13fc5798de56b367"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"bc6844fc7b59b4f0c7da70a307fc578465411d7a2c34b0f4dc2cc154c873b644"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"2b1dc59bc61dbbc3db11a6f3b0708c948efd46cceb7f6c8ea2024b8d1b8c829a"}]},{"id":7,"value":"b3a56a06c03a65277d0a787fcabc1e293eaa5d6dd79398f2dda741f7b874c65d","parts":[{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"ccfc4bb32888a345bc8aeadaba552b627d99348c767681ab3141f5b01e40a40e"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"adb6fc232943e39c374bf4782b6c697f43c39fca1f4b51dfceda21164e19a893"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"b5432fe20c624811cb0296391bfdf948ebd02f0705ab8229bea09774023f0ebf"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"4313e43de720194a0eabf4d6415d42b5a03a34fdc47bb1fc924cc4e665e6893d"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"001004ba58a184f09be6c1f4ec75a246cc2eefa9637b48ee428b6aa9bce48c55"},{"name":"EV_SEPARATOR","hash":"df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"4d4a8e2c74133bbdc01a16eaf2dbb5d575afeb36f5d8dfcf609ae043909e2ee9"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"e8e9578f5951ef16b1c1aa18ef02944b8375ec45ed4b5d8cdb30428db4a31016"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"ad5901fd581e6640c742c488083b9ac2c48255bd28a16c106c6f9df52702ee3f"}]},{"id":14,"value":"17cdefd9548f4383b67a37a901673bf3c8ded6f619d36c8007562de1d93c81cc","parts":[{"name":"EV_IPL","hash":"e8e48e3ad10bc243341b4663c0057aef0ec7894ccc9ecb0598f0830fa57f7220"},{"name":"EV_IPL","hash":"8d8a3aae50d5d25838c95c034aadce7b548c9a952eb7925e366eda537c59c3b0"},{"name":"EV_IPL","hash":"4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"}]}]}}


BinaryData
====

Events:  <none>
```

Refer to [Labeling the image](#labeling-the-image) for further steps.

## Option 2: With the compute-pcrs binary

For this approach, we will use the image again, but attach it to a Podman container.
Check out the compute-pcrs and reference-values repositories and build a compute-pcrs container:

```sh
~ $ git clone https://github.com/confidential-clusters/compute-pcrs
Cloning into 'compute-pcrs'...
...
Resolving deltas: 100% (308/308), done.
~ $ git clone https://github.com/confidential-clusters/reference-values
Cloning into 'reference-values'...
...
Resolving deltas: 100% (8/8), done.
~ $ cd compute-pcrs
~/compute-pcrs $ just build-container
[1/2] STEP 1/4: FROM ghcr.io/confidential-clusters/buildroot:latest AS builder
...
Successfully tagged localhost/compute-pcrs:latest
ca7b509881b785a918a9e18e80fe80a2b18f04a1b814737b91800d2c7b7e7336
```

Run compute-pcrs, providing the correct source image and value paths.

```sh
~/compute-pcrs $ podman run --rm --security-opt label=disable \
  -v ../reference-values:/var/srv/test-data \
  --mount=type=image,source=quay.io/confidential-clusters/fedora-coreos:42.20250705.3.0,destination=/var/srv/image,rw=false \
  compute-pcrs compute-pcrs all --rootfs /var/srv/image \
  --efivars /var/srv/test-data/efivars/qemu-ovmf/fedora-42 \
  --mok-variables /var/srv/test-data/mok-variables/fedora-42 \
  2> /dev/null | tr -d '\n' | sed 's/ //g'
{"pcrs":[{"id":4,"value":"551bbd142a716c67cd78336593c2eb3b547b575e810ced4501d761082b5cd4a8","parts":[{"name":"EV_EFI_ACTION","hash":"3d6772b4f84ed47595d72a2c4c5ffd15f5bb72c7507fe26f2aaee2c69d5633ba"},{"name":"EV_SEPARATOR","hash":"df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"94896c17d49fc8c8df0cc2836611586edab1615ce7cb58cf13fc5798de56b367"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"bc6844fc7b59b4f0c7da70a307fc578465411d7a2c34b0f4dc2cc154c873b644"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"2b1dc59bc61dbbc3db11a6f3b0708c948efd46cceb7f6c8ea2024b8d1b8c829a"}]},{"id":7,"value":"b3a56a06c03a65277d0a787fcabc1e293eaa5d6dd79398f2dda741f7b874c65d","parts":[{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"ccfc4bb32888a345bc8aeadaba552b627d99348c767681ab3141f5b01e40a40e"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"adb6fc232943e39c374bf4782b6c697f43c39fca1f4b51dfceda21164e19a893"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"b5432fe20c624811cb0296391bfdf948ebd02f0705ab8229bea09774023f0ebf"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"4313e43de720194a0eabf4d6415d42b5a03a34fdc47bb1fc924cc4e665e6893d"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"001004ba58a184f09be6c1f4ec75a246cc2eefa9637b48ee428b6aa9bce48c55"},{"name":"EV_SEPARATOR","hash":"df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"4d4a8e2c74133bbdc01a16eaf2dbb5d575afeb36f5d8dfcf609ae043909e2ee9"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"e8e9578f5951ef16b1c1aa18ef02944b8375ec45ed4b5d8cdb30428db4a31016"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"ad5901fd581e6640c742c488083b9ac2c48255bd28a16c106c6f9df52702ee3f"}]},{"id":14,"value":"17cdefd9548f4383b67a37a901673bf3c8ded6f619d36c8007562de1d93c81cc","parts":[{"name":"EV_IPL","hash":"e8e48e3ad10bc243341b4663c0057aef0ec7894ccc9ecb0598f0830fa57f7220"},{"name":"EV_IPL","hash":"8d8a3aae50d5d25838c95c034aadce7b548c9a952eb7925e366eda537c59c3b0"},{"name":"EV_IPL","hash":"4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"}]}]}
```

# Labeling the image

Paste the entire `pcrs` key and value into a Containerfile:

```dockerfile
FROM quay.io/confidential-clusters/fedora-coreos@sha256:e71dad00aa0e3d70540e726a0c66407e3004d96e045ab6c253186e327a2419e5
LABEL org.coreos.pcrs='{"pcrs":[{"id":4,"value":"551bbd142a716c67cd78336593c2eb3b547b575e810ced4501d761082b5cd4a8","parts":[{"name":"EV_EFI_ACTION","hash":"3d6772b4f84ed47595d72a2c4c5ffd15f5bb72c7507fe26f2aaee2c69d5633ba"},{"name":"EV_SEPARATOR","hash":"df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"94896c17d49fc8c8df0cc2836611586edab1615ce7cb58cf13fc5798de56b367"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"bc6844fc7b59b4f0c7da70a307fc578465411d7a2c34b0f4dc2cc154c873b644"},{"name":"EV_EFI_BOOT_SERVICES_APPLICATION","hash":"2b1dc59bc61dbbc3db11a6f3b0708c948efd46cceb7f6c8ea2024b8d1b8c829a"}]},{"id":7,"value":"b3a56a06c03a65277d0a787fcabc1e293eaa5d6dd79398f2dda741f7b874c65d","parts":[{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"ccfc4bb32888a345bc8aeadaba552b627d99348c767681ab3141f5b01e40a40e"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"adb6fc232943e39c374bf4782b6c697f43c39fca1f4b51dfceda21164e19a893"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"b5432fe20c624811cb0296391bfdf948ebd02f0705ab8229bea09774023f0ebf"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"4313e43de720194a0eabf4d6415d42b5a03a34fdc47bb1fc924cc4e665e6893d"},{"name":"EV_EFI_VARIABLE_DRIVER_CONFIG","hash":"001004ba58a184f09be6c1f4ec75a246cc2eefa9637b48ee428b6aa9bce48c55"},{"name":"EV_SEPARATOR","hash":"df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"4d4a8e2c74133bbdc01a16eaf2dbb5d575afeb36f5d8dfcf609ae043909e2ee9"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"e8e9578f5951ef16b1c1aa18ef02944b8375ec45ed4b5d8cdb30428db4a31016"},{"name":"EV_EFI_VARIABLE_AUTHORITY","hash":"ad5901fd581e6640c742c488083b9ac2c48255bd28a16c106c6f9df52702ee3f"}]},{"id":14,"value":"17cdefd9548f4383b67a37a901673bf3c8ded6f619d36c8007562de1d93c81cc","parts":[{"name":"EV_IPL","hash":"e8e48e3ad10bc243341b4663c0057aef0ec7894ccc9ecb0598f0830fa57f7220"},{"name":"EV_IPL","hash":"8d8a3aae50d5d25838c95c034aadce7b548c9a952eb7925e366eda537c59c3b0"},{"name":"EV_IPL","hash":"4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"}]}]}'
```

Build and tag this image.

```sh
$ podman build -f Containerfile -t quay.io/confidential-clusters/fedora-coreos:42.20250705.3.0-tagged-pcrs 
```
