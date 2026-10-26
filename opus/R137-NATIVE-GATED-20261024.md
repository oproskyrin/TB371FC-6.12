# R137 native display candidate — BOOT VERIFIED, native PHY blocked on power closure

2026-10-24. Package D:/TB371FC-builds/r137-native-prereqs.
Current tablet now R137 bootf8239fae-e368-4b9d-af8a-963ae3a730ec,
native SSH works, physical display black. No Android flash or SD write-enable.

## Hardware test result and discovered packaging defect

First-stage4.19 boot7b7832f5-3b80-4158-9a95-b0a7c3d29672 verified hashes then RAM
kexec. Native SSH confirmed6.12.30-tb371fc-r137-native+, PID1/systemd,
failed units0, RPMh stage0. Power stage registers exactly the3 LDOs. DISPCC0,
ICC0, MDSS/DPU bound, I2C994000/a8c000 probe0. Backlight stage0: both actual
5-0011 and11-0011 chips bound/probe0; backlight class appears. GPIO12/13/60/61
selective release did not reset this boot. No panel module or GUI launched.

PHYs remain-517: Failed to get supply vdds. Restricting regulator registration
to the3 terminal LDOs mistakenly disabled their upstream bucks too. This is a
R137 packaging/validation gap, not evidence that the PHY analog patch failed.
Complete actual DT/source-derived closure:
LDO5 <- SMPS6a(vreg_s6a_0p95) <- vph_pwr;
LDO9 <- SMPS8c(vreg_s8c_1p4) <- vph_pwr;
LDO14 <- SMPS5a(vreg_s5a_1p9) <- vph_pwr.
Old power gate checked regulator names only, which did not prove usable input
supply resolution. Audit now walks input supplies and --require-closure rejects
R137 as expected. Do not start panel while either PHY lacks a driver.

Live overlays/OF_DYNAMIC unavailable, so no unsafe live DT/property patching.
R138 is a DT-only correction enabling exactly those3 buck nodes; same Image
and initrd. Roundtrip proves no other DT change; closure validation passes.
It is NOT BOOTED. See R138-POWER-CLOSURE-20261024.md.

Logs diagnostics/r137-{boot-preflight,first-ssh,power-stage,dispcc-stage,
icc-stage,backlight-stage,power-closure-failure}-20261024.log and
diagnostics/r121-r137-boot-20261024.log. Selected RAM archive
diagnostics/r137-evidence-20261024.tar.gz SHA256
4acdb66be4e765cce576b5514695ee475998106eb0c2346d2edf61fe8531b7ac.

## Source audit corrected an old assumption

Older7.1 experimental patch0013 claimed a pre-v4.1 TX table was needed. Actual
saved runtime devices in diagnostics/v46-stock-kernel-avdd-always-on-20260813/
05-after-kms/display-devices.txt identify both PHYs and PLLs as v4.1.
The actual V56.3 source /root/tb371fc-desktop-v56-3-kexec-src/techpack/display/
msm/dsi/dsi_phy_hw_v4_0.c selects TX{40,40,40,46,41} for version4.1 (lines160..163),
and uses its DT lane CFG0/1/2. Merely seeing function name v4_0 is not evidence
of physical v4.0 revision. Initial R137 compile reproduced the old hypothesis;
it was NEVER booted and has been superseded before packing.

Final board-only compatible selects V4_1 plus clock-lane CFG0=0x20 and the
V56-source DPHY overrides: VREG0=0x51, RESCODE top0x3d/bottom0x39, CAL_SEL0x01,
HSTX0xff. Generic SoC profiles unchanged. VCO bounds600MHz..5GHz, as generic4.1.
These are reference source values, NOT proof that the V56 visible-simplefb path
actually exercised native PHY initialization. Native electrical/scanout success
remains a hardware test. Legacy0013 and historical reports are preserved as
history; new6.12 patches0002+0003 supersede that assumption for this candidate.

## Kernel/build

Isolated source /root/tb371fc/linux-6.12-r137-native and output
/root/tb371fc/build-6.12-r137-native; original R134 Image/config unchanged.
Kernel6.12.30-tb371fc-r137-native+. QCOM_CLK_RPMH=m and REGULATOR_QCOM_RPMH=m.
Eleven rebuilt exact-vermagic modules incl bothUSB, clockRPMh, regulatorRPMh,
DISPCC, fourICC, panel andKTZ. No forced module versions/unresolved symbols.
Bootable Image linked, source and DSC/timing/order checks passed.

DPU: new board catalog duplicates exact6.12 SM8250 resources, changing only
max_linewidth4096->1880.6.12 splits linear2944 into1472+1472 via parallel
multirect on the same SMART_DMA SSPP, NOT newer dynamic two-SSPP allocation.
This is a candidate behavior, not proof of hardware source-split compatibility.

## Actual DT audit and gates

Based exactR131 DT, preserving boot memory, SD GPIO75, USB2 and RSC fix.
Both DSI/PHY nodes now enabled; Tianma panel compatible and board DPU/PHY select
new code. No panel/KTZ module autoload or GUI launch in initramfs. After Arch/SSH,
only RPMh clock module loads. Native nodes are ARMED, not hardware-isolated until
manual module phases: enabling nodes/pins can itself change probe behavior.

Saved4.19 sysfs proves KTZ physical controllers994000 and a8c000, NOT adapter
numbers2/4 or DTS label guesses. Actual R131 DT puts them under geniqup9c0000
andac0000. Pin phandles resolve to GPIO12/13 and60/61 respectively. I2C controllers
enabled400kHz, both address0x11, KTZ defaults128/2047.

Allowed TLMM pins exactly12,13,33,54,60,61,69,75,77,78. All other0..180 reserved.
Display pinctrl33/54/77/78 high belongs to panel consumer, not global hogs.
Reset69 remains active-low; saved reset sequence retained. Other I2C/keyboard/
WLAN pins NOT released. DP disabled because its PHY intentionally unavailable.

Missing power driver was real: current live regulator_summary only dummy and
fixed rails. DT display supplies resolve to PM8150 RPMh LDO5(880000uV),
LDO9(1200000uV), LDO14(1800000..1880000uV). These are DT constraints, not measured
stock voltages. To avoid registration applying unrelated regulator constraints,
all OTHER regulator children are disabled in this candidate. Loading power
module must be attended and checked before native panel. Original SD remainsRO.

Manual stages after SSH:
`sh /run/r134/config/r137-native-stage.sh power` then dispcc, icc, backlight,
panel one at a time. Script requires prior phase markers and kernel version,
checks all11 module hashes before every phase, captures dmesg/clocks/regulators/
deferred/identity to/run/r137. ICC may trigger other deferred probes; stage name
does not mean a single atomic hardware action. Panel phase may trigger native
DRM fbcon/modeset automatically. No promise that SSH survives a hardware hang.

## Payload identity

Image41b514a1487c5f2c314b63f458d9e62bb072b2ef94be4791bc4e7bec8c4e8450
DTBe13d514b00ff8fa12ed975685b9b57d1eb605f2e0063d8de70a17ef4387f02a5
initrd8a74557366d0a8a47595bde7436c768e3fccc9f0e41e9068598bc52d216be853

r137-native-gated-payload.tar.gz contains those three files. Runner
scripts/test-r121-r137-native-gated.sh pins all3 hashes and first-stage4.19 uname.
R129 storage loader byte-identical, only publicSSHkey embedded, GPIO whitelist,
all module ABI/hash checks and source/command/PPS/timing/order validators pass.
Log diagnostics/r137-offline-validation-20261024.log. Original R130/R131/R134
checkpoints remain unchanged. No claim of visible console/KDE on R137 yet.
