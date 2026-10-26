# Linux 6.12 port status for Lenovo TB371FC

## Controlled loader checkpoint (2026-08-23)

The current development loader is r35.  It boots the proven V56.5
`4.19.157-perf-v56.5+` environment first, exposes the authenticated USB ACM/SSH
control path, preserves and hashes the Linux 6.12 Image/DTB/initramfs, and does
not execute 6.12 automatically.  The hardware test successfully enumerated
`TB371FC-V56-SSH` and `COM9`; an authenticated session verified all three
payload hashes and reported state `not-loaded`.

Use the three explicit target-side commands in order:

```text
/run/tb371fc-rescue/status-linux-6.12-r35
/run/tb371fc-rescue/load-linux-6.12-r35
/run/tb371fc-rescue/execute-linux-6.12-r35
```

The complete artifact, hashes, hardware evidence and inherited V56.5 serial
gate caveat are recorded in
`diagnostics/linux-6.12-controlled-loader-r35-result-20260823.md`.

Status date: 2026-08-18

Latest hardware result: the reported KDE desktop was verified as V56.5, not
6.12.  A clean 39-bit, marker-free 6.12 Image was then executed from RAM and
also reset before userspace; V56.5 returned with a fresh boot ID.  The next
candidate bypasses the downstream kexec state entirely: direct recovery r8b
uses the proven ABL entry address and a tiny shim to place the unchanged
modern Image at aligned address `0x80200000`.  It is offline verified but has
not yet been flashed.  See
`diagnostics/linux-6.12-clean39-and-abl-aligned-shim-20260818.md`.

The Linux 6.12 port is reproducibly buildable, packaged and offline verified.
The new desktop GPU r3 package contains the upstream DRM_MSM/Adreno stack and
its early A650 firmware. It has **not yet passed its hardware GPU gate**.
V56.3 r3.3 remains the working development desktop and V56.3 r2 remains the
immutable rollback image.

## Source

```text
WSL tree: /root/tb371fc/linux-6.12-donor
branch: codex/tb371fc-6.12-port
commit: 66abeb39a
kernel: 6.12.30
```

The port adds two intentionally separate configurations:

- `tb371fc_arch_safe.config`: boot, microSD, Arch root, USB ACM/NCM, console,
  kexec and diagnostics, with native DSI deliberately disabled;
- `tb371fc_arch_desktop.config`: the safe profile plus DRM_MSM/DPU/DSI,
  Adreno, QCA6390 ath11k, Bluetooth QCA, audio, camera and Novatek input
  modules.

The first hardware boot must use the safe profile. The desktop profile is not
accepted until the safe profile proves kernel start, microSD root and remote
control.

The desktop fragment now explicitly builds in the complete clock and fuse
contract needed by A650 probe:

- `CONFIG_COMMON_CLK_QCOM=y`;
- `CONFIG_SM_GCC_8250=y`;
- `CONFIG_SM_GPUCC_8250=y`;
- `CONFIG_QCOM_AOSS_QMP=y`;
- `CONFIG_NVMEM_QCOM_QFPROM=y`;
- `CONFIG_DRM_MSM=y` and Qualcomm SMMU support.

## Board work included

- board-specific power rails and reserved memory from the proven development
  DTS;
- firmware simple-framebuffer at 2944x1840 for the first visible console;
- UFS, USB-C/DWC3, Type-C role switching and the QCA6390 power node;
- microSD on SDHCI2 in conservative 3.3 V, 25 MHz, four-bit mode;
- GPIO75 external SD redriver sequencing in `sdhci-msm`;
- GPIO14 card detect;
- corrected four-cell serial-number fuse address;
- DTBs compile on the 6.12 tree and both kernel profiles complete a full
  `Image dtbs modules` build.

## Verified packages

```text
D:\TB371FC-builds\linux-6.12.30-tb371fc-safe-r2
D:\TB371FC-builds\linux-6.12.30-tb371fc-desktop-r2
D:\TB371FC-builds\linux-6.12.30-tb371fc-safe-r2-runtime
D:\TB371FC-builds\linux-6.12.30-tb371fc-safe-r3
D:\TB371FC-builds\linux-6.12.30-tb371fc-arch612-desktop+-desktop-r3
```

Offline verification covers SHA-256 manifests, ARM64 Image format, initramfs,
module archives, firmware simplefb dimensions, microSD/redriver DT properties,
kexec and USB NCM configuration.

Desktop GPU r3 additionally verifies that both the release firmware archive
and the initramfs contain:

```text
qcom/a650_sqe.fw
qcom/a650_gmu.bin
qcom/sm8250/lenovo/tb371fc/a650_zap.mbn
```

The provisional firmware set comes from the official upstream
`linux-firmware` repository at commit
`2398c20fc6563d41af79ce329de7c5b245345d5a`. The generic SM8250 ZAP is staged
under the board-specific lookup path only for guarded bring-up. On the next
rooted Android connection,
`scripts/collect-tb371fc-stock-gpu-firmware.ps1` will collect Lenovo's exact
signed ZAP without writing any partition. If its hash differs, the desktop
package must be rebuilt with the stock set before accepting GPU support.

Safe Image SHA-256:

```text
cdbe369d7eaf92275e50f7c744383de004dd2a1881003f83fca7e36f9c82d2c7
```

Safe microSD DTB SHA-256:

```text
caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c
```

## Hardware test contract

1. Boot rooted Android and collect/compare the exact Lenovo A650 firmware.
2. Boot the already installed V56.3 r3.3 or V56.5 development environment.
3. Run `scripts/stage-linux-6.12-desktop-gpu-r3-on-tablet.ps1`. This verifies
   all hashes and does not execute the payload.
4. Run `/usr/local/sbin/tb371fc-load-linux-6.12-desktop-gpu-r3` and confirm
   `/sys/kernel/kexec_loaded` is `1`.
5. Arm the matching 90-second V56 watchdog and execute the RAM-only transition
   with the exact token `EXECUTE_VERIFIED_LINUX_6_12_DESKTOP_GPU_R3`.
   No Android, recovery, vbmeta or boot partition is changed.
6. Accept only after console or USB control proves 6.12 is alive. Run
   `tb371fc-capture-linux-6.12-gpu` and require `/dev/dri/renderD128`, a clean
   A650/GMU firmware probe and hardware rendering before enabling KDE.

Prepared commands:

```text
scripts/collect-tb371fc-stock-gpu-firmware.ps1
scripts/stage-linux-6.12-desktop-gpu-r3-on-tablet.ps1
/usr/local/sbin/tb371fc-load-linux-6.12-desktop-gpu-r3
/usr/local/sbin/tb371fc-execute-linux-6.12-desktop-gpu-r3
/usr/local/sbin/tb371fc-capture-linux-6.12-gpu
```

## Current blocker

The tablet is currently powered off in Android and is not connected. All host
artifacts are ready. Hardware-dependent work is limited to collecting the
stock Lenovo ZAP, staging the verified package and observing the guarded boot.
No partition was written while preparing desktop GPU r3.

## Next gates

- Safe gate: 6.12 kernel start, simplefb console, microSD root and USB SSH.
- Desktop gate: DRM render node, A650 firmware, stable KMS and accelerated KDE.
- Peripheral gates: QCA6390 Wi-Fi, Bluetooth, touch/pen, audio, cameras,
  suspend, USB-C DP and dock Ethernet/HDMI/USB.
