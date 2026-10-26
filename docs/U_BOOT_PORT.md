# TB371FC read-only U-Boot stage-0

## Purpose

Lenovo ABL does not implement host `fastboot boot`, so every direct recovery
experiment previously required a partition write. The U-Boot stage-0 is a
small intermediate loader placed in the same Android recovery-v2 container
only for an attended test. It preserves ABL's framebuffer, exposes a visible
console and accepts a Linux Android-boot payload into RAM through its own USB
fastboot implementation.

This is not a replacement bootloader and not an installer. Its configuration
disables UFS, MMC, SCSI, USB storage and `FASTBOOT_FLASH`. The automatic command
is only:

```text
fastboot -l $fastboot_addr_r usb 0
fastboot_bootcmd=bootm $fastboot_addr_r
```

The environment pins `serial#=TB371FC-UBOOT`, letting the host distinguish
U-Boot from Lenovo ABL. `board_late_init()` allocates `fastboot_addr_r` from
the real firmware-supplied RAM map with 2 MiB alignment; there is deliberately
no unsafe static fallback address.

## Source and verified artifact

The U-Boot source commit is
`527115ef6783cec49e5610c523c124b399011361`. Board files live under
`u-boot-port/`; the build, package and verification scripts live under
`scripts/`.

```text
D:\TB371FC-builds\u-boot-tb371fc-stage0-v3-uncompressed\tb371fc-u-boot-stage0-recovery.img
size 104,857,600 bytes
SHA-256 84bb3d7f8ae768e1550539b5b1489495f80ac375f55379cf4ac8c41b5321aa01
hardware status: HARDWARE FAILED BEFORE OBSERVABLE U-BOOT INIT; SUPERSEDED
```

The package preserves the exact stock recovery DTBO field, uses the stock
recovery-v2 memory layout and has an AVB `NONE` hash footer. Independent
unpacking byte-compared the embedded U-Boot binary and DTB and verified the
footer. The DTB exposes only inherited simplefb, UART2 and the primary USB
controller in peripheral mode; native MDSS/GPU, UFS and the secondary USB
controller are disabled.

An offline audit confirmed that Qualcomm U-Boot fills `$fastboot_addr_r` at
runtime using LMB. The first hardware candidate declared the invalid ARM64
offset `0xffffffff80000000`; a corrected but gzip-compressed candidate and the
uncompressed v3 candidate with `text_offset=0x80000` all returned before
U-Boot USB enumeration. Every attempt automatically restored the exact stock
pair, and unchanged V55 was reinstalled after v3. Do not retest these images.

The next discriminator is the independently verified bare-metal ABL entry
probe:

```text
D:\TB371FC-builds\abl-entry-probe-v1-padded\tb371fc-abl-entry-probe-v1-recovery.img
size 104,857,600 bytes
SHA-256 c2620fa4405b4200d5ae6a6767c472dfe4c27d9845b44931668d03691ddc8177
expected display: full-screen 64x64 green/magenta checkerboard
```

Its ARM64 payload is exactly 4096 bytes and uses no stack, DT, USB, memory
parser, firmware call or U-Boot code. The recovery is byte-identical to V55
for ramdisk, DTB and recovery DTBO. A visible checkerboard proves ABL entered
the payload and narrows v3 to early U-Boot init; a return to Lenovo fastboot
without it points to the wrapper/entry contract. See
`diagnostics/u-boot-stage0-hardware-result-20260814.md`.

Hardware result: **PASS**. The tablet displayed the expected full-screen
green/magenta checkerboard and held it. Qualcomm ABL therefore enters our
ARM64 code, and inherited simplefb can be written directly at `0x9c000000`.
The v3 failure is now conclusively inside early U-Boot initialization. The
v4 strategy is boundary instrumentation with the proven direct framebuffer
writer, beginning before `board_fdt_blob_setup()` and excluding storage,
pinctrl/SMMU and USB until a visible U-Boot boundary is reached.

The first boundary build is now offline verified:

```text
D:\TB371FC-builds\u-boot-tb371fc-stage0-v4-early-boundary-r2\tb371fc-u-boot-stage0-recovery.img
SHA-256 c85b6a623fe644ace8eef32aa8826c0510b74bb353b0a29a6b411bcfb0c1bbc1
```

Its disassembly is included in the artifact checksum manifest. Red is emitted
at the arm64 `reset` label; green plus a permanent `wfe` is emitted at entry to
`board_fdt_blob_setup()`. It must not be tested without somebody present to
force Lenovo fastboot afterward because neither successful boundary contains
USB or a software reboot path.

## Linux 7.1.8 payloads

`D:\TB371FC-builds\u-boot-linux-7.1.8-payloads` contains the historical first
hash-verified Android boot-v2 pair. It is retained for provenance but its
display payload is superseded by r6:

| Payload | Size | SHA-256 | Purpose |
|---|---:|---|---|
| `tb371fc-linux-7.1.8-stage0-u-boot.img` | 33,775,616 | `c770f4de6a5a276c602e9a5959d859b73fd4a48c8d509776d3c4b7fe93902004` | First Linux 7.x execution/USB test without native display |
| `tb371fc-linux-7.1.8-display-test-u-boot.img` | 33,783,808 | `9699db83ad1896fb455a0e62c21808bd4924f344ad8dbba9e46aa6b0bb37dbb8` | Attended dual-DSI/DSC hardware test |

Both are below `CONFIG_FASTBOOT_BUF_SIZE=0x7000000` (112 MiB). They carry the
same diagnostic initramfs and differ only in DTB. The 54,364,168-byte raw
ARM64 Image is stored as deterministic gzip and verified byte-for-byte after
decompression. This makes U-Boot place/decompress it at its separate
2-MiB-aligned `kernel_addr_r`, instead of attempting to execute an uncompressed
Image at the 4-KiB Android payload offset. They have no AVB footer because
U-Boot consumes them from RAM rather than a partition.

### r6 native-display payloads

The current stage0/native-display pair is stored under
`D:\TB371FC-builds\u-boot-linux-7.1.8-r6-display-wideplane-payloads`:

| Payload | Size | SHA-256 | Purpose |
|---|---:|---|---|
| `tb371fc-linux-7.1.8-stage0-u-boot.img` | 33,812,480 | `af8fe098070c0192af9840af98d7dcb55914d525c73745b9ef75688146d2daea` | Prove the r6 kernel/USB path without native display |
| `tb371fc-linux-7.1.8-display-test-u-boot.img` | 33,816,576 | `4f59f0ea38f1ddf135ba1a2739c1fb771e19aef1f45250d7d82657b9d80708e9` | Attended dual-DSI/DSC test with TB371FC 1880-pixel SSPP split |

Both unpack to the pinned r6 kernel, DTB and diagnostic initramfs byte for
byte. They are offline verified, unflashed and not booted. The r5
display-pinctrl pair is superseded; the r4 Arch/microSD payload below remains
the required gate before r6 display.

The preferred first native-display run is the additional gated payload:

| Payload | Size | SHA-256 | Purpose |
|---|---:|---|---|
| `u-boot-linux-7.1.8-r6-display-gated-payload\tb371fc-linux-7.1.8-display-gated-u-boot.img` | 18,898,944 | `1bb58f5dbcd393dacfa63ed892f62b40ec9f63a889b497286c4f9cea7cf5aa93` | Register DRM without fbdev modeset, establish USB, then run one explicit observed KMS test |

Its initramfs SHA-256 is
`a15ffe54c36e682f756c5e0c54c21b94ce705ed4afb404855ca1a762716d7edb`.
The image embeds a static KMS checker and before/current/after DRM snapshot
tools. It does not automatically invoke the checker and does not mount any
Android partition.

`scripts/control-mainline-gated-display.ps1` automates the ACM control path.
It has a non-device `ValidateOnly` mode, captures the initial DRM probe state,
requires `-KmsApproved` before sending the manual modeset command and stores
raw serial evidence under `diagnostics/`.

### r4 Arch microSD payload

The earlier r2 Arch payloads used DTBs with SDHCI2 disabled. r3 enabled it but
used a GPIO-hog rejected by the strict SM8250 pinctrl schema. All are blocked
from launch; r3 was never booted.

The replacement attended-test payload is:

| Payload | Size | SHA-256 | Purpose |
|---|---:|---|---|
| `u-boot-linux-7.1.8-r4-arch-microsd-payloads\tb371fc-linux-7.1.8-arch-test-arch-development-u-boot.img` | 34,086,912 | `6dd8f7542564ecdd60b4c28d912c2a097d38ea0a3121feb813bc86ba81d76d5c` | Linux 7.1.8, conservative microSD enumeration, Arch loop-root and USB/SSH handoff |

Its DTB enables only SDHCI2 on top of the stage-0 safety profile. It uses
stock GPIO 14 card detect, SDHCI-managed GPIO 75 BayHub-redriver power and the upstream
PM8150L L6/L9 regulator nodes. The first test is restricted to 25 MHz and
3.3-V signalling because upstream Linux does not yet contain Lenovo's BH201
redriver/tuning helper. UFS, GPU and native display remain disabled. The DTB
passes the SDHCI, SM8250 pinctrl and RPMh regulator schemas; the complete release and boot image pass their
offline verifiers and have not been booted.

## Next attended test order

`scripts/attended-u-boot-mainline-test.ps1` implements this state machine. Its
`ValidateOnly` action verifies all eight pinned stage-0, payload, vbmeta and
rollback files without querying the tablet. Partition installation, RAM boot
and restoration have separate approval switches. It recognizes Lenovo ABL as
`<serial>` and U-Boot as `TB371FC-UBOOT`; a failed RAM payload that visibly
returns to Lenovo fastboot triggers exact stock restoration.

1. Confirm exact stock `recovery_b` and signed `vbmeta_b` backups and hashes.
2. Stop the V55 session cleanly and enter Lenovo bootloader with a person at
   the tablet.
3. The verified ABL entry probe has passed with a full-screen checkerboard.
   It currently has no USB or software-reboot path; manually return to Lenovo
   fastboot and let the hash-pinned watcher reinstall unchanged V55.
4. With a person present, test the already built U-Boot v4 boundary image.
   Red means execution reached the arm64 `reset` label; held green means it
   reached the first Qualcomm board callback. Manually return to Lenovo
   fastboot after either result and reinstall unchanged V55. A later U-Boot
   build may proceed to USB only after this boundary is identified.
5. Download/boot the stage0 payload in RAM. Prove Linux 7.1.8 execution and a
   USB rescue channel before any native-display payload.
6. Re-enter U-Boot and RAM-boot profile `arch-microsd`. Require SDHCI2,
   microSD, loop-ext4, USB rescue and Arch SSH before enabling any DRM path.
7. Re-enter U-Boot and RAM-boot profile `display-gated` only after the Arch
   handoff result is captured. Require USB and DRM probe state before manually
   starting one 120-Hz checker modeset while rescue and rollback remain
   observable.
8. Restore exact stock `recovery_b` first and signed `vbmeta_b` second, verify
   hashes, then return to Android.

No unattended flash, reboot, DRM modeset or Plasma launch is authorized by
the existence of these files.
