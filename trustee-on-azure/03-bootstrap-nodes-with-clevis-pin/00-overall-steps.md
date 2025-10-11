# Bootstrap the cluster nodes with the Trustee URL and the clevis pin 
Task: COCL-92 Investigation how to configure ignition for confidential clusters
Steps:
1. Deploy and configure the Trustee Operator on the cluster using the settings from the investigation project.
2. Deploy a web server to host both the remote ignition file and the cluster ignition file.
3. Convert the FCOS with trustee-clevis-pin to a VHD image and upload it to Azure.
4. Create a new MachineSet that uses this image and the luks.ign file to merge the ignition files provided by the web server.