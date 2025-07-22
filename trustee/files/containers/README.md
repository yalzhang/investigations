# Trustee container/systemd files

## Multi-container micro-services Trustee
These systemd-unit files automatically start running containers within a VM
created using script/install_vm.sh -b trustee/config.bu <-k SSH_PUB_KEY>

### as-grpc.container
Running the attestation service

Listening on port 50004

### kbs.container
Running KBS (key-broker-service)

Listening on port 8080

### key-generation.container
Generating cryptographic (ed25519) keys, that are being used
by KBS and KBC, in /opt/confidential-containers/kbs/user-keys

### keyprovider.container
Running CoCo keyprovider (generating CoCo-compatible encrypted images).

Not yet being used in the Confidential Clusters project.

Listening on port 50000

### rvps.container
Running the RVPS service, providing reference-values to the attestation-service

Listening on port 50003

### kbc.container
A container with kbs-client.

To be used to configure and test Trustee (using 'podman exec').
Does nothing but wait (tail -f /dev/null).

### trustee.network
A configuration file for setting up a network bridge.
A part of micro-services Trustee.

Used by install-vm.sh script.

### -----------------------------------------------------

## Standalone Trustee containers
### trustee.container
A standalone container running Trustee.

Also contains kbs-client for simple configuration.

Build with e.g.: buildah build -f trustee.container -t trustee:latest .

Or with e.g.: buildah build --build-arg COMMIT=v0.11.0 -f trustee.container -t trustee:v0.11.0 .

Needs to be configured when being run, e.g. by passing a volume with
configuration files and scripts.

For example: podman run -it --rm -v configdir:/configdir:ro,z -p <port:port> trustee:latest /bin/bash

Within the container - copy files and run kbs --config-file <path-to-kbs-config.toml> + upload configurations with kbs-client.

### trustee-attester.container
A container running trustee-attester

Build with e.g.: buildah build -f trustee-attester.container -t trustee-attester:latest .

Or with e.g.: buildah build --build-arg COMMIT=v0.11.0 -f trustee-attester.container -t trustee-attester:v0.11.0 .

Or with e.g.: buildah build --build-arg ATTESTERS=snp -f trustee-attester.container -t trustee-attester:latest

Run with e.g.: podman run -it --rm --network host trustee-attester:latest /bin/bash

Within the container run: trustee-attester --url <KBSURL> get-resource --path <resource-path> (can also be added in the "podman run" command)



