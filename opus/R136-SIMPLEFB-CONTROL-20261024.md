# R136: old working simplefb path tested on6.12; physical display still black

2026-10-24. Current kernel6.12.30-tb371fc-r134-panel+, R135 initrd,
boot1d4ea8c5-929e-4186-9c05-6144302b15f7. No Android/SD write-enable or flash.

## Old evidence actually reused

WORKING_BASELINE_V56.md records verified4.19 visible desktop and console.
diagnostics/display-v49-community-simplefb-build-20260813.md and
diagnostics/display-v48-community-parallel-sspp-result-20260813.md identify:
physical framebuffer0x9c000000, size0x2300000,2944x1840, pitch11776,
a8r8g8b8, continuous splash, retained clock/power rails and parallel SSPP
linewidth0x758. V49 itself was NOT the successful simplefb image: it failed
ioremap due to pfn_valid until no-map fixed in V50. V56 is the proven baseline.
Do not conflate software rendering or KMS completion with visible panel output.

## Controlled live test

Built exact6.12 simplefb.c plus same-tree fb_io_fops/cfb drawing helpers as one
external module against unchanged R134 config/Image. Only simplefb driver name
changed to tb371fc-simplefb-control to coexist with registered simpledrm driver.
Helpers are required because original config lacks FB IOMEM helpers; no
unresolved symbols/version bypass. Source/kernel unchanged, module SHA256
737e26174964c5c81ec2f94f30516023a0112ae2db9b791a316c0fd4285d560f.
Build script scripts/build-r136-simplefb-control.sh, patch/Kbuild alongside.

Live runner asserts exact boot ID, module SHA, absent DISPCC and absent chosen
framebuffer clock/domain/supply properties before swap. Disconnects fbcon,
unbinds simpledrm, overrides this one device to renamed simplefb, insmods,
validates binding/fb name, reconnects fbcon and writes visible test message.
Failure path restores simpledrm if new binding absent. It does not reset panel,
touch GPIO, set video timing or write clock/regulator settings. No GUI involved.

Probe0 at316.388s, simplefb mapped0x9c000000/0x2300000,2944x1840x32,
stride11776; fb0 name simple and active framebuffer console184x57.
Same boot ID, native SSH still active. User explicitly reports STILL BLACK.
The directly mapped framebuffer path alone is therefore insufficient on this
handoff; this does NOT prove the physical scanout still points at that memory,
or identify power/DSI/timing cause. Live state left simplefb-bound, no DRM card0.

Evidence diagnostics/r136-{simplefb-live,result}-20261024.log, selected archive
diagnostics/r136-evidence-20261024.tar.gz includes RAM R135/R136 logs/module.
SHA256e481597609775042a3112e267f34e92ce5e23ae16bcd64a50cbd6b0774979b38.
No persistent boot image changed by R136; R134/R135 payloads remain unchanged.

## Next development boundary

Need native dual-DSI/DSC panel, PHY lane contract and correctly retained power;
not another KDE launch. Stock Tianma commands/reset/PPS already verified R134.
PHY6.12 calls the v4.0 quirk PRE_V4_1, unlike newer V4_0; port board flag
without changing generic SoCs. Board clock-lane CFG0=0x20 needs exact audit.
6.12 wide-plane path uses parallel multirect on one SSPP (SMART_DMA gate), not
newer dynamic two-SSPP allocation; do not blindly transplant7.1 dpu_plane_split.
GPIO69 reset and display enable33/54/77/78 remain reserved; selective source-backed
DT changes and guarded power tests required. Do not unreserve all GPIOs.
