# Native display port

## Current native-display candidate

The next candidate is `mainline-7.1.7-native-display-phycfg-v4`. It retains
the verified long-write v3 panel sequence, dual-link DSC PPS and stock
2944x1840@120 geometry, and additionally reproduces Lenovo's DSI PHY v4.0
electrical setup. Both PHYs use the v4.0 TX_DCTRL table and clock-lane
`CFG0=0x20`; the display-test DTB also drives GPIO33 high with the already
identified GPIO54/77/78 display enables. It is built and verified offline but
has not been written to or booted on the tablet.

The stock TB371FC display is a 2944x1840 LCD driven as two synchronized
1472x1840 MIPI DSI links. Lenovo ships BOE and Tianma variants of the Novatek
NT36532 panel controller. The vendor device tree describes:

- four D-PHY lanes on each DSI host;
- reset GPIO 69 and TE GPIO 66;
- physical size 274x171 mm;
- DSC 1.1, 8 bits per component, 8 bits per pixel, block prediction enabled;
- two 736x20 DSC slices per DSI link, transported one slice per packet;
- 30, 60, 120 and 144 Hz refresh rates;
- horizontal timing per link: 1472 active, 201 front porch, 12 sync, 60 back porch;
- vertical timing: 1840 active, 26 front porch, 2 sync, 182 back porch at 120 Hz;
- two KTZ8866 backlight/bias controllers at I2C address 0x11. Android binds
  `ktz8866a` and `ktz8866b` simultaneously, with shared HWEN GPIO 54 and bias
  enable GPIOs 77/78.

`mainline-port/patches/0001-drm-panel-nt36523-add-lenovo-tb371fc-nt36532.patch`
extends the existing upstream Novatek dual-DSI driver with both exact vendor
command tables, DSC and the four advertised modes. The driver and its KTZ8866
dependency compile successfully against stable Linux 7.1.8. The 7.1.8 panel
module is 231,464 bytes with SHA-256
`d3ec7b018227abba591a938d4e3d339c1799e674570e47c1f434ea1a6ecff2f1`;
`ktz8866.ko` is 57,296 bytes with SHA-256
`3ca0e7b65962c795f375f00fa64c64eaed40def7b52a6eed7b4fc4aac03941a2`.

The DSI graph is present in the TB371FC DTS but remains disabled. This is
deliberate: the fitted BOE/Tianma variant is not exposed by Android's
unprivileged sysfs, and selecting the wrong command table is not an acceptable
guess. The first simple-framebuffer diagnostic boot will identify the panel
from the live DT or a controlled DCS read before native reset/power sequencing
is enabled.

The remaining display work is:

1. identify the fitted panel variant and verify DCS ID registers;
2. model the two KTZ8866 chips as one synchronized logical backlight while
   respecting the shared enable/bias GPIOs;
3. verify the native 120 Hz mode first, then 60/30 Hz porch switching and
   finally the higher 144 Hz link clock;
4. validate suspend/resume, brightness, DSC errors, TE/ESD handling and the
   BOE/Tianma split independently.

## Downstream live result — 2026-08-12

The Tianma panel now reaches native dual-DSI 2944x1840@120 under the downstream
4.19 test kernel. The post-KMS dark screen was isolated to the two external
KTZ8866 controllers, not to DSI or DSC: both had maximum brightness but
`BL_EN=0x3f`, with the global LED-enable bit clear. Setting only bit 6 on both
controllers (`0x3f -> 0x7f`) immediately lit the physical screen.

V25 adds synchronized KTZ8866 control and reconnects
`DSI_BACKLIGHT_EXTERNAL` to a real backlight implementation. See
`diagnostics/arch-v25-dual-ktz8866-build-20260812.md`. Native image correctness
still needs the next physical v25 boot; brightness range, blank/unblank and
suspend/resume remain explicit test items.
# Current diagnostic boundary (v26)

The v24 runtime tests proved that both external KTZ8866 devices need BL_EN
bit 6 set; v25 implements that synchronized backlight control in the kernel.
With the backlight lit, solid-color framebuffers at 2944x1840 and both 60/120
Hz remain invisible. The CRTC split, pitch, maximum MDP clock and maximum bus
vote were verified, so this is not a simple framebuffer offset or bandwidth
failure.

V26 adds a reversible hardware test-pattern control on both Qualcomm DSI
controllers. Its result will isolate the remaining fault to either the
SDE/DSC input path or the DSI PHY/dual-link/NT36532 side.
# V27 DSC state-corruption fix

Runtime tracing on the Lenovo 4.19 bridge kernel proved that the downstream
dual-DSI enable path permanently multiplied `dsc.pic_width` by two on every
normal KMS enable. The first cycle generated the expected 2944-wide PPS, but
later cycles generated 5888 and 11776-wide PPS packets. V27 makes the
conversion temporary and restores the per-link width of 1472 immediately
after PPS serialization. Initial boot and a controlled re-enable both now
produce `2944x1840` PPS followed by `restored_per_link_pic_width=1472 rc=0`.

## V27 live pixel-path boundary

A full-screen color animation generated distinct hardware MISR values on both
SDE interfaces and both DSI transmitters while the glass remained dark/gray.
This proves that framebuffer positioning and missing data on the second link
are not the active fault. A dual-DSI TPG test was invalid because the hardware
generator is uncompressed while NT36532 expects DSC; it caused a bounded DSI1
FIFO overflow and was reverted with a clean KMS cycle. See
`diagnostics/display-v27-live-pixel-path-audit-20260812.md`.

## V28: DSC PPS before cold panel ON

The v27 audit narrowed the dark-screen fault to the panel side of the two DSI
transmitters. Source inspection then found that the downstream normal enable
path sends the complete panel ON set (including sleep-out/display-on) before
the first full-width DSC PPS. V28 tests the panel-compatible ordering by
sending a 2944x1840 PPS before ON, retaining the existing post-ON PPS, and
restoring the canonical 1472-pixel per-link width after both sends.

The verified build and test interpretation are recorded in
`diagnostics/arch-v28-pre-on-dsc-pps-build-20260812.md`.

An offline byte-level audit additionally found that the active stock Tianma
ON property contains 88 commands (800 bytes), including a 66-command
gamma/brightness tail absent from the older reconstructed DTS and initial
mainline patch. The Linux 7.1 panel patch now includes the complete active
table. Details and the DSC/power conclusions are in
`diagnostics/display-v28-offline-stock-command-audit-20260812.md`.

## Linux 7.1 native-display test variant

The conservative mainline TB371FC DTB continues to leave the native display
off. A separate `sm8250-lenovo-tb371fc-display-test.dtb` now enables the fitted
Tianma panel, both bonded DSI controllers/PHYs and both KTZ8866 chips. A new
TB371FC backlight driver presents the pair as one logical backlight and mirrors
brightness/enable writes across I2C5 and I2C11.

The panel and backlight are built in, together with fbcon, the 16x32 Terminus
font and the color Linux logo. This provides a high-contrast visual target for
the requested next test instead of relying on whether a black framebuffer is
visible. The full ARM64 Image, DTB and both driver objects compile cleanly;
artifact hashes and the safe test order are recorded in
`diagnostics/mainline-7.1.7-native-display-build-20260812.md`. This variant has
not been flashed or hardware-tested yet.

Review of the public `tb371fc-desktop-linux-6.12` branch at commit `780c887`
confirmed that its display result relies on ABL continuous splash through a
`simple-framebuffer`; it does not implement native NT36532 modesetting. Its
useful clock/power-domain retention was ported into our separate display-test
DTB and expanded for both DSI links. Our diagnostic initramfs additionally
draws a format-aware full-screen color/checkerboard pattern directly through
fbdev, so a successful scanout is unambiguous even without a desktop session.

## V4: exact vendor DSI PHY lane configuration

The stock 4.19 DT supplies the following lane bytes to each 7 nm DSI PHY:
four data lanes with `00 00 0a 0a` and the clock lane with
`20 00 8a 8a`. Source inspection of Qualcomm's downstream v4.0 PHY driver
shows that the first three bytes become `CFG0`, `CFG1` and `CFG2`; `TX_DCTRL`
comes from the v4.0 table separately.

Linux 7.1's generic `qcom,dsi-phy-7nm` profile selected v4.1 instead and wrote
clock-lane `CFG0=0x00`. Patch 0013 adds a TB371FC-only compatible using v4.0
TX_DCTRL plus the required `CFG0=0x20`, without changing other SM8250 boards.
The resulting Image, DTB and recovery package are documented in
`diagnostics/mainline-7.1.7-native-display-phycfg-v4-build-20260813.md`.

# V32: upstream NT36532 vendor DSC sequence

V32 tested the DSC-enable ordering used by the October 2025 upstream
NT36532 series while retaining Lenovo's complete Tianma initialization table:

`90 03 -> 128-byte DSC PPS -> 9d 01`

The commands were sent once, before the panel ON sequence, as synchronized LP
DCS writes to both downstream DSI controllers. Kernel traces prove that all
three operations completed without a host transfer error. The PPS described a
2944x1840 picture, 736x20 slices, two slices per 1472-pixel interface and one
slice per packet.

The physical result did not improve. Immediately after handoff the panel was
gray with a green checkerboard row at the top; after Linux completed display
initialization it became dark with the backlight still enabled. `/dev/fb0`
was present and writable (`4096x4320` virtual size, 16384-byte stride, 32 bpp,
active mode 2944x1840). A direct full-frame write of large red, green, blue,
white, black, yellow, cyan and magenta vertical bands completed successfully,
but none appeared on the glass. This rules out font size, console placement
and a merely black userspace framebuffer as the current cause.

Both DSI controllers reported active video-engine register state, matching
timing and active lanes. Encoder counters ended at INTF1 VSYNC=30,
INTF2 VSYNC=0 and 19 underruns on each side. The zero software VSYNC count on
the slave interface is not independently conclusive because the same pattern
was recorded in earlier dual-link tests with non-zero hardware MISRs on both
interfaces. The remaining boundary is panel-side DSC interpretation or the
dual-link synchronization/packing contract.

Evidence:

- `diagnostics/mainline-display-hardware-20260813-161224.txt`;
- `diagnostics/mainline-display-hardware-20260813-161344.txt`;
- v32 recovery SHA-256
  `3e63740d14de47725722f9b86000e8181491cfab89f75d04d6818bf0be705569`.

After evidence capture, exact stock `recovery_b` and signed `vbmeta_b` were
restored and Android booted successfully on slot B. This experiment must not
be repeated unchanged: the extra `90/9d` sequence alone is insufficient for
the TB371FC Tianma panel.

# V33: per-link DSC PPS width

V33 changes one variable from v32: both the pre-ON and post-ON PPS packets use
the canonical per-controller picture width of 1472 instead of temporarily
expanding it to 2944. The SDE still renders the complete 2944x1840 frame as two
1472-pixel interfaces; slice width remains 736, slice height 20 and there is
one slice per packet. Lenovo's panel table and the v32
`90 03 -> PPS -> 9d 01` experiment are unchanged.

Verified artifacts:

- kernel SHA-256
  `8ee73b27456d141938071cd58c01334bc618b9435f641cd7175caaa374b65a0c`;
- recovery SHA-256
  `c5fe930e71e1bc7267527c8723ab04bd1f80f6a7b6343fbbcdd0d042dc5b8c43`;
- exact v32 ramdisk SHA-256
  `08df0e8a9eee611ed0daaa1e23795e268fd4b99ee9d8db11de67f12297480085`;
- exact v32 DTB SHA-256
  `cb0f50f13fd70b5dcd0b12d330ae09d070ae4d6f20f4873b1a9815883726ee0e`.

The recovery passed Android boot-v2 unpacking, AVB `NONE` verification and
byte-for-byte ramdisk, DTB and recovery-DTBO comparison. It booted successfully
through the temporary recovery path. Live traces confirmed two successful
1472x1840 PPS broadcasts and the retained NT36532 vendor command order. A
stride-aware eight-color pattern was then written directly to fb0. Physically,
the panel first showed the inherited gray frame with a green checkerboard row;
after Linux completed initialization it remained uniformly gray with the
backlight enabled. Neither the console nor the color bands appeared. The full
machine capture is
`diagnostics/mainline-display-hardware-20260813-163439.txt`.

Conclusion: a per-link `pic_width=1472` PPS is not sufficient and must not be
retested unchanged. The next controlled variant returns to the full-panel
2944-pixel PPS and removes the redundant post-ON PPS, leaving only the
pre-ON `90 03 -> PPS -> 9d 01` transaction followed by Lenovo's exact ON
table. This isolates whether rewriting PPS after `display-on` disrupts the
NT36532 decoder.

# V34: pre-ON PPS only and persistent kexec bridge

V34 restores the full-panel `pic_width=2944` PPS and suppresses only the
second PPS after Lenovo's display-on sequence. DMS/POMS transition updates are
retained. The cold trace on hardware contains exactly one successful
`90 03 -> 2944x1840 PPS -> 9d 01` transaction before ON and the explicit
marker `post-ON PPS only for transition flags=0x0`; no cold post-ON PPS trace
follows.

Artifacts:

- kernel SHA-256
  `b98478d17865382f5554ad33435898a4ee1f10721fa252a7fc704b67ae16c360`;
- kexec initramfs SHA-256
  `358651c0b26add362315b40dc8d150d7a41af4ebb9a1c8aa7c2827dc32c4600f`;
- recovery SHA-256
  `205dae2250efbad6088406ce290818463d649540e8d895498fd51b3bea8285af`.

The kernel has `CONFIG_KEXEC=y` and the downstream ARM64 kexec ABI fix. The
static `kexec-tools 2.0.32.git` binary and transfer helpers survive switch_root
under `/run/tb371fc-rescue`. Live receivers are available over NCM at ports
2325 (Image), 2326 (DTB) and 2327 (initramfs). This permits subsequent kernel
tests from RAM without booting Android or rewriting recovery, after host-side
hash verification. A direct eight-color framebuffer was written; physical
v34 result remained a dark panel with the backlight enabled; the color bands
did not appear. Therefore the redundant cold post-ON PPS is not the cause and
v34 must not be repeated unchanged.

The live DRM connector command interface accepted a standard LP-mode DCS
`Display On (0x29)` packet and reported `last_cmd_tx_sts=1`, but the tablet
remained dark with the backlight enabled. Thus a missing final `Display On`
command alone is not the fault. This interface still provides a useful
no-reboot path for bounded panel-command experiments.

A subsequent live LP-mode sequence sent `Sleep Out (0x11)`, waited 120 ms,
then sent `Display On (0x29)` and waited 100 ms. Both writes again reported
`last_cmd_tx_sts=1`, with no transfer error in `dmesg`, but the physical panel
remained dark with its backlight on. This excludes a merely omitted or too-early
standard wake/display-on pair. The next diagnostic must read panel state rather
than infer it from successful writes.

# V35: post-ON DCS status readback

V35 returns to the full-width pre-ON plus post-ON PPS behavior used by V32 and
adds read-only status instrumentation immediately after Lenovo's exact ON table,
before the video timing engine starts. It reads each DSI controller independently:
Get Power Mode (`0x0a`, one byte), Get Display Status (`0x09`, four bytes), and
Get Diagnostic Result (`0x0f`, one byte). Raw replies and failures are logged
with the `TB371FC status post-panel-enable` marker. This build is intended to
separate panel sleep/display state from DSC or pixel-stream configuration faults.

The first attempted V35 launch through the V34 kexec bridge did not enter V35.
The machine reset and booted the still-installed V34 recovery image, proven by
`uname` build time `2026-08-13 16:45:03 +05` and the V34-only marker
`TB371FC cold path already sent PPS; post-ON PPS only`. No V35 status marker was
present and pstore was empty. Consequently the unchanged dark/backlit panel is
not a V35 display result. The kexec transition path is not yet trusted; V35 must
be tested through the established temporary `recovery_b` workflow.

V35 was then written through the verified temporary `recovery_b` workflow and
confirmed by kernel build time `2026-08-13 17:00:42 +05`. Both DSI halves
successfully returned `0x0c` for DCS Get Power Mode (`0x0a`). Per MIPI DCS,
that means Display Normal Mode and Display On are set (bits D3 and D2), but
Sleep Mode remains on because D4 is clear. Thus the panel is present and the
LP command/read path works in both directions, but the panel has not accepted
or retained `Sleep Out (0x11)`. This directly explains why no video image is
shown despite the backlight and accepted `Display On` writes.

The longer Get Display Status (`0x09`) returned four zero bytes on controller 0
and `-EINVAL` on controller 1. The subsequent diagnostic-result read did not
complete, leaving the DRM enable sequence blocked before the post-ON PPS/video
engine stage. V35 must not be reused unchanged. The next comparison is the same
`0x0a` read under rooted stock Android, followed by a bounded V36 that reads
only `0x0a` and tests the Sleep Out placement/state transition.

# V13 baseline replay and live power/scanout isolation

The exact V13 recovery was replayed because that build had previously produced
a physically visible fragment of the Linux console at the top of the panel.
The installed recovery SHA-256 is
`ff6136aa61b371b610a4e568d3438e04dac89692e1b15145822d3b9c8860b370`;
the running kernel is
`4.19.325-cip134-st18-perf+ #7 Tue Aug 11 12:38:59 +05 2026`.
V13 preserves the bootloader continuous splash and exposes the native
2944x1840@120 DRM mode.

The replay exposed a separate late-power issue. At 31.713 seconds the regulator
core logged `display_panel_avdd: disabling`. A reversible diagnostic module was
built against the exact V13 kernel and loaded without reboot. It acquired and
enabled `display_panel_avdd`; the live regulator summary then reported AVDD at
5.5 V, with `lcdb_ldo` and `lcdb_ncp` both enabled at 4.0 V. The module is
`D:\TB371FC-builds\panel-avdd-hold-v13.ko`, SHA-256
`d0573724797260537ff9da4f56869f2cfafc4b7c0c5f37e9002b8b874bdb9637`.
This proves the AVDD rail can be controlled safely from the running Linux test
environment and establishes that a future image must retain it explicitly.

After the original KMS holder exited, DRM still reported an active
2944x1840@120 CRTC but every plane had `fb=0`. A new 2944x1840 framebuffer was
assigned live without reboot. The user physically observed a gray panel with a
narrow green checkerboard strip along the top. The green checkerboard is the
test framebuffer pattern, so Linux-generated pixel data reaches the internal
panel. The remaining fault is therefore in scanout/dual-DSI/DSC geometry or
panel decoder state, not a dead panel, missing backlight, or absent framebuffer.

At that point both downstream DSI debug states still reported `CTRL_ENGINE=ON`
but `VIDEO_ENGINE=OFF`, with byte and pixel clocks at zero. A bounded KMS cold
cycle was started while AVDD remained held to distinguish stale continuous-
splash scanout from a fully restarted video engine. The screen became dark,
confirming that the partially visible checkerboard depended on the inherited
bootloader scanout and that V13 cannot cold-start the panel correctly.

The first cold-cycle holder was accidentally tied to the diagnostic SSH session;
when that session ended, closing the DRM file descriptor disabled the pipeline.
The test was repeated with `nohup setsid`, and the holder remained correctly
parented to PID 1. DRM then showed an active 2944x1840 framebuffer owned by the
test process, but both DSI controllers still reported their video engines and
pixel/byte clocks off. Encoder 28 showed `intf:1 vsync=69`, `intf:2 vsync=0`
and 39 underruns on both interfaces.

A final reversible RAM-only test set encoder 28 `idle_power_collapse` from `Y`
to `N` and assigned a fresh checkerboard framebuffer. It did not establish the
second interface: after five seconds intf1 reached 1908 vsync events, intf2
remained at zero, and both underrun counters reached 1753. The test was stopped
to avoid an unbounded underrun storm and idle collapse was restored to `Y`.
This rules out idle power collapse as the initiating fault. The next build must
instrument and fix the dual-interface kickoff/flush path before another physical
panel cycle; V13 cold-cycle and no-idle tests must not be repeated unchanged.

# V36: continuous-splash dual-interface flush

V36 implements the next bounded test derived from the V13 live evidence. It
keeps the V13-safe continuous-splash lifecycle and does not include the V35 DCS
reads or the later experimental cold-panel command sequences. The first Linux
video commit no longer skips interface flush programming merely because the
bootloader splash is active. It explicitly queues the normal flush bit for each
physical DSI interface and logs interface, split role, CTL and splash state.

The recovery command line additionally contains `regulator_ignore_unused`, so
`display_panel_avdd` is retained from boot instead of being disabled after
31 seconds. The V13 ramdisk and DTB are byte-for-byte unchanged.

Verified artifacts:

- kernel SHA-256
  `cbaf31aac6294d5803fea37475de51654b446a3ef448f9f441c335240c2d1a36`;
- unchanged V13 ramdisk SHA-256
  `41b742e836f344b1362837459468aca55b6ae5871b2bfe11404d7241e05aafa5`;
- unchanged V13 DTB SHA-256
  `cb0f50f13fd70b5dcd0b12d330ae09d070ae4d6f20f4873b1a9815883726ee0e`;
- recovery SHA-256
  `50c56310ddb5f86c9ba523ff6f4e40da18d64d1c89f32be880ee4c28e3d67a36`.

The 100 MiB Android boot-v2 recovery was independently unpacked. Its embedded
AVB footer and `NONE` vbmeta structure verify successfully, its kernel contains
the new trace marker, and its command line contains `regulator_ignore_unused`.
The exact recovery hash is allowlisted by the guarded temporary test script.
It was then written temporarily to `recovery_b` together with the already
verified test `vbmeta_b`. The guarded launcher confirmed V36 over USB, and the
running kernel build time is `Thu Aug 13 17:59:09 +05 2026`.

Hardware logs prove that V36 queued the slave first and master second:
`intf=2 role=2 ctl=0 splash=1`, then `intf=1 role=1 ctl=0 splash=1`. The common
kickoff reported `affected=0x3`, two active physical encoders and the expected
2944x1840, two-mixer DSC topology. This confirms the patch reached both halves.

The vendor regulator core nevertheless disabled `display_panel_avdd` at
31.713 seconds even though `regulator_ignore_unused` was present in the parsed
kernel command line. The parameter is therefore ineffective in this Lenovo
4.19 tree. The exact previously verified AVDD hold module was loaded live and
restored the rail to 5.5 V. V37 must make this regulator hold explicit in kernel
or initramfs rather than relying on the command-line parameter.

After AVDD restoration, both DSI controller debug states simultaneously showed
`VIDEO_ENGINE=ON`, byte clock 141250000, pixel clock 188333333 and escape clock
19200000. The original 120-second V13 KMS holder had already exited and left
`fb=0`, so a new checkerboard holder was started with `nohup setsid`, without a
cold cycle. It remained active under PID 1 while both DSI video engines stayed
on. Physically the screen remained dark with its backlight on. Because AVDD had
already been removed before it was restored live, this result cannot distinguish
panel state loss from the remaining dual-DSI synchronization fault.

# V37: early explicit AVDD hold

V37 reuses the exact verified V36 kernel and V13 DTB. Its only functional change
is an initramfs helper that loads the already hardware-tested AVDD hold module
immediately after `/run` is mounted. A failure to acquire the regulator after
five bounded attempts stops the display test rather than continuing with an
invalid power sequence. This ensures the panel never reaches the 31-second
unused-regulator cutoff observed in V13 and V36.

Verified artifacts:

- unchanged V36 kernel SHA-256
  `cbaf31aac6294d5803fea37475de51654b446a3ef448f9f441c335240c2d1a36`;
- AVDD module SHA-256
  `d0573724797260537ff9da4f56869f2cfafc4b7c0c5f37e9002b8b874bdb9637`;
- V37 initramfs SHA-256
  `a0cc1a6ee99d226aa6ed192aeea8f56ce77810ee08cfcf20b4b977805234e53a`;
- unchanged V13 DTB SHA-256
  `cb0f50f13fd70b5dcd0b12d330ae09d070ae4d6f20f4873b1a9815883726ee0e`;
- V37 recovery SHA-256
  `245efca9726e69977737eafecd345ac37ae2732e9e5c990a4cfc9b626e6db12e`.

Independent unpacking confirmed the early init call, executable helper and
embedded module. AVB verified both the footer/vbmeta structure and the recovery
hash descriptor. V37 was allowlisted and then launched through the guarded
temporary recovery workflow.

On hardware the AVDD module was present before the late regulator sweep. At
uptime 76 seconds `display_panel_avdd` remained enabled at 5.5 V and no
`display_panel_avdd: disabling` line existed; only unrelated `vdd_hap_boost`
was disabled. Both DSI video engines remained on at the expected clocks. The
physical result was the same stable gray frame with the Linux green checkerboard
strip along the top. This is the first clean result with no panel power loss,
and therefore confirms that the remaining partial-frame fault is downstream
DSC packetization/decoding or scanout synchronization.

At 120 seconds the inherited V13 KMS holder exited by design, released its
framebuffer and made the panel dark again. This was not a power or DSI failure:
AVDD remained at 5.5 V and both video engines remained on. A replacement
checkerboard holder was started detached under PID 1 for 86400 seconds without
a cold cycle. Future ramdisks must use the longer hold by default so this timer
cannot be confused with a panel regression.

## V37 live refresh and performance isolation

The first attempted `60 Hz` test was invalid. The V37 ramdisk still contained
the older V13 `drm-kms-smoketest` binary, which always selected the preferred
mode despite accepting extra command-line arguments. Live DRM state remained
`2944x1840x120x375888vid`. The diagnostic source was updated to enumerate the
complete connector timings, select by either the reported or calculated refresh
rate, flush its pre-commit output, and identify the exact selected mode. The new
static ARM64 binary has SHA-256
`40f09c7eda578ea60b258c0145160e6e84db9d6262a61031d76bb9bf8a35cb0e`.

The downstream connector exposes three modes. They share a 375888 kHz pixel
clock and horizontal timing 2944/3346/3370/3490, while their vertical totals are
2050, 4100 and 8200 for the driver-labelled 120, 60 and 30 Hz modes. The new
binary selected the 60-Hz object and live DRM state confirmed
`2944x1840x60x375888vid`, `mode_changed=1` and `plane_mask=1`.

Before that commit, debugfs performance mode 1 was enabled. The driver source
defines this as its maximum clock and bandwidth test mode; hardware state
confirmed MDP at 460 MHz and a 16.6 GB/s minimum bus vote. This did not prevent
the fault. A 120-Hz max-performance commit increased both interface underrun
counters from 38 to 48, and the verified 60-Hz commit increased them from 59 to
67. The counters then remained stable, so this is a bounded commit-time failure
rather than a continuing underrun storm. The 120-Hz physical result was gray
with a narrow green checkerboard strip. At verified 60 Hz, the upper green strip
remained but the main gray area changed to visible artifacts. This proves that
the panel responds to the alternate vertical timing and further narrows the
fault to split-display DSC geometry, packet distribution or master/slave
interface synchronization, rather than panel power or ordinary bandwidth.

The 60-Hz photograph (`C:\Users\<user>\Downloads\IMG_1843.jpeg`) shows dense,
vertically repeated coloured structures across essentially the full active
panel, while the separate top row retains the expected 64-pixel checker cadence.
A verified 30-Hz commit produced the same physical corruption. It added only
two underruns per interface (67 to 69), compared with eight at 60 Hz, so the
fault is independent of refresh rate and persists after the commit-time
underruns stop.

The corrected utility then committed a solid red framebuffer at 30 Hz. The
artifact field remained unchanged, but the narrow top strip changed from the
checker pattern to solid red. This proves the strip carries current Linux pixel
data and that pixel format, stride and framebuffer fill are not responsible for
the corrupted area. The apparent strip height is close to the configured DSC
slice height of 20 lines, strongly suggesting loss of encoder/decoder agreement
after the first slice row.

A read-only module captured both live SDE DSC blocks. DSC0 and DSC1 were
identical: common mode `0x00000005`, encoder config `0x003080ca`, picture
`0x0b800730` (2944x1840), slice `0x02e00014` (736x20), and chunk size 736.
The active panel was independently confirmed as Tianma by both the selected
kernel command-line node and the NT36532 touch firmware report; the BOE profile
is not selected.

Two reversible MMIO tests were performed and restored without reboot. Changing
both host DSC picture widths from 2944 to 1472 produced no physical change.
Forcing the hardware ICH reset override bits changed both encoder registers from
`0x003080ca` to `0x303080ca`, survived a new red framebuffer commit, and also
produced no physical change. Unloading the modules restored the exact original
registers. Per-link width and ICH override must therefore not be repeated as
standalone fixes. The next decisive reference is a read-only dump of these same
DSC registers while stock Android is driving the working panel.

## Stock Android trace and V38 splash PPS test

A rooted stock Android boot was traced through the built-in SDE event log over
a complete display off/on cycle. The stock `4.19.157-perf+` kernel cannot load
our diagnostic module (`CONFIG_MODVERSIONS=y`, forced signed modules, no
`CONFIG_DEBUG_FS` or kprobes), but the vendor trace contains the required DSI
ordering. The full capture is preserved as
`diagnostics/android-stock-sde-panel-cycle-trace-20260813.txt`; the matching
compressed kernel configuration is
`diagnostics/android-stock-4.19.157-config-20260813.gz`.

Stock Android and V37 agree on the important steady-state parameters: two layer
mixers, two encoders and two DSI interfaces, DSC common mode `0x5`, display mode
2944x1840, link clocks `0x0d69ba00`, `0x086b4dd0` and `0x0b39bd15`, and video
timing values `0x801`/`0x2fb`. This makes a simple timing or bandwidth mismatch
unlikely.

The decisive difference is command ordering. Stock sends command set `0x11`
(`DSI_CMD_SET_PPS`) immediately before enabling both DSI video engines. The
V37 continuous-splash path enables the engines and returns before the normal PPS
update block, then underruns at kickoff. Earlier PPS experiments were therefore
placed on a path that continuous splash never executed.

V38 moves a checked `dsi_panel_update_pps()` call into the continuous-splash
branch before `dsi_display_vid_engine_enable()`. While composing the PPS it
temporarily converts the per-link picture width back to the full panel width and
then restores it. The change is isolated in
`vendor-kernel/patches/0014-tb371fc-cont-splash-send-stock-pps-before-video.patch`.
The verified recovery image is
`D:\TB371FC-builds\arch-development-loader-v38-splash-stock-pps\tb371fc-arch-development-loader-v38-splash-stock-pps-recovery.img`
(104857600 bytes, SHA-256
`329a421fa03e922c056c5b392ff2ed3cbb38c0b6441d673f62c467200e593301`).
Its unpacked ramdisk, DTB and recovery DTBO are byte-identical to V37; only the
kernel changed. This is the next on-device display test.

V38 subsequently booted and executed the new PPS path. The first kickoff had no
underruns on either interface, but the panel still showed grey with a green
checker strip. Sending the three exact stock 120-Hz packets later through
debugfs was accepted but did not repair the already-running stream. V39 therefore
parses `qcom,mdss-dsi-dispparam-pen-120hz-command` and sends it immediately after
POST_ON, matching the stock event order. The verified V39 recovery SHA-256 is
`6642a4142ba52d8fb8b8c0b713ef559fa3302ca0b7907d73534a190efb146e2d`.

V39 proved that command was transmitted, but the physical result stayed grey
with the same narrow green strip. The later dark screen was traced to the old
automatic cold-cycle helper leaving `plane_mask=0`, not to panel power loss.
A live full-screen red XR24 framebuffer restored `plane_mask=1`; both DSI links
remained active with no ACK/timeout errors, yet only the partial strip was
visible. The strip is approximately one configured DSC slice row (20 lines).

The next test therefore changes the stream boundary rather than its pixels:
stop both inherited bootloader video engines, send the full-width PPS while no
video packets are flowing, and synchronously start both links. Patch 0016
implements this bounded continuous-splash handoff. The next initramfs also
removes the automatic cold cycle and holds a red framebuffer for 86400 seconds,
so a timer cannot again masquerade as a display regression.

V40 booted and held the expected full-screen red framebuffer in DRM state, but
the physical output remained partial. The new trace identified a software-state
failure before the intended hardware transition: video-engine disable returned
`-EINVAL`. Continuous-splash setup had imported both DSI host engines as ON but
left both inherited video engines recorded as OFF, even though the bootloader
was still transmitting. V41 imports those two video states as ON first, then
uses the normal checked `OFF -> PPS -> ON` sequence. This is implemented by
patch 0017 and preserved in
`diagnostics/display-v41-splash-state-build-20260813.md`.

V41 confirmed that state import works and removed the `-EINVAL` failures, but
PPS command DMA timed out while both inherited video engines were physically
OFF. This also explains why V38 could transmit but still corrupt the frame:
with physical video ON and software video OFF, the DSI 2.2 frame-line scheduler
was bypassed. V42 keeps physical video active after importing both states as ON,
so synchronized PPS uses the native video-line scheduler. It then skips the
redundant splash video-enable operation. The build is recorded in
`diagnostics/display-v42-scheduled-pps-build-20260813.md`.

V42 then proved that the native DSI 2.2 frame scheduler is not the missing
piece. Its PPS transfer, initial dual-link kickoff and PLL state were clean, but
the panel still showed grey with the narrow green strip. When the temporary KMS
client later exited, `plane_mask` became zero and the panel became dark with its
backlight on. Starting a new solid-red 2944x1840 XR24 client restored
`plane_mask=1` but reproduced the grey/green output. The next experiment is a
strict kernel A/B control: the exact Lenovo 4.19.157 recovery kernel and exact
stock DTB with the current storage-safe Linux/NCM environment. This test does
not mount Android or microSD storage and will distinguish a 4.19.325 display
regression from a boot-handoff problem.

The V43 A/B control used the exact unmodified Lenovo 4.19.157 recovery kernel,
DTB and recovery DTBO. It nevertheless showed the same inherited grey frame
with green strip and then became black. Therefore the 4.19.325 kernel binary is
not the sole cause; working Android contributes a later panel/power/display
transition that the minimal Linux environment does not yet reproduce. V43's
new USB gadget setup did not enumerate, so V44 retains the byte-exact NCM setup
from old loader V4, which previously enumerated with the same stock kernel. Its
purpose is to capture the stock-kernel transition live, before changing any
panel state.

V44 confirmed that the screen eventually loses its backlight under the exact
stock kernel and minimal Linux userspace. Its known-compatible V4 NCM gadget
enumerated, proving userspace was running, but its network data plane repeated
the old no-ARP/no-IPv6 failure. V45 therefore takes autonomous snapshots before
KMS and 5/35/65 seconds later, then exports them through a read-only USB FAT log
disk backed entirely by RAM. This will identify which regulator, backlight or
display state changes when the visible partial frame turns off.

V45 isolated that late transition. `display_panel_avdd` is enabled at 5.5 V at
uptime 1.50 and 7.04 seconds, has no regulator consumer, and is disabled by the
unused-regulator sweep at 31.713228 seconds. It is disabled in the 37.56- and
68.10-second snapshots, while both LCDB rails, the long-running red KMS client
and the enabled DSI connector remain present. The physical grey/green frame
turns dark in the same interval. The full evidence is preserved under
`diagnostics/v45-stock-kernel-logdisk-20260813/`.

V46 adds only `regulator-always-on` to the active overlay entry 2 fixed-regulator
node for `display_panel_avdd`, inside the recovery image's embedded DTBO. It
keeps the exact stock kernel and V45 userspace. This should prevent the late
screen-off event and confirm that AVDD retention is required. It is not expected
to fix the initial grey frame and narrow green strip; after AVDD is held, work
returns to the remaining dual-DSI/DSC stream geometry and panel command state.

V46 subsequently confirmed the power hypothesis: `display_panel_avdd` remained
enabled at 5.5 V through the 65-second snapshot and the unused-regulator sweep
did not disable it. The malformed image remained, so AVDD retention is required
for stable testing but is not the missing content-path fix.

Internet/source review then found the decisive TB371FC-specific implementation
in the `tb371fc-desktop` desktop-Linux branch. Its authors document that one
full-screen DRM plane must be split over two parallel SDE SSPP blocks; without
that source split only half of this panel can be driven. Their tested activation
values are `qcom,sde-sspp-linewidth = <0x758>` and a matching first VIG
linewidth limit of `0x758`. Our stock DT advertises `0x1000`, so a 2944-wide
plane does not enter the parallel path. This explains why changes downstream at
DSI/DSC PPS, timing and framebuffer fill could not repair the full image.

V47 therefore changes strategy from further panel-command experiments to the
known device-specific SDE path. It uses the community `tb371fc-desktop-linux`
kernel, patches only active base DTB entry 0 to the published `0x758` values,
retains V46's AVDD-always-on property in active DTBO entry 2, and reuses the V45
RAM-only diagnostic/log-disk initramfs. Build rationale and modern bonded-DSI
follow-up references are recorded in
`diagnostics/display-v47-community-parallel-sspp-research-20260813.md`.

V47 built and passed structural verification. The 104857600-byte recovery image
is `D:\TB371FC-builds\arch-development-loader-v47-community-parallel-sspp\tb371fc-arch-development-loader-v47-community-parallel-sspp-recovery.img`
with SHA-256
`ffd0377d05f5a1c7fe5fce7d43db52d7381c164f5224152929d460dc11bedfa5`.
The embedded Linux 4.19.157 community kernel hash is
`a73a7ac437066be5cc35aa6529fdadf93c11f6cca098e9a4e8db20d712af7e02`.
The next action is a guarded temporary V47 launch after one manual entry into
bootloader; V47 has not yet been written to the tablet.

V48 superseded V47 only by adding DRM KMS debug logging and was launched
successfully. The physical result was the first full-screen response: the
narrow green checker strip expanded over the complete panel, then the image
became dark with backlight still on. The delayed read-only log disk proved the
first 2944x1840x120 `SETCRTC` began at 3.165 seconds but did not return; its
userspace process remained alive at 69.20 seconds with no output. AVDD stayed
enabled at 5.5 V and both LCDB rails stayed enabled, so this is an incomplete
first KMS commit rather than another panel-power failure. The complete result
is recorded in
`diagnostics/display-v48-community-parallel-sspp-result-20260813.md`.

V49 now adopts the community wiki's second device-specific requirement: a
simple framebuffer over the inherited `0x9c000000` splash memory. It avoids a
userspace DRM modeset, writes a direct fbdev color pattern, then leaves a large
`SUN12x22` Linux console on `tty0`. This separates proven panel scanout from the
remaining downstream DRM page-flip/commit bug.

The final V49 package also preserves all nine clocks listed by the community
simplefb DTS. Because this Android 4.19 DT exposes `mdss_core_gdsc` as a vendor
regulator instead of a generic power-domain provider, V49 holds its exact
`qcom,gdsc@af03000` node through simplefb's `mdss-supply` mechanism. `/chosen`
uses two address and size cells and the framebuffer `reg` is the exact
`<0 0x9c000000 0 0x2300000>` range. The verified 100 MiB image has SHA-256
`025f98954dd76ffe2a31cdc7a096dde628cba051ef57bcbb189521f91d5b5e4a`;
the build record is
`diagnostics/display-v49-community-simplefb-build-20260813.md`.

V49 then booted but left the Lenovo splash unchanged. Its autonomous logs
proved `simplefb_probe()` failed with `-ENOMEM`: ARM64 rejected
`ioremap_wc(0x9c000000, 0x2300000)` because the reserved splash pages still
belonged to the linear RAM map. V50 adds the standard empty `no-map` property
to the existing `cont_splash_region@9c000000` reservation. This makes
`pfn_valid()` false for that range and permits one write-combined mapping,
without changing its physical address, size or ownership.

V50 also restores unattended development access. It starts the previously
proven ACM+NCM gadget and RAM-only BusyBox rescue shell at
`169.254.77.2:2323`, displays the simplefb proof, then verifies and enters the
authorised 6 GiB Arch container on microSD. Arch starts public-key-only SSH on
port 2222. `drm-kms-smoketest` is deliberately removed from the initramfs, so
the Arch runtime cannot repeat V48's hanging DRM modeset. The remote
`return-to-bootloader` helper is retained for subsequent tests without a manual
power-key cycle. Build details are in
`diagnostics/display-v50-community-simplefb-arch-ssh-build-20260813.md`.

V50 was then physically successful: the internal panel displayed a stable,
readable Linux fbcon over its full scanout area for more than five minutes.
This confirms the splash `no-map` correction and establishes the first usable
Linux console on TB371FC. The residual magenta edge is the intentional test-
pattern border outside complete 12x22 fbcon cells, not a panel-width failure.
This result still uses inherited bootloader scanout; native DRM's first atomic
`SETCRTC` hang remains to be solved independently.

V50 also exposed a userspace-only remote-control bug. Its setup allocated ACM
first, NCM creation then failed and PID 0104 enumerated without any shell bound
to `ttyGS0`. The community's own commit `c2adf4b` confirms that ACM PID 0104
plus a serial getty on `ttyGS0` is the intended working control path. V51
therefore preserves the proven kernel and display DTB byte-for-byte, creates
ACM only and binds a respawning interactive BusyBox ash before holding safely
in initramfs. NCM and Arch handoff are deferred until this control channel is
physically proven, after which `return-to-bootloader` removes further manual
cycles. The
build and exact artifact are recorded in
`diagnostics/display-v51-community-simplefb-arch-remote-build-20260813.md`.

The required unattended transport is SSH, with a serial shell only an optional
rescue mechanism. V52 therefore avoids V50's failed ACM-then-NCM composite
allocation and creates NCM as the only configfs function. The verified Arch
container then provides public-key-only OpenSSH on `169.254.77.2:2222`, while
the proven V50 simplefb path remains unchanged. Build evidence is recorded in
`diagnostics/display-v52-community-simplefb-arch-ssh-build-20260814.md`.

## Linux 7.1.8 r6 parallel-SSPP adaptation

Linux 7.1 already contains the upstream `dpu_plane_split()` implementation,
including multi-SSPP allocation for a source rectangle wider than the catalog
limit. The missing board adaptation was therefore not another copy of the old
downstream SDE plane driver. It was the TB371FC limit itself: generic SM8250
declared 4096, while stock/community evidence requires `0x758` (1880).

Patch 0016 adds a board-specific DPU catalog which reuses all SM8250 hardware
tables and changes only `max_linewidth` to 1880. The display-test DTB selects
`lenovo,tb371fc-dpu`; base, stage0 and Arch/microSD profiles remain unchanged.
At 2944 pixels this forces the existing Linux 7.1 code to request two SSPPs,
matching the proven V48 direction without importing the 4.19 DRM stack.

r6 compiles, links and passes targeted DT-schema checks. Its Image SHA-256 is
`09245e6aafad68a77789388462e16b79813146aafb996e60b60d95281ba25a74` and
its display-test DTB SHA-256 is
`fe6b51f191faa2421699d28ba4fd5abfc9ebb6e4bc2c8bd128102a80e5bb7e05`.
It remains an offline candidate until an attended RAM-only test; no claim of a
working native DRM display is made yet.

The first hardware execution should use the separately verified r6 gated
payload. `drm_kms_helper.fbdev_emulation=0` and `msm.fbdev=0` prevent the DRM
probe from immediately owning the first modeset. The initramfs establishes USB
control and records the uncommitted DRM state; only the explicit
`run-mainline-display-test 120 checker 120` command submits the first frame.
This separates driver probe from scanout activation and keeps log collection
available during a stuck userspace KMS process.

## V56 compositor atomic-test failure and V56.1 correction

The first Plasma/KWin test on the working 4.19.157 console path isolated a
different native-DRM failure from the earlier panel timing work. KWin detected
the complete DSI-1 mode list, but SDE left `rsvp_nxt` sequence 2 behind after a
userspace atomic test. All later tests timed out with current reservation 1,
next reservation 2 and encoder 28, then returned `-EINVAL`. Consequently KDE
was alive with DRM master while `card0-DSI-1/enabled` remained `disabled`.

Patch `vendor-kernel/patches/0024-community-drm-track-userspace-test-only.patch`
adds a narrow distinction to DRM atomic state. Reservations made by an actual
userspace `DRM_MODE_ATOMIC_TEST_ONLY` ioctl are discarded because no modeset
can follow them. The atomic-check reservation for a real commit is still kept
for SDE mode_set, preserving Qualcomm's dual-DSI transaction semantics.

V56.1 subsequently proved this correction on hardware. KWin completed a real
atomic commit, `card0-DSI-1/enabled` changed to `enabled`, and Plasma Wayland
rendered cleanly over the complete 2944x1840 internal panel. The earlier gray,
checkerboard and dark-screen experiments are no longer the active downstream
display blocker. Native mainline 7.x support remains a separate future port;
V56.1 currently uses Lenovo's 4.19.157 display stack.
