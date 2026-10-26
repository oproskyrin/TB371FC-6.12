# Persistent Arch development laboratory

The long-running development environment keeps Android partitions untouched.
It stores one 6 GiB ext4 image as a normal file on the existing exFAT microSD
and boots that image through the already tested recovery route.

## Architecture

1. The verified recovery starts the hardware-tested downstream 4.19 bridge
   kernel and a small rescue initramfs.
2. The initramfs exposes USB NCM at `169.254.77.2` and keeps a rescue shell on
   TCP port 2323.
3. It mounts only microSD partition `/dev/mmcblk0p1`, checks for
   `tb371fc-linux/tb371fc-arch-development.raw`, attaches it to `/dev/loop0`
   and mounts its ext4 filesystem.
4. `switch_root` moves devtmpfs, procfs and sysfs into Arch and starts the
   project PID 1 through a BusyBox runtime retained in tmpfs.
5. Arch immediately reopens the USB rescue shell on port 2323, then starts a
   local console, persistent kernel logging, passive QRTR diagnostics and
   OpenSSH on `169.254.77.2:2222`.

The microSD partition table and existing files are not modified. Android
`boot`, `super`, `userdata`, slot A and every other Android partition remain
outside this design. The ext4 image can later be removed as one ordinary file.

## Verified artifacts

| Artifact | Location | SHA-256 |
|---|---|---|
| Installed Arch ext4 image, schema 2, exactly 6 GiB | microSD `tb371fc-linux/tb371fc-arch-development.raw` | `874aefbc65f176c94ad4e7dc7636993fd6d7f8b0bed8b77fee17da7d6609594e` |
| Preserved runtime-modified schema-1 image | microSD `tb371fc-linux/tb371fc-arch-development.schema1-backup.raw` | `865b3fe6900063f47536d3760a2088b4a117e2e02649007b011e5b9fda4c24ef` |
| Hardware-proven 4.19.325 fbcon kernel | `D:\TB371FC-builds\diagnostic-vendor-4.19.325-single-qmi-fbcon\Image-4.19.325-single-qmi-fbcon` | `d7919c2f5a3706f220dea926eaf7c1d3d41c9f774cb4c2bef9523fb6571a5a77` |
| Development-loader initramfs v7 | `D:\TB371FC-builds\arch-development-loader-v7\tb371fc-arch-development-loader-v7.cpio.gz` | `64943db6c06e3d721516d35c752592173d6816ad3453c3d58deeefa717797374` |
| Development recovery v7, exactly 100 MiB | `D:\TB371FC-builds\arch-development-loader-v7\tb371fc-arch-development-loader-v7-recovery.img` | `8ad42e997216ddce47c4d679207eb04384530fa6feb060f5c3e3375c9975ac53` |

The v7 recovery passed byte-for-byte Image, ramdisk, DTB and recovery-DTBO
comparison plus AVB NONE verification. The ext4 image passed `e2fsck`, ARM64
qemu-user execution and an OpenSSH configuration test. Schema 2 also contains
pre-generated per-image OpenSSH host keys. Before `switch_root`,
the loader attaches the image to loop0 and lazy-unmounts exFAT from the old
namespace; this prevents BusyBox cleanup from traversing the user's microSD.
It then moves devtmpfs/procfs/sysfs and preserves the guarded bootloader-return
helper plus BusyBox rescue runtime in the same tmpfs `/run`. Loader v7 waits
up to 60 seconds for `usb0`, refuses the Arch handoff if it never appears and
continuously reapplies the link-local address. It assigns stable local-only NCM
MAC addresses. Before `switch_root`, it moves `/run`, replaces the early
listener with one already chrooted into Arch, proves that PID remains alive,
and only then moves devtmpfs/procfs/sysfs and completes the handoff.

V7 also corrects a packaging mismatch discovered before launch: v4-v6 recovery
used Lenovo's stock `4.19.157-perf+` payload while the development userspace,
return module and tested display path target `4.19.325-cip134-st18-perf+`.
V7 uses the exact 4.19.325 kernel that already replaced the Lenovo splash with
a 2944x1840 fbcon console in hardware. Its command line keeps `console=tty0`
and `SUN12x22`; early init creates `/dev/tty0` from verified sysfs major/minor
if devtmpfs is absent and prints explicit `[TB371FC Linux]` stage messages.

The first v2 loader boot reached its NCM rescue fallback because this vendor
kernel did not mount devtmpfs. Sysfs nevertheless exposed exact block device
numbers `179:1` for microSD partition 1 and `7:0` for loop0. A live read-only
probe created only those RAM device nodes and successfully verified the full
exFAT, 6 GiB image, loop, ext4 marker and Arch binary chain. Loader v3 now
creates those nodes only after matching the same sysfs values.

The image is now installed on microSD as
`/storage/D42E-5DC7/tb371fc-linux/tb371fc-arch-development.raw`. The guarded
installer wrote a `.partial` file, verified its exact 6,442,450,944-byte size
and SHA-256 on the tablet, then renamed it. Android remained fully booted on
unlocked slot B with AVB `orange`, 100% AC-powered battery and 79 GiB free on
the card. No partition table or pre-existing file was changed.

Installed development tools include OpenSSH 10.4, `iw` 6.17,
`wpa_supplicant` 2.11, tmux, git, rsync, strace, gdb, dtc, iperf3, ethtool,
I2C/PCI/USB/input/video utilities and the exact stock QCA6390 firmware and INI.

## SSH trust

The client key is local-only and ignored by Git:

`artifacts/tb371fc-development-ssh/id_ed25519`

Its Ed25519 public-key fingerprint is:

`SHA256:4XB7QNE9Gre04cjQN7S27zpoFYrXJN9FvH1mXnZent4`

The server listens only on the USB link-local address. Password and keyboard
interactive authentication are disabled. Host keys are generated once while
preparing the per-device image and retained there; first boot therefore cannot
stall on early kernel entropy.

## Installation gate

The read-only preflight is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-arch-development-image-to-sd.ps1 `
  -PlatformToolsDir <platform-tools>
```

It pins tablet serial `<serial>`, microSD UUID `D42E-5DC7`, source size and
SHA, requires completed Android boot on unlocked slot B, checks an 8 GiB free
space floor, and refuses to overwrite either final or partial files.

Creating the file additionally requires the explicit
`-MicroSdWriteApproved` switch. The installer writes
`tb371fc-arch-development.raw.partial`, verifies its size and SHA on the
tablet, then performs a same-directory rename. It never repartitions or
formats the card.

That installation gate has completed successfully for development image v1.
The installer now refuses to run again because the final target exists.

## Daily connection and development

The current prepared entry image is V52. It retains the proven V50 simplefb
kernel/DTB and creates NCM as the only USB gadget function before entering the
existing schema-2 Arch image. Its 100 MiB recovery SHA-256 is
`f2e83276a37f1adb28703c963c08bdb688d9afd4ded9cd33bc4222011a795ccd`.
It is offline verified but not yet physically launched.

After an authorized development-recovery launch, connect with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/connect-arch-development.ps1
```

The intended workflow is to edit and build full kernels on WSL, while using
the tablet for live hardware inspection, logs and reloadable driver modules.
Changing the running kernel, DTB or a built-in driver still requires a reboot;
userspace, scripts and loadable modules do not.

Loader v29 adds an experimental ARM64 kexec bridge for the native-display
mainline iterations. It receives Image, DTB and initramfs independently on USB
ports 2325-2327, verifies pinned SHA-256 values, and can load the payload
without executing it. `scripts/stage-mainline-kexec.ps1` performs only that
staging step. Execution is deliberately separate and still requires explicit
authorization because it replaces the running kernel and can remove the USB
recovery channel. The complete verified build record is
`diagnostics/arch-v29-kexec-bridge-build-20260812.md`.

KDE Plasma and Plasma Mobile are intentionally staged as later package
manifests in `rootfs/packages-plasma.txt` and
`rootfs/packages-plasma-mobile.txt`. They can be installed into the persistent
Arch image after SSH, GPU and native DRM are stable; installing them does not
require rebuilding recovery. Kernel/DTB or built-in driver changes still need
a reboot, while userspace and loadable modules can be changed live over SSH.

## Display/KMS acceptance

The v8 hardware session proved that fbcon binding alone does not replace the
retained Lenovo splash. DSI-1 is detected with 2944x1840 modes at 120, 60 and
30 Hz, but remains disabled until an explicit DRM/KMS modeset. A static ARM64
KMS smoke test enabled the connector and replaced the splash with a grey field
and green stripe. Therefore the next image must perform a real KMS modeset;
writing `/dev/tty0` or `/dev/fb0` alone is not display acceptance.

Loader v13 completed the full automatic path in hardware. Its critical fix is
a tmpfs-backed `/dev`: Lenovo's kernel exposes device classes in sysfs but the
attempted devtmpfs mount leaves `/dev` as an ordinary initramfs directory,
which cannot be used as the source of `mount --move`. V13 creates and
populates a real `/dev` tmpfs, moves `/dev`, `/proc` and `/sys`, executes
`switch_root`, starts rescue and SSH, and only then activates DSI through KMS.

Expected stages for v9 and later are:

1. `[TB371FC Linux] kernel started; preparing USB rescue and Arch root`;
2. USB rescue and microSD/Arch verification messages;
3. `TB371FC Arch Linux development laboratory` with SSH/rescue addresses;
4. an identifiable DRM Linux status screen, followed later by the graphical
   compositor and terminal.

If the Lenovo image remains after DRM/fbcon initialization, display acceptance
fails even when USB works. USB port 2323 remains the recovery channel for that
case; the screen and USB results must be recorded independently.

The exact rollback-first order and independent acceptance gates are pinned in
[NEXT_DEVELOPMENT_TEST.md](NEXT_DEVELOPMENT_TEST.md).

WLAN remains separately gated. `tb371fc-wlan-lab activate` requires its full
one-shot token, catches `wlan0` before the downstream idle timeout and brings
the interface administratively up. It does not scan or associate. A passive
scan has a second explicit token. No replacement MAC is persisted or invented.

## Recovery

Before `switch_root`, a failed microSD lookup or mount stays in the initramfs
NCM rescue shell without touching Android. Loader v4 preserves a static
BusyBox rescue shell and the guarded return-to-bootloader helper in tmpfs after
the handoff. To end a session, flush logs, invoke that helper, and restore exact
stock `recovery_b` first and signed `vbmeta_b` second. Full installation or
dual boot remains out of scope until the stable 7.1 kernel reaches the same
hardware baseline.

## Current live baseline (V55, 2026-08-14)

V55 supersedes the V52 connection notes above. It is physically running on
slot B with the community `4.19.157-perf+` kernel, a readable inherited
simplefb console, the 6 GiB Arch loop root, and public-key OpenSSH carried over
CDC ACM. The Windows bridge exposes the authenticated tablet endpoint as
`127.0.0.1:22223`; the tablet SSH daemon itself listens only on
`127.0.0.1:2222`. No Android/UFS filesystem is mounted.

The live root has been updated and now contains the complete kernel build
toolchain plus a manual Plasma 6 bring-up subset. It has only 489 MiB free
(92% used), so no more large package transaction is allowed on this 6 GiB
container. It remains the stable hardware baseline and is not modified further.

The guarded launcher is `/usr/local/sbin/start-tb371fc-plasma`. It refuses the
current 4.19 kernel before opening DRM, requires a connected internal DSI
connector and an explicit `I_UNDERSTAND_DRM_MODESET` argument, and permits only
a `7.*-tb371fc*` kernel. Plasma, KWin, NetworkManager and BlueZ have not been
started automatically. This preserves the console and remote channel that
made V55 recoverable.

The stable V55 recovery image is:

```text
D:\TB371FC-builds\arch-development-loader-v55-community-simplefb-arch-loopback-ssh\tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img
SHA-256 c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5
```

The prepared replacement root is now a verified 12 GiB sparse ext4 image:

```text
\\wsl.localhost\Ubuntu-24.04\root\arch-tb371fc\tb371fc-arch-development-v2-12g.raw
logical size 12884901888 bytes; ext4 used 6.0 GiB; available 5.7 GiB
SHA-256 ae0fe97debbb6b6c485546dd130e9a9a15724784b41af3fb862bad1f1cf58b44
```

It contains the updated Arch ARM toolchain, guarded Plasma 6, KScreen,
Plasma PA, Dolphin, Mesa/Freedreno Vulkan, PipeWire/WirePlumber, ALSA,
NetworkManager/BlueZ, power and brightness utilities, diagnostics, static QRTR
tools and fresh per-image OpenSSH host keys. `e2fsck`, schema/permission checks,
the 633-package manifest, all 1,510 exact Linux 7.1.8-r4 modules, `sshd -t`
and the AArch64 QEMU smoke test all pass.
No display manager is enabled and no DRM client starts automatically. The image
has not been copied to microSD or booted.

`scripts/install-arch-development-image-to-sd.ps1` now supports the explicit
`-ImageProfile v2-12g` transaction. It requires at least the image size plus a
2 GiB safety reserve, preserves the old card image during an upgrade, verifies
the final remote SHA-256, and restores the previous filename if final
verification fails. This remains an attended Android/ADB operation.

Do not replace or reboot this session unattended. Linux 7.1.8 and U-Boot are
prepared as offline next-stage artifacts; their first hardware run is a new
boot-chain test and must retain a human-observable rollback point.

The current replacement kernel gate is r4 `arch-microsd`, not any r2/r3 Arch
payload. Its DTB finally enables SDHCI2 with the stock card-detect, SDHCI-managed redriver
power and regulator wiring, while limiting the first run to 25 MHz/3.3 V and
keeping UFS/GPU/display disabled. The full release and 34,086,912-byte RAM
payload are checksum-verified but not booted. If the attended test reaches
this same Arch root and SSH, the next controlled step is native Linux 7 DRM;
only after a connected DSI connector is verified may the existing guarded KDE
Plasma launcher be used.
