# Next persistent-development hardware test

## V55 live result (2026-08-14)

V55 is the preserved stable laboratory. It has a readable inherited-simplefb
console, the 6-GiB Arch loop root mounted read-write and key-only OpenSSH over
the guarded ACM localhost bridge at `127.0.0.1:22223`. The live kernel is
`4.19.157-perf+`. No Android/UFS filesystem is mounted, no KMS opt-in marker
exists, and no graphical, NetworkManager or BlueZ daemon is running. The
earlier V51--V54 notes below are historical.

## Current test state (2026-08-14)

V56.2 has passed its attended desktop test and is now the successful
vendor-kernel hardware-reference baseline. Display, persistent Arch, KDE,
Wi-Fi/SSH, calibrated touch and the Lenovo keyboard/touchpad are working.
Adreno 650 Turnip Vulkan was also proven for isolated applications; whole
Plasma acceleration remains disabled after an unstable live experiment.

Linux 7.x development is resumed. V56.2 is both the desktop comparison point
and the primary Linux rollback target after an unsuccessful mainline test.
V55 remains the secondary immutable rescue fallback. Neither artifact may be
overwritten by a mainline experiment.

The next attended Linux 7.1.8 gate is the existing r4 Arch/microSD/SSH payload
with native display and GPU deliberately disabled. After it proves boot,
persistent root and remote control, move to a new guarded DRM_MSM payload that
uses the V56.2 firmware and input findings.

Those findings are now represented in the r7 source: upstream DRM_MSM/A650 was
already staged, and the exact Lenovo keyboard-cover I2C/GPIO sequence has been
added, fully rebuilt, packaged and offline verified. The existing r4 payload
is intentionally unchanged; it remains the smaller first-boot gate. See
[MAINLINE_V56_MIGRATION.md](MAINLINE_V56_MIGRATION.md).

The r4 payload is
`D:\TB371FC-builds\u-boot-linux-7.1.8-r4-arch-microsd-payloads\tb371fc-linux-7.1.8-arch-test-arch-development-u-boot.img`,
34,086,912 bytes, SHA-256
`6dd8f7542564ecdd60b4c28d912c2a097d38ea0a3121feb813bc86ba81d76d5c`.
It is offline verified and not booted. No unattended reboot or flash is part
of this gate.

After stage0 and r4 Arch/microSD/SSH pass, the preferred attended display
payload is the gated r6 profile:

```text
D:\TB371FC-builds\u-boot-linux-7.1.8-r6-display-gated-payload\tb371fc-linux-7.1.8-display-gated-u-boot.img
size 18,898,944 bytes
SHA-256 1bb58f5dbcd393dacfa63ed892f62b40ec9f63a889b497286c4f9cea7cf5aa93
hardware status: OFFLINE VERIFIED; NOT BOOTED
```

This image boots with automatic DRM fbdev emulation disabled. Require the USB
shell and `/dev/dri/card0`, preserve `/run/tb371fc-display-probe.txt`, then run
`run-mainline-display-test 120 checker 120`. Use a second USB shell and
`status-mainline-display-test` while observing the panel. The automatic r6
display image remains a fallback, not the first test. The r5 display-pinctrl
payload is superseded; r4 Arch is not superseded because it deliberately keeps
display and GPU disabled.

The host-side controller is `scripts/control-mainline-gated-display.ps1`.
`ValidateOnly` checks its pinned payload and serial dependencies without a
device query. After RAM boot, `WaitAndSnapshot` captures probe state,
`StartTest -KmsApproved` submits the explicit observed modeset, and `Status`
collects its program log plus current DRM/dmesg state.

## Historical tablet state (2026-08-11, stock Android restored)

Exact stock `recovery_b` and signed stock `vbmeta_b` were restored after the
v17/v13 display tests. Android 14 / ZUI 16.0.474 completed boot on slot B with
authorized ADB, an unlocked bootloader and a 100% AC-powered battery. Magisk
root is available after the user grants Shell access. No Linux test image is
currently installed in `recovery_b`.

V8 reached the schema-2 Arch filesystem and proved the kernel/rootfs/network
contract, but PID 1 stopped before `switch_root`: the early listener PID file
named its parent shell instead of the actual `nc` process, so the chrooted
listener could not reuse port 2323. A manually started chroot runtime proved
the Arch root and accepted the pinned SSH public key.

The internal panel was initially left on the Lenovo/Android bootloader image.
Live KMS diagnostics proved DSI-1 is connected with 2944x1840 modes at
120/60/30 Hz but disabled until userspace performs a modeset. The static ARM64
KMS smoke test enabled DSI and replaced the splash with a grey field and green
stripe. Evidence is in
`diagnostics/arch-loader-v8-live-kms-20260811.txt`.

## Mandatory rollback order

1. Use the guarded helper to enter fastboot while the user is present.
2. Restore exact stock `recovery_b` SHA-256
   `94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668`.
3. Restore signed stock `vbmeta_b` SHA-256
   `58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05`.
4. Boot Android and require `sys.boot_completed=1`, slot B and unlocked state.
5. Remove v8 from the launch allowlist. Add v9 only for a separately
   authorized test after its hash is pinned.

## Successful v13 artifacts

- 4.19.325 Image SHA-256:
  `d7919c2f5a3706f220dea926eaf7c1d3d41c9f774cb4c2bef9523fb6571a5a77`;
- initramfs:
  `D:\TB371FC-builds\arch-development-loader-v13\tb371fc-arch-development-loader-v13.cpio.gz`,
  SHA-256 `41b742e836f344b1362837459468aca55b6ae5871b2bfe11404d7241e05aafa5`;
- 100 MiB recovery:
  `D:\TB371FC-builds\arch-development-loader-v13\tb371fc-arch-development-loader-v13-recovery.img`,
  SHA-256 `ff6136aa61b371b610a4e568d3438e04dac89692e1b15145822d3b9c8860b370`;
- installed schema-2 Arch image SHA-256:
  `874aefbc65f176c94ad4e7dc7636993fd6d7f8b0bed8b77fee17da7d6609594e`.

V13 records the real early `nc` PID, uses independent port 2324 during the
chroot transition, starts a fresh port-2323 listener after `switch_root`, and
creates the verified framebuffer device node `29:0`. It also embeds the exact
static ARM64 KMS program proven live on the tablet and creates DRM card node
`226:0` only after matching sysfs. Unlike v10-v12, it creates a movable
tmpfs-backed `/dev` when the Lenovo kernel fails to mount devtmpfs. Its
initramfs passed
ARM64 shell checks and a real qemu-user chroot/TCP test. Its recovery passed
AVB NONE verification and byte-identical Image, initramfs, Lenovo DTB and
recovery-DTBO checks.

## Verified v13 acceptance gates

1. **Passed:** PID 1 completed `switch_root`; `/` is `/dev/loop0` without a
   manual chroot.
2. **Passed:** port 2324 covered the transition, closed afterward, and port
   2323 works from the Arch root.
3. **Passed:** key-only SSH on 2222 accepted the pinned key.
4. **Passed:** the DRM/KMS launcher enabled DSI-1 and replaced the Lenovo
   splash with the grey/green Linux test framebuffer.
5. No WLAN, Bluetooth, camera or dock activation during this handoff test.
6. Logs are synchronized before guarded return to fastboot and exact stock
   rollback.

Persistent success marker:
`/var/lib/tb371fc/v13-switch-root-success`, SHA-256
`b985ecfa0d54f39a5fe8179286a000c9c6fcba6b1a423655bc625f76b12280ed`.
Full evidence: `diagnostics/arch-loader-v13-success-20260811.txt`.

## V14 DSI lifecycle result and prepared v15 PPS test

Live v13 testing proved that Weston and `modetest` render complete
2944x1840 buffers, while the internal panel initially updates only the top
approximately 20 rows. That height exactly matches the Tianma NT36532 DSC
`slice-height = 20` from the stock panel device tree. Both DSI debugfs
controllers simultaneously reported `VIDEO_ENGINE = OFF` and zero byte,
pixel and escape clocks.

The exact cause was then found in the published downstream source at commit
`9d8abebf4ac4d45cf4cc11b5b6bc5e4483d10fd1`:
`dsi_bridge_pre_enable`, `dsi_bridge_enable`,
`dsi_bridge_disable`, and `dsi_bridge_post_disable` each contained an
unconditional warning followed by `return`. Consequently Linux never
executes the Qualcomm DSI panel lifecycle and only reuses the bootloader
continuous-splash path. A non-atomic AB24 modeset eventually affected the
whole panel but produced a corrupted repeating pattern, consistent with a
new framebuffer entering that stale path without a clean DSC/PPS setup.

`vendor-kernel/patches/0003-display-enable-dsi-bridge-lifecycle.patch`
removes only those four early returns. V14 was written and booted successfully:

- kernel: `D:\TB371FC-builds\arch-development-loader-v14-dsi-lifecycle\Image-v14-dsi-lifecycle`,
  SHA-256 `16a4c0737d3dc1e8161f8a591124c53d6c8d4d7498352750a53d27abd65bcc69`;
- recovery: `D:\TB371FC-builds\arch-development-loader-v14-dsi-lifecycle\tb371fc-arch-development-loader-v14-dsi-lifecycle-recovery.img`,
  SHA-256 `aaf9b27ab6cbca1a2a0face72a2f84c79f5d3dfddd375a07e5b68769e67856ad`.

Both DSI control and video engines are now ON at 120 Hz, with 141250000 Hz
byte clocks, 188333333 Hz pixel clocks and 19200000 Hz escape clocks on both
controllers. This proves the restored bridge lifecycle executes. It did not
fix full-frame scanout: atomic Weston, legacy Weston and the standalone KMS
checkerboard all leave the bootloader image below a changing top strip about
20 rows high, exactly one DSC slice row.

Review found that the continuous-splash branch of `dsi_display_enable()`
returns before the normal `dsi_panel_update_pps()` call. V15 adds
`vendor-kernel/patches/0004-display-refresh-dsc-pps-after-cont-splash.patch`,
sends the calculated PPS before splash cleanup, and logs the PPS plus the
dimensions programmed into both DSC encoders.

Verified v15 artifacts:

- kernel: `D:\TB371FC-builds\arch-development-loader-v15-cont-splash-pps\Image-v15-cont-splash-pps`,
  SHA-256 `15bb920bad513ae90569e4f7ea4b5b03a29cab6a763708848466c4c2bdbd35f3`;
- recovery: `D:\TB371FC-builds\arch-development-loader-v15-cont-splash-pps\tb371fc-arch-development-loader-v15-cont-splash-pps-recovery.img`,
  SHA-256 `782f8bbaee289865a25302808eb4603d2d19fd21d74b40cffd7b4740970c0245`.

Independent unpacking matched the v15 kernel, v13 initramfs, stock DTB and
stock recovery-DTBO byte-for-byte. AVBtool verified the embedded NONE vbmeta
and recovery hash. V15 was written to `recovery_b` and booted successfully.
USB NCM, SSH, Arch switch-root, Weston and the 2944x1840 framebuffer remained
operational.

V15 proved that the Linux PPS is transmitted and both DSC encoders are
programmed consistently for a 2944x1840 picture, 736x20 slices, 8 bpc and
8 bpp. Both DSI controllers have their control and video engines ON. CTL0
shows both interfaces active (`0x6`), both DSC blocks active (`0x3`) and
DSI0 as master. The panel nevertheless remains gray/corrupted with only the
top strip changing. Both interfaces continuously accumulate underruns even
with MDP fixed at 460 MHz and the maximum debug bus vote. The 6.12 community
DTS does not provide a missing fix: its MDP 460 MHz setting and PHY lane tail
`20 00 8a 8a` already match the running vendor DT.

## Tested v16 DSI controller soft-reset

The remaining continuous-splash difference is in `dsi_display_prepare()`:
the normal path resets the DSI controller state machines after controller
initialization, host enable and link-clock enable, while the splash path
skips that reset and inherits the bootloader FIFO state. Patch
`vendor-kernel/patches/0005-display-soft-reset-dsi-during-cont-splash.patch`
performs that controller-only reset for both paths. It does not cycle panel
regulators, toggle the panel reset GPIO or resend the panel power-on sequence.
The v15 DSC PPS update remains enabled.

Independently verified and tested v16 artifacts:

- kernel: `D:\TB371FC-builds\arch-development-loader-v16-dsi-soft-reset\Image-v16-dsi-soft-reset`,
  SHA-256 `c1cf3b53ccf471061c7dc72f26c5b6165a9dcf75a815920466f9f4be878bbf2a`;
- recovery: `D:\TB371FC-builds\arch-development-loader-v16-dsi-soft-reset\tb371fc-arch-development-loader-v16-dsi-soft-reset-recovery.img`,
  SHA-256 `d3df3b95f6d12ef2f9230da30515588ef86e17d9af7d7d1faffd4338d84b3dcf`.

Independent unpacking matched the kernel, v13 initramfs, stock DTB and stock
recovery-DTBO byte-for-byte. The new kernel logged the expected
`continuous-splash controller soft reset` marker. V16 booted Arch, USB NCM,
SSH, Weston and foot successfully, but the panel remained gray/dark with a
green or corrupted top strip. The soft reset therefore did not fix the
physical scanout. A live 60 Hz transition also failed its atomic commit and
was restored to 120 Hz; it is not a display fix.

## Prepared v17 PPS-before-video test

The normal non-splash enable path transmits the DSC PPS before enabling the
DSI video engines. V15/v16 enabled continuous-splash video first and sent the
PPS afterwards. Patch
`vendor-kernel/patches/0006-display-send-cont-splash-pps-before-video.patch`
makes the splash handoff follow the normal order: controller soft reset, DSC
PPS, then both video engines. It does not cycle panel power or reset GPIOs.

Prepared and independently verified, not written:

- kernel: `D:\TB371FC-builds\arch-development-loader-v17-pps-before-video\Image-v17-pps-before-video`,
  SHA-256 `768b1afdc851e3a9875725626430a5407c6fab5519eb0228b346aecb0241e48a`;
- recovery: `D:\TB371FC-builds\arch-development-loader-v17-pps-before-video\tb371fc-arch-development-loader-v17-pps-before-video-recovery.img`,
  SHA-256 `561ad47f94960c8a65e2347a624d584ad13f57a3bcc1e2b3de897c7d421c526d`.

Independent unpacking matched the v17 kernel, v13 initramfs, stock DTB and
stock recovery-DTBO byte-for-byte. The expected engine-enable error marker is
present and AVBtool verified the algorithm-NONE recovery hash. Do not write
or reboot into v17 without a fresh attended authorization.

## Prepared v18 safe dual-DSI trace

The active stock Android device tree was reconstructed from base DTB index 0
and DTBO index 2. It confirms that the Tianma panel is a 2944x1840 logical
display composed of two 1472x1840 DSI tiles. Its required topology is two
layer mixers, two DSC encoders and two interfaces (`<2 2 2>`), with command
broadcast enabled. DSC 1.1 uses 736x20 slices at 8 bpc / 8 bpp. Android
advertises 30, 60, 120 and 144 Hz; the current Linux mode list lacks 144 Hz.

V13 and the later lifecycle tests already parse `<2 2 2>` correctly. The
decisive runtime discrepancy is that the second physical interface recorded
no VSYNC after KMS while both interfaces accumulated underruns. V18 therefore
returns to the v13 display behavior and does not include patches 0003 through
0006. It adds only bounded diagnostics for panel broadcast parsing, horizontal
tile/physical-encoder creation, affected-display selection, split roles,
kickoff state and the 2-LM/2-DSC/2-interface programming path.

Prepared and independently verified, not written:

- kernel: `D:\TB371FC-builds\arch-development-loader-v18-dual-dsi-trace\Image-v18-dual-dsi-trace`,
  SHA-256 `41545ac5a7cb16e00c3a89586a014bbb487f29fb0e21b0e49573ebbfae3ad407`;
- recovery: `D:\TB371FC-builds\arch-development-loader-v18-dual-dsi-trace\tb371fc-arch-development-loader-v18-dual-dsi-trace-recovery.img`,
  SHA-256 `337ed5b4bea68c957b01cf4ba95a803813df43f69591ee2d6dc79ebb67f108ce`.

Independent unpacking matched the v18 kernel, v13 initramfs, stock DTB and
stock recovery-DTBO byte-for-byte. AVBtool verified the NONE vbmeta and
recovery hash. The guarded launcher allowlist contains the exact v18 hash.
Writing `recovery_b`/`vbmeta_b` and rebooting still require a fresh explicit
authorization; preparing the image did not change the tablet.

## V18 result and v19 direction

V18 booted successfully and preserved Arch, USB NCM and key-only SSH. The
captured trace proved that both horizontal tiles and physical encoders are
created correctly and every full-frame commit has `affected_displays=0x3`.
Nevertheless INTF1 reached 32 VSYNC / 17 underruns while INTF2 remained at
0 VSYNC / 17 underruns. Both DSI software states showed their video engine off
and all byte, pixel and escape clocks at zero. The photographed result remained
dark/gray with backlight and a corrupted green top strip.

The missing v18 `DSC 2-2-2` marker exposed the next concrete bug. The kickoff
path updates current/previous ROI before DSC setup, excludes video continuous
splash from that setup, and then treats later identical-ROI commits as already
configured. Patch
`vendor-kernel/patches/0008-display-program-dsc-on-video-cont-splash.patch`
allows the existing 2/2/2 hardware setup on that first commit. It retains the
v13 bridge early returns and does not touch panel power, DSI lifecycle, reset
or PPS transmission.

Evidence archive:
`D:\TB371FC-diagnostics\v18-20260812\tb371fc-v18-evidence.tar.gz`, SHA-256
`38129e72d74ef06e92f3a54b00f405245266eff069eacbfdd400acc69cef9c72`.
Exact stock recovery and vbmeta were restored; Android completed boot on slot
B before preparation of v19 began.

V19 is now built and independently verified, but has not been written:

- kernel: `D:\TB371FC-builds\arch-development-loader-v19-video-splash-dsc\Image-v19-video-splash-dsc`,
  SHA-256 `83da51fba2393e1e621d20f0b39a23b0aa0ff0c1905c8fad6efa7f0f31b32384`;
- recovery: `D:\TB371FC-builds\arch-development-loader-v19-video-splash-dsc\tb371fc-arch-development-loader-v19-video-splash-dsc-recovery.img`,
  SHA-256 `baad93ea48260608a73874d16e4564e04719b9232ee1a6f1912612ab4442a0f5`.

Independent unpacking matched the v19 kernel, v13 initramfs, stock DTB and
stock recovery-DTBO byte-for-byte. AVB algorithm NONE and the exact recovery
hash verified successfully. The guarded allowlist contains this exact hash.
A new attended write/reboot requires fresh explicit authorization.

## V19 result and active v20 test

V19 booted and proved that patch 0008 reaches the required 2-LM/2-DSC/
2-interface setup on the first continuous-splash commit. It did not start the
DSI video engines, so the panel still showed the gray/dark field and corrupted
top strip. Its evidence archive is
`D:\TB371FC-diagnostics\v19-20260812\tb371fc-v19-evidence.tar.gz`, SHA-256
`48e52844d7f1a78f2b6523d2cdfbf6a0addf04819cb8f56bee6e8ef8d305d811`.

V20 combines patch 0008 with the normal DSI bridge lifecycle from patch 0003
and excludes the failed reset/PPS patches 0004-0006. It was built, unpacked,
verified and booted directly from Linux through fastboot without entering
Android. Both DSI controllers now report their control and video engines on,
with matching 141.25 MHz byte, 188.333333 MHz pixel and 19.2 MHz escape clocks.
The DSC 2/2/2 trace also executes with both displays affected.

A live 2944x1840@30 XR24 KMS framebuffer was accepted and is currently held
active for visual inspection. Its mode commit added only bounded underruns;
the counters then remained stable. INTF2's software VSYNC counter still reads
zero, so the physical panel result must be confirmed before calling the
display fixed. Do not restore or launch another image until the held v20 frame
has been observed or its evidence has been copied.

V20 recovery SHA-256:
`755e2b27a943bfbad2f8a4556cc818882151950e6549f518c2563ac76fd46fa3`.
Evidence archive SHA-256:
`770df1e85fa49dd0721a0e1437e20a2f9727b82559909a0989673825924c6b6c`.

Hardware MISR sampling further proved stable, distinct SDE output on INTF1
and INTF2 (`0x79a865d2` and `0x7c2b4fef`) plus non-zero data at both DSI
controllers. If the held checkerboard is still not physically visible, the
remaining boundary is panel-side DSC state inherited from the bootloader.

V21 is prepared for that exact branch. With the opt-in command-line flag
`tb371fc.cold_panel=1`, patch 0009 bypasses continuous-splash resource adoption
before KMS initialization. The first ordinary modeset must then execute the
vendor driver's complete DSI host, panel reset/init, Tianma on-command and PPS
sequence. The behavior is isolated to the flagged image; normal kernels are
unchanged.

- v21 kernel SHA-256:
  `0e926219ea5cb243b1db0dcb2fc564bfd2176eff9d75f85dab9f83792358c639`;
- v21 recovery SHA-256:
  `492397eabc01f0102117ed4be0041925bf9e6f5b6a38f5a8522e53ef8883b999`.

The image was independently unpacked and verified. It is allowlisted but must
not replace the currently held v20 frame before that frame is physically
observed, because doing so would discard the strongest visual A/B checkpoint.

## V21–V23 cold-cycle results

V21 tested the opt-in early continuous-splash bypass. It did not provide a
safe cold start: the bootloader display state continued reading stale splash
mappings, producing SMMU faults, while the DSI PLL path reported busy and lock
failures (`-16` and `-110`). This branch is retained only as a negative
experiment. Evidence:
`D:\TB371FC-diagnostics\v21-20260812\tb371fc-v21-evidence.tar.gz`, SHA-256
`764987d48d61b4baf59abc44178cd10be593b198e7c2ae31e86e5362c8958afc`.

V22 moved the disable/re-enable sequence into userspace but incorrectly used
it as the first KMS frame. The downstream Qualcomm driver reported
`DMS not supported on first frame`; the cycle therefore ran before a valid
handoff and left both DSI video engines off. Evidence:
`D:\TB371FC-diagnostics\v22-20260812\tb371fc-v22-evidence.tar.gz`, SHA-256
`04104cafec6919989a78013785314a185f038aeea18c3e742f89cea2004d2f2f`.

V23 keeps the proven v20 kernel and fixes only that sequencing race. The init
script performs a normal 2944x1840@120 commit, waits until both DSI controllers
report `VIDEO_ENGINE=ON`, then executes a clean KMS disable and full re-enable.
The complete automatic sequence succeeded. Both DSI links remain on at
141.25 MHz byte, 188.333333 MHz pixel and 19.2 MHz escape clocks. Final MISR
values are non-zero and distinct on both SDE interfaces and both DSI links.

The v23 120 Hz checkerboard is intentionally held for 24 hours so it can be
physically inspected without another reboot. Do not restore Android or kill
the KMS holder before that observation. A full-screen stable checkerboard will
close the low-level panel handoff checkpoint; gray/corrupt output would narrow
the remaining fault to panel-side DSC/PPS decoding or dual-link synchronization.

- v23 recovery SHA-256:
  `dd1636136a88e73b725ebafa79b870017c702d4425b7f4c6a6290a4f954cde72`;
- v23 evidence:
  `D:\TB371FC-diagnostics\v23-20260812\tb371fc-v23-evidence.tar.gz`;
- evidence SHA-256:
  `01e09a38e6fa3aab4d5447f7e43293695511d77575146709ec859281ae241c98`.

## Prepared v24 PPS trace image

V24 has been built and independently verified but is deliberately not flashed
while v23 remains available for physical inspection. It uses the clean v20
kernel patch set plus diagnostic-only patch `0010`, which records the exact
128-byte DSC PPS and proves whether that packet is broadcast through both DSI
controllers during the v23-style full re-enable cycle. Failed patches
`0004`–`0006` and the v21 cold-start patch `0009` are excluded.

- kernel SHA-256:
  `4d801e8cc20151557070e710f172a8354ab17cb02d030760f24124dc6121db70`;
- recovery SHA-256:
  `ba9f185b03d1421a9a06917d83cd3236f90250e9eeaf82b23dd052bbadd8a12f`;
- build record: `diagnostics/arch-v24-pps-trace-build-20260812.md`.

Use v24 only if the physically observed v23 checkerboard is still gray,
corrupt or dark. A correct v23 checkerboard makes the extra boot unnecessary.

## Prepared v25 dual-KTZ8866 image

The v24 live session proved that the panel's two external KTZ8866 controllers
lost their global LED-enable bit during the full Linux KMS transition. A
reversible runtime module changed only `BL_EN` from `0x3f` to `0x7f` on buses 2
and 4 and the physical screen immediately lit.

V25 incorporates this as a synchronized backlight driver and reapplies the
requested level after DSI post-enable. Verified recovery:

`D:\TB371FC-builds\arch-development-loader-v25-dual-ktz8866\tb371fc-arch-development-loader-v25-dual-ktz8866-recovery.img`

SHA-256:
`a4dcdd7ada974f751164e3105e4cd918ccbcb188cac3aa77aac18bbcde3abe9c`.

V25 has been built and independently unpacked, but is not flashed yet. On the
next authorized boot verify, in order: automatic backlight after the full KMS
cycle, visible framebuffer content, brightness changes on both halves, blank
and unblank, and clean DSI/KTZ logs. Keep the existing stock recovery/vbmeta
backups and restoration guard unchanged.
# Mainline DSC long-write v3 hardware test

The current offline-verified candidate is
`D:\TB371FC-builds\mainline-7.1.7-native-display-longwrite-v3`. Its generated
DSC PPS matches all 128 bytes captured from Lenovo's downstream kernel. It
also matches the stock DSI packet types: 86 vendor commands use LP DCS
long-write (`0x39`), while sleep-out/display-on remain short packets with
120/100 ms waits. This corrects the last known wire-level mismatch in v2.

The guarded bridge is
`D:\TB371FC-builds\arch-development-loader-v30-longwrite-kexec-bridge`.
It accepts only the v3 Image hash. The diagnostic gadget exposes ACM and NCM
together, so a serial fallback is available while NCM remains at
`169.254.77.2:2323`.

The tablet is currently running v27 from `recovery_b`, identified by its exact
UTS timestamp (`#1 Wed Aug 12 11:33:09 +05 2026`). It has Arch on `/dev/loop0`,
USB NCM on port 2323 and a 120 Hz KMS holder, but no `CONFIG_KEXEC`. Therefore
the next transition requires one guarded reboot to fastboot, temporary v30
`recovery_b` plus test `vbmeta_b`, and recovery boot. Do not execute that
transition without fresh explicit authorization.

Run `scripts/preflight-v30-from-linux.ps1` immediately before an authorized
transition. It requires the exact running v27 UTS string, Arch loop root,
connected/enabled DSI, USB power, the guarded bootloader-return helper/module,
absence of kexec in v27, and all v30/v3/rollback artifact hashes. It performs
no reboot or device write.

After the explicitly approved boot, collect evidence with:

```powershell
.\scripts\collect-mainline-display-result.ps1 -InterfaceIndex 46
```

This records the prepared report, DRM debugfs and complete dmesg without
mounting or changing an Android partition.
