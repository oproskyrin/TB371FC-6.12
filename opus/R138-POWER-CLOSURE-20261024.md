# R138: boot/power/PHY/DSI verified; loss of responsiveness at panel module stage

2026-10-24. D:/TB371FC-builds/r138-power-closure.

## Hardware result

RAM kexec from4.19 boot9cddffce-d31d-4f9b-85c2-1dae9be982da verified all3
hashes. NativeSSH bootbfea0a4c-9f14-4e4a-ba52-55a5fd25cf2e, unameR137 as expected
for DT-onlyR138. Three upstream status properties confirmedokay in liveDT.
Initial Arch/systemd failed units0. User reported black screen before manual
display modules. Native USB appeared after roughly130s, not the usual100s;
an early SSH timeout was not a boot failure.

Power stage0: actual regulator_summary now shows the3 LDOs beneath their
SMPS6a/SMPS8c/SMPS5a inputs, all resolved. DISPCC/ICC stages0; both I2C buses,
MDSS/DPU probe0. Both PHY ae94400/ae96400 and DSI ae94000/ae96000 probe0 and
driver symlinks explicitly verified. The previous vdds-517 blocker is fixed.
Only cpufreq remains deferred, ICC-path issue. DSI refgen uses a dummy regulator,
so real refgen management remains a limitation, not a verified native supply.
Backlight stage0; brightness128. No GUI launched.

Before panel stage, selected RAM logs were archived and downloaded:
diagnostics/r138-before-panel-20261024.tar.gz (458135bytes). Then panel module
stage began. All module hashes passed, but no stage-complete marker returned.
Original SSH timed out; newSSH and ping also timed out on repeated checks.
Windows still enumerated NCM Up andCOM4; this does NOT prove kernel responsiveness.
No reboot command was sent after loss of connectivity, and no automatic reboot
was confirmed. Current precise failure is loss of responsiveness during panel
module load/bind/native modeset path; NOT yet proven panic, reset or a specific
GPIO/DSI bug. Await screen/photo evidence before claiming cause.

Panel module load can apply default pinctrl GPIO33/54/77/78 BEFORE the panel
probe, request resetGPIO69 OUT_HIGH during probe, attach dualDSI and trigger
DRM fbcon/modeset. Split these boundaries in next diagnostic; do not assume
vendor command table or PHY values caused the hang without trace evidence.
All current evidence through pre-panel preserved locally; cannot collect later
kernel logs over unresponsiveSSH. Bootlog and stage logs diagnostics/r138-* and
diagnostics/r121-r138-boot-20261024.log. Android/SD not written.

User explicitly authorized software reboots to initial console on2026-10-24.
Sending Linux reboot is possible only while responsive; automatic return to
specific4.19 first stage is not yet verified. Do not claim it was done here.
If connectivity stays absent, physical restart is needed for next test.

## Offline preparation (historical, before the hardware run above)
Fixes R137 packaging omission found by actual PHY probe-517, not a panel-table
or framebuffer rendering issue. R137 currently stable via nativeSSH with both
KTZ backlights bound. Native PHY and panel output still NOT proven.

Exact R137 kernel Image and initrd/modules retained. Only three status properties
change disabled->okay: regulators-0/smps5, regulators-0/smps6, regulators-1/smps8.
These are required inputs of LDO14/LDO5/LDO9, according to actual provider
phandles and6.12 qcom-rpmh-regulator input-group table. All unrelated RPMh
regulators remain disabled. Voltages/constraints unchanged from original DT.
Candidate registers more hardware rails; this is a real power-stage test,
not merely cosmetic DT metadata. No live power change performed for R138.

Validation: SHA checks, complete recursive supply closure available, exact
Image/initrd comparisons and restoring3 status values roundtrips to identical
decoded R137 DT. New audit --require-closure explicitly fails original R137.
GPIO/USB/memory/SD/DSI/panel data unchanged. Kernel uname and banner remainR137
because Image/initrd are deliberately identical. Verify input nodes in live DT.

Image41b514a1487c5f2c314b63f458d9e62bb072b2ef94be4791bc4e7bec8c4e8450
DTB7a2c83e62b42b13a7642dcb6982dba45e87e415e1cdca6a226d82affd9809f0c
initrd8a74557366d0a8a47595bde7436c768e3fccc9f0e41e9068598bc52d216be853
Runner scripts/test-r121-r138-power-closure.sh pins these and requires4.19firststage.
No Android/UFS flash or SD write-enable. Need user return to initial4.19console,
not unvalidated6.12-to6.12 kexec. After boot: power, dispcc, ICC in separate gates,
then verify both PHY drivers and suppliers BEFORE backlight/panel stages. If a
PHY is still deferred, stop panel activation and collect exact probe errors.
