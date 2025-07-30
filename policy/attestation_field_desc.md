`hardware`: Verifying the Trusted Computing Base (TCB) for Firmware. The core goal of this module is to ensure that confidential virtual machines (CVMs) run on physical hosts with known, secure, and untampered firmware and microcode. This is achieved by verifying the Trusted Computing Base (TCB) version to prevent firmware downgrade attacks.

`executables`: Verifying executable code and boot integrity.This function verifies the integrity of the boot software stack (firmware, bootloader, kernel, etc.). In Azure's vTPM attestation model, this is accomplished by checking hash values of the Platform Configuration Registers (PCRs).

`configuration`: Enforces Platform and Customer Policies. Verifies that the virtual machine's runtime configuration and hardware-enforced security policies conform to expectations.

```bash
executables := 3 if {
    input.azsnpvtpm.measurement in data.reference.measurement
    # Meaning and Source:
    # Represents evidence collected from an Azure CVM that is requesting attestation. 
    # A measurement is a cryptographic hash value generated very 
    # early in the CVM boot process, called "Measured Boot." 
    # During this process, each critical boot component (such as UEFI firmware, boot loader,
    # and operating system kernel) is hashed before being loaded and executed.
    
    # The role of the vTPM: In Azure CVMs, these sequential hash values are securely recorded in a
    # dedicated virtual Trusted Platform Module (vTPM). 
    # The vTPM contains a set of special memory locations called Platform Configuration Registers (PCRs). 
    # Each measurement is irreversibly "extended" into the corresponding PCRs, forming a final cumulative 
    # hash value that represents the complete state of the entire boot chain.
    
    # Thus, input.azsnpvtpm.measurement is effectively the final value of a key PCR or sets of PCRs in the CVM's vTPM. 
    # It acts like a unique digital fingerprint, accurately reflecting the entire software stack used to boot the VM. 
    # Any subtle modification to the boot components—whether malicious (such as a rootkit) or
    # benign (such as a kernel update)—will fundamentally alter this "fingerprint."
    
    input.azsnpvtpm.tpm.pcr4 in data.reference.snp_pcr04
    input.azsnpvtpm.tpm.pcr7 in data.reference.snp_pcr07
    input.azsnpvtpm.tpm.pcr11 in data.reference.snp_pcr11
}
```

```bash
hardware := 2 if {
    input.azsnpvtpm.reported_tcb_bootloader in data.reference.tcb_bootloader
    # The bootloader for the AMD Secure Processor. It is the first code to start the Secure Processor. Its value is derived from the BOOT_LOADER section of the REPORTED_TCB field in the ATTESTATION_REPORT.
    
    input.azsnpvtpm.reported_tcb_microcode in data.reference.tcb_microcode
    # The microcode patch level applied to all CPU cores. Microcode is used to fix CPU hardware errata. Its value is derived from the MICROCODE section of the REPORTED_TCB field.
    
    input.azsnpvtpm.reported_tcb_snp in data.reference.tcb_snp
    # The core firmware responsible for implementing the SEV-SNP functionality. Its value is derived from the SNP portion of the REPORTED_TCB field.
    
    input.azsnpvtpm.reported_tcb_tee in data.reference.tcb_tee
    # Trusted Execution Environment operating system running on the AMD Secure Processor. This value is derived from the TEE portion of the REPORTED_TCB field.
    
    # Reference link: https://www.amd.com/content/dam/amd/en/documents/epyc-technical-docs/specifications/56860.pdf
}
```

```bash
configuration := 2 if {
    input.azsnpvtpm.platform_smt_enabled in data.reference.smt_enabled
    # Meaning and Source:
    # This is a factual statement about the state of the physical host. 
    # It reflects whether the host CPU currently has SMT enabled. 
    # The value is derived from the SMT_EN bit in the PLATFORM_INFO structure 
    # in the hardware attestation report.

    # Possible Values and Recommended Settings:
    #   - true: SMT is enabled.
    #   - false: SMT is not enabled.
    #   - Recommended Value: false. Since SMT may introduce the risk of cross-thread
    #     side-channel attacks, the industry generally recommends disabling
    #     SMT at the host level for workloads with high security requirements.

    input.azsnpvtpm.policy_smt_allowed in data.reference.smt_allowed
    # Meaning and Source:
    # This is a hardware-enforced guest policy set at VM startup. 
    # It specifies whether the VM is allowed to use SMT, even if the host has SMT enabled.
    # The value is taken from the SMT bit of the GUEST_POLICY structure.

    # Possible Values and Recommended Settings:
    #   - 0: Disallow SMT.
    #   - 1: Allow SMT.
    #   - Recommended Value: 0. SMT is disallowed. Explicitly disabling usage in customer policy, 
    #     combined with the above 'platform_smt_enabled = false', 
    #     creates a double check mechanism that demonstrates a sophisticated defense-in-depth approach: 
    #     The policy not only verifies that the platform's current configuration is correct,
    #     but also ensures that restrictive policies are set for VMs to prevent them from 
    #     exploiting potentially vulnerable functionality if they are
    #     mistakenly scheduled onto a misconfigured host.

    input.azsnpvtpm.platform_tsme_enabled in data.reference.tsme_enabled
    # Meaning and Source: 
    # This policy checks whether Transparent Secure Memory Encryption (TSME) is enabled on the host. 
    # TSME is an AMD technology that encrypts the entire physical memory, 
    # providing basic memory confidentiality protection for the system. SEV-SNP provides stronger, 
    # isolated encryption for each virtual machine on top of this. 
    # The value is derived from the TSME_EN bit of the PLATFORM_INFO structure.

    # Possible Values and Recommended Settings:
    #   - true: TSME is enabled.
    #   - false: TSME is not enabled.
    #   - Recommended Value: true. While SEV-SNP provides stronger protection, 
    #     it is good security practice to enable TSME as an additional layer of defense.

    input.azsnpvtpm.policy_abi_major in data.reference.abi_major    
    input.azsnpvtpm.policy_abi_minor in data.reference.abi_minor
    # Meaning and Source:
    # These two policy lines check the minimum firmware ABI (Application Binary Interface) 
    # major and minor version numbers required for the guest to run. 
    # This ensures compatibility and functional correctness between the guest operating system 
    # and the host firmware. These values are taken from the ABI_MAJOR and ABI_MINOR 
    # fields of the GUEST_POLICY structure.
    # ABI_MAJOR: The minimum ABI major version required for this guest to run.
    # ABI_MINOR: The minimum ABI minor version required for this guest to run.

    input.azsnpvtpm.policy_single_socket in data.reference.single_socket
    # Meaning and Source:
    # This policy checks whether the VM is restricted to a single physical CPU socket. 
    # For multi-socket servers, restricting the VM to a single socket 
    # reduces the potential attack surface through cross-socket interconnect buses 
    # such as Infinity Fabric. The value is derived from the SINGLE_SOCKET bit of the GUEST_POLICY structure.

    # Possible Values and Recommended Settings:
    #   - 0: Allows operation on multiple sockets.
    #   - 1: Only allows operation on a single socket.
    #   - Recommended Value: 1. This allows you to follow the principle of least privilege,
    #     reduce complexity, and minimize attack surfaces.

    # Reference Link: https://www.amd.com/content/dam/amd/en/documents/epyc-technical-docs/specifications/56860.pdf
}
```