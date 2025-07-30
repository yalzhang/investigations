package policy

import rego.v1

# This policy validates multiple TEE platforms
# The policy is meant to capture the TCB requirements
# for confidential containers.

# This policy is used to generate an EAR Appraisal.
# Specifically it generates an AR4SI result.
# More informatino on AR4SI can be found at
# <https://datatracker.ietf.org/doc/draft-ietf-rats-ar4si/>

# For the `executables` trust claim, the value 33 stands for
# "Runtime memory includes executables, scripts, files, and/or
#  objects which are not recognized."
default executables := 33

# For the `hardware` trust claim, the value 97 stands for
# "A Verifier does not recognize an Attester's hardware or
#  firmware, but it should be recognized."
default hardware := 97

# For the `configuration` trust claim the value 36 stands for
# "Elements of the configuration relevant to security are
#  unavailable to the Verifier."
default configuration := 36


##### Azure vTPM SNP
executables := 3 if {
    input.azsnpvtpm.measurement in data.reference.measurement
    input.azsnpvtpm.tpm.pcr4 in data.reference.snp_pcr04
    input.azsnpvtpm.tpm.pcr7 in data.reference.snp_pcr07
    input.azsnpvtpm.tpm.pcr11 in data.reference.snp_pcr11
}

hardware := 2 if {
    # 检查报告的 TCB 以验证 ASP 固件
    input.azsnpvtpm.reported_tcb_bootloader in data.reference.tcb_bootloader
    input.azsnpvtpm.reported_tcb_microcode in data.reference.tcb_microcode
    input.azsnpvtpm.reported_tcb_snp in data.reference.tcb_snp
    input.azsnpvtpm.reported_tcb_tee in data.reference.tcb_tee
}

configuration := 2 if {
    input.azsnpvtpm.platform_smt_enabled in data.reference.smt_enabled
    input.azsnpvtpm.platform_tsme_enabled in data.reference.tsme_enabled
    input.azsnpvtpm.policy_abi_major in data.reference.abi_major
    input.azsnpvtpm.policy_abi_minor in data.reference.abi_minor
    input.azsnpvtpm.policy_single_socket in data.reference.single_socket
    input.azsnpvtpm.policy_smt_allowed in data.reference.smt_allowed
}

