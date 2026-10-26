# R123: isolate pinctrl initialization

Status: initramfs shell reached; confirmed by user photo.

R122 reached the initramfs shell with the exact r68 config rebuilt from the
NOP-checkpoint donor. R118 resets with pinctrl enabled. R123 is an experiment
identifier, NOT a newly compiled Image or a working SD release.

Use the exact R118 Image already in the R121 recovery runtime:
SHA256 dbcffeead9750aa41228269f2101c32c76cbde42d1bea554db1132ad30eac11d.
Keep DTB and initramfs unchanged. Append only:

    initcall_blacklist=sm8250_pinctrl_init

Local checks: R118 CONFIG_KALLSYMS=y, CONFIG_PINCTRL_MSM=y,
CONFIG_PINCTRL_SM8250=y. System.map contains sm8250_pinctrl_init at
ffff8000819f16ec. Source drivers/pinctrl/qcom/pinctrl-sm8250.c registers
the platform driver through arch_initcall(sm8250_pinctrl_init).
init/main.c checks the blacklist before calling the function.

Reference: https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html

Runner: scripts/test-r121-r123-pinctrl-blacklist.sh. It verifies the Image,
uses the existing loader's payload verification, reloads with the extra
parameter, and saves hashes/cmdline/boot ID to the microSD-backed first-stage
/var/log/tb371fc-r121/r123-control.txt before invoking the existing handoff.
No partition flash or Android data changes are needed.

Interpretation:
- Shell reached: pinctrl registration/probe or dependent-device activation
  becomes the leading suspect; not proof of a defect in pinctrl itself.
- Reset again: investigate earlier differences and confirm parameter handling;
  do not claim that this alone rules pinctrl out.
- MMC -517 is expected to remain with the provider deliberately absent.

User reported Linux console. SSH confirmed existing first-stage recovery:
4.19.157-perf-v56.6+, boot_id d3da3cc9-147b-4a78-9659-8d88fe6fe617,
panic=0, kexec_loaded=0. No bootloader transition or flash was required.
The runner verified all three payload hashes, loaded the original R118 with
the single added blacklist parameter, and reached calling kexec -e.
Host evidence: diagnostics/r121-r123-control-20261023.log.
Photo D:/image-23-10-26-11-10 (1).jpeg confirms Linux
6.12.30-tb371fc-r118-pinctrl+, the command-line blacklist, explicit
"blacklisting initcall sm8250_pinctrl_init", and the final ~ # prompt.
MMC still returns -517; USB is disabled. No full Arch/SD success established.
The exact same R118 Image reaches initramfs when registration is skipped.
This implicates pinctrl initialization and/or newly activated consumers;
it does not yet identify the precise operation causing reset.

Next prepared control R124 uses the same original R118 Image/initramfs and
original cmdline (no blacklist), but disables /soc/pinctrl@f100000 in DTB.
Artifact D:/TB371FC-builds/linux-6.12.30-tb371fc-r124-tlmm-disabled/board.dtb
SHA256 226936e5f6988ea01c4547ae2e9d96efc89fa71c1bec356ffca519f5afb95aad.
Canonical DTS diff adds only status="disabled"; restoring the original
absence of that property reproduces the baseline canonical DTS exactly.
Preparation initially stopped because baseline status was absent; script
now handles absence explicitly and the completed roundtrip audit passed.
Scripts: prepare-r124-tlmm-disabled.sh, test-r121-r124-tlmm-disabled.sh.
R124 handoff executed after the user returned to the first-stage console.
SSH confirmed 4.19.157-perf-v56.6+, panic=0 and boot ID
0bee9228-768f-4c74-a007-e143226289ff. Transferred candidate DTB into RAM,
verified all payload hashes, and reached calling kexec -e. No flash needed.
Host log: diagnostics/r121-r124-control-20261023.log.
Persistent record: /var/log/tb371fc-r121/r124-control.txt.
Photo D:/image-23-10-26-11-30 (1).jpeg confirms R124 reached ~ #.
sm8250_pinctrl_init returned 0 after 0 usecs; TLMM was disabled in DTB.
This supports successful driver registration without TLMM probe. MMC remains
-517 and USB disabled. Full Arch/SD operation has not been established.

## R125 prepared: disable GPIO75 hog only

The original TLMM node has sd-redriver-hog (GPIO75, output-high). Local 6.12
drivers/gpio/gpiolib-of.c: of_gpiochip_scan_gpios uses available child nodes,
so status="disabled" excludes this hog. R125 enables the original TLMM and
adds only status="disabled" on /soc/pinctrl@f100000/sd-redriver-hog.
The original R118 Image/initramfs/cmdline are retained, no blacklist.
Artifact D:/TB371FC-builds/linux-6.12.30-tb371fc-r125-no-gpio75-hog/board.dtb
SHA256 95c53bfe82d42c11110b2eb970167962a9ee0583e688071c594e1fa198719afe.
Canonical diff and property-removal roundtrip passed.
Scripts: prepare-r125-no-gpio75-hog.sh, test-r121-r125-no-gpio75-hog.sh.
R125 handoff executed 2026-10-23 from first-stage 4.19.157-perf-v56.6+,
boot ID ffa9def1-5e65-45c2-a8e8-ade4beb3d65a, panic=0.
DTB transferred into RAM; all three payload hashes confirmed; original
cmdline without blacklist. Execution reached calling kexec -e.
Host evidence: diagnostics/r121-r125-control-20261023.log.
Persistent evidence: /var/log/tb371fc-r121/r125-control.txt and boot-ID logs.
R125 reset confirmed: user saw the initial console again, and SSH confirmed
new boot ID 53184df6-1877-409b-8563-2b97b0f068c1 under 4.19. MicroSD logs
survived. Evidence: diagnostics/r125-post-reset-20261023.log.
GPIO75 hog alone does not explain the reset. R126 adds TLMM probe tracing
and selectable stop gates; see R126-TLMM-TRACE-20261023.md.
