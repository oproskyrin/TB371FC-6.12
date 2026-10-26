# TB371FC temporary boot and recovery

The first hardware test uses a purpose-built diagnostic environment, not the
final desktop installation. It contains Linux 7.1.8, a static BusyBox shell,
the required early-boot modules and firmware, and the static `input-monitor`
utility. It does not start a graphical desktop, mount Android partitions or
write persistent storage.

The same image now carries the common `r8152`, `ax88179_178a` and `cdc_ether`
USB-Ethernet drivers plus BusyBox `lsusb`, `ip` and `udhcpc`. It records dock
USB IDs, link state, Type-C and DRM state in `/run/tb371fc-report.txt`. DHCP is
manual and never starts merely because a dock is connected.

The normal board DTB keeps native panel and Novatek touch disabled. The test
image uses `sm8250-lenovo-tb371fc-touch-test.dtb`, which differs only by its
model string and by enabling QUPv3 SE14 plus the Novatek NT36532 child. Native
DSI remains disabled, so the test continues to rely on the bootloader-provided
framebuffer while probing touch and AP500U.

The initramfs also attempts to expose a transient USB CDC-ACM serial console.
If the DWC3 controller reaches device mode, the connected host should see a
`TB371FC diagnostic console` COM device with a root shell. Failure to create
that interface is non-fatal and does not write persistent storage.

## RAM-boot probe result

The approved non-writing probe was performed on 2026-08-10. The bootloader
accepted the 77,361,152-byte image transfer, then returned:

```text
Sending 'boot.img' (75548 KB) OKAY
Booting FAILED (remote: 'unknown command')
```

The kernel never executed. No partition was written, `fastboot reboot`
returned the tablet to ZUI 16.0.474, and Android completed boot on slot `_b`.
Bootloader variables also report slot A as `unbootable:yes`; it must not be
used as a disposable test slot.

`scripts/temporary-boot.ps1` now performs the read-only preflight only and
rejects `-ExecuteTemporaryBoot` before rebooting the tablet. Do not retry
`fastboot boot` and do not replace it with `fastboot flash`.

## Observed launch constraints

The earlier TB371FC desktop-Linux wiki uses `/dev/sda6` (`super`) as the Linux
root filesystem and expects a repacked `boot.img`. That is a persistent
conversion which replaces Android's dynamic-partition container; it is not a
temporary test method and will not be copied into this port's first-boot flow.

The stock GPT also contains A/B `vm-linux` (32 MiB) and `vm-system` (128 MiB)
partitions, plus Qualcomm/OEM multi-image partitions. Their names and sizes do
not establish that Lenovo ABL exposes a user-selectable Linux boot path, and
stock Android shows no userspace service for launching one. The EDL readback
later proved all of those VM and multi-image regions are zero-filled. Treat
them as firmware-owned until their signed image format and boot-selection
mechanism are understood. Do not write them experimentally.

The exact stock firmware and 44 critical device regions have now been saved
through a read-only Firehose path. The original `recovery_b` was restored
successfully after both recovery launch probes without relying on slot A.

## Recovery-boot probe result

Two approved tests temporarily wrote only `recovery_b`. Both images used boot
header v2 and the stock recovery DTBO. The second also reproduced the stock
100 MiB AVB hash-footer structure and passed `avbtool verify_image`. Both
returned to fastboot before the diagnostic CDC-ACM device appeared, after
which the exact EDL backup was restored successfully.

The signed slot-B vbmeta contains an explicit hash descriptor for the stock
recovery payload. Testing a modified or verification-disabled `vbmeta_b` is a
separate two-partition experiment and is not authorized by the recovery-only
procedure.

The separately approved two-partition test was executed on 2026-08-10. The
script verified all four pinned artifacts, changed only `recovery_b` and
`vbmeta_b`, and requested recovery boot with AVB verification disabled. The
tablet again returned to fastboot before the Linux CDC-ACM gadget enumerated.
The monitor immediately restored the exact EDL `recovery_b` backup followed by
the signed `vbmeta_b` backup, and fastboot reported both writes successful.
The next reboot entered stock recovery with secure, unauthorized ADB instead
of Android; exiting that stock UI requires `Reboot system now` or a power-key
restart. No further partition write is required for that exit.

This result disproves the narrow hypothesis that the signed `vbmeta_b`
recovery hash descriptor was the only rejection. Do not repeat either
recovery launch image. The next launch investigation must compare ABL's image
acceptance requirements and the complete stock recovery container before any
new on-device write.

Offline comparison found a concrete DT handoff defect in both rejected
images. Their `recovery_dtbo` was copied from ZUI and selects the stock Kona
QRD overlay (`qcom,board-id = <0xb 0>`). Applying that downstream overlay to
the complete mainline TB371FC DTB reproducibly fails with
`FDT_ERR_NOTFOUND`, because its downstream symbol targets do not exist in the
mainline tree. This is consistent with ABL returning to fastboot before the
kernel or Linux USB gadget starts.

The replacement recovery DTBO contains one matching, deliberately empty
overlay. It applies successfully and leaves the mainline DTB byte-identical.
The Android DT table header, board ID, AVB footer and every boot component
have been checked offline. The resulting unapproved artifact is stored at
`D:\TB371FC-builds\diagnostic-7.1.8-v2\tb371fc-mainline-dtbo-test-recovery-7.1.8.img`,
size 104,857,600 bytes, SHA-256
`625e5d115e5e002668858adfc6f45a8bf93d58b115eb192f7310d213f772d099`.
Its separately approved launch on 2026-08-10 again returned to fastboot before
Linux USB enumeration. The monitor restored the exact stock `recovery_b` and
signed `vbmeta_b` backups, and all four fastboot writes reported `OKAY`. The
image has been removed from the allowlist and must not be launched again.

This result disproves the incompatible stock overlay as the only launch
blocker. The next investigation must compare the kernel compression/placement,
boot-header fields, recovery container layout and ABL authentication behavior
without another device write.

That comparison found a second concrete format difference. Lenovo's stock
ARM64 kernel starts with a direct branch instruction and has `ARMd` at offset
56. The rejected mainline kernel also has `ARMd` at offset 56, but starts with
the `MZ`/PE-compatible EFI-stub entry generated by `CONFIG_EFI_STUB=y`. ABL
may reject that entry before transferring control. Android recovery does not
need EFI, so the TB371FC fragment now disables `CONFIG_EFI`.

An isolated Linux 7.1.7 proof build without EFI completed successfully. Its
52,099,080-byte `Image` starts with normal ARM64 `NOP + branch`, has `ARMd` at
offset 56 and SHA-256
`d68cfffde43c58d18ae1ab03feb0df58677c3a4977c4da5e77c0d9543b0a060c`.
This established the format change before rebuilding the current kernel.

A clean Linux 7.1.8 no-EFI build then produced a matching 52,099,080-byte
kernel and 1,556 stripped modules. Its new 18,214,626-byte initramfs includes
the diagnostic USB console, Ethernet modules, Novatek touch/AP500U module,
BOE/Tianma firmware and QCA6390 firmware. The resulting recovery image is:

- path: `D:\TB371FC-builds\diagnostic-7.1.8-noefi\tb371fc-noefi-dtbo-test-recovery-7.1.8.img`;
- size: 104,857,600 bytes;
- SHA-256: `d30579790cf8aaaf34bc1b44cfc62855ff1d4198c18aca7b865561e54b406512`.

Fresh unpacking matched the kernel, ramdisk, DTB and 359-byte recovery DTBO
byte-for-byte, and `avbtool verify_image` validated both footer/vbmeta and the
recovery hash descriptor. The user separately authorized a reversible launch
after these checks; this did not authorize permanent installation.

The no-EFI recovery was launched after a final live preflight on 2026-08-10.
It also returned to fastboot before Linux USB enumeration. The monitor restored
the exact stock recovery and signed vbmeta backups; all writes and the final
reboot reported `OKAY`. The image was immediately removed from the allowlist.
Therefore neither the recovery overlay nor EFI-stub entry explains the entire
early ABL rejection.

## Successful stock-kernel control boot

A separately authorized control image retained Lenovo's exact stock 4.19
kernel, concatenated stock recovery DTB set and stock recovery DTBO, replacing
only the Android ramdisk with this project's Linux diagnostic initramfs. The
104,857,600-byte AVB recovery image is stored outside Git at
`D:\TB371FC-builds\diagnostic-stock-kernel\tb371fc-stock-kernel-ncm-diag-recovery.img`
with SHA-256
`9106312de095b6029b7b9efc1345cb9736649406ae4ad2c52b98af5ae9155d56`.

This image booted Linux on the tablet. Windows enumerated USB ID
`05c6:f626` as `UsbNcm Host Device`, created an up NCM network adapter and did
not return to fastboot. This is direct runtime proof that the recovery-v2/AVB
container, recovery boot route, stock DTB/DTBO handoff and diagnostic Linux
userspace work. It narrows the failed 7.1.8 tests to mainline kernel/DT early
bring-up. It does not establish support for the display, Wi-Fi, stylus or any
other peripheral, because the control still uses Lenovo's 4.19 kernel.

The first NCM build used `192.168.77.2/24`; Windows required administrator
rights to assign the matching host address, so no shell transcript was
captured. New diagnostic initramfs builds use `169.254.77.2/16`, which is on
the Windows adapter's automatic link-local route. After the observed boot the
user forced fastboot, and the reviewed restore action wrote the exact stock
`recovery_b` first and signed `vbmeta_b` second. Both writes and reboot
reported `OKAY`; Android then reported `sys.boot_completed=1`, slot `_b` and
ZUI 16.0.474. No test changed `boot_b`, `super` or userdata.

## Successful rebuilt-downstream kernel boot

The public lineage source commit
`9d8abebf4ac4d45cf4cc11b5b6bc5e4483d10fd1` was built with the exact compiler
family from its workflow. The resulting `4.19.325-cip134-st18-perf+` Image is
48,416,784 bytes, SHA-256
`3ab314e2fd99cb68fad5f3d77a8cf18adbed625a463c35295c119034b99cb86e`.
It was packaged with the proven NCM initramfs, stock concatenated DTB and stock
recovery DTBO. The complete recovery SHA-256 is
`1bd81ac7e53d13c44e64c500fee730a65b8edbd1dbb656b8a858b31430399f33`.
Fresh unpacking and AVB verification passed before the authorized launch.

The tablet booted Linux and Windows detected `USB\VID_1D6B&PID_0105`, an up
`UsbNcm Host Device` at 426 Mbps. The expected TCP listener at
`169.254.77.2:2323` was unreachable, so no `dmesg` transcript was collected.
The USB gadget nevertheless proves execution beyond the rebuilt kernel entry
and into the diagnostic initramfs. It does not prove any production peripheral.

The first forced-fastboot appearance was transient and returned to Linux before
the restore script could write. A second attempt immediately issued `fastboot
reboot bootloader`, stabilizing the bootloader. The reviewed restore then wrote
the exact stock `recovery_b` first and signed `vbmeta_b` second; all transfers,
writes and reboot reported `OKAY`. Authorized ADB confirmed
`sys.boot_completed=1`, slot `_b`, TB371FC, ZUI 16.0.474, unlocked state and
AVB `orange`. The recovery hash is not allowlisted for another launch.

## Prepared mainline stage-0 test

The successful stock-kernel control isolated the remaining failure to
mainline kernel/DT bring-up. The previous command line used Lenovo's downstream
`earlycon=msm_geni_serial,0xa90000`, but Linux 7.1 exposes the upstream GENI
early console as `qcom_geni`. Stock DT analysis also identifies its `serial0`
as QUPv3 SE2 at `0x988000`. The new image therefore uses
`earlycon=qcom_geni,0x988000`, enables the corresponding upstream `uart2` node
and keeps its boot console active with `keep_bootcon ignore_loglevel`.

`sm8250-lenovo-tb371fc-stage0.dtb` is a deliberately separate diagnostic DTB.
It uses the upstream SM8250 HDK power map, matches the active Kona v2.1 ID,
enables only the real debug UART and primary USB controller, forces DWC3 into
peripheral mode, and disables GPU, UFS, Venus and USB2. It is not an install
DTB and cannot replace the normal TB371FC description.

The clean stage-0 artifacts are stored outside Git at
`D:\TB371FC-builds\diagnostic-7.1.8-stage0`:

- Linux 7.1.8 `Image`: 52,099,080 bytes, SHA-256
  `781ebe43f91fc7e7599b840f06945c6ef5a50d8964a9f63f8d2ca6c1a3ff8ad3`;
- stage-0 DTB: 119,844 bytes, SHA-256
  `56a1af1b5466b380d2382cac947171bca5f90629f16151d18040fee6c1184d1d`;
- link-local diagnostic initramfs: SHA-256
  `abd9ff2ea567dfc34a7a8403342f2155b6202799c1f8efb4730646585a8b7ec0`;
- complete recovery image: 104,857,600 bytes, SHA-256
  `340ba80c245dbe3f1c7cfe12ba2ed7f481dc69a1a0b805a856589fceb1ed4e0a`.

The ARM64 image has a direct `NOP + branch` entry and `ARMd` magic; EFI and
KASLR are disabled, while panic-on-oops is enabled. Independent unpacking
matched kernel, initramfs, DTB and the 359-byte empty board-`0xb` DTBO
byte-for-byte. Applying that overlay to the stage-0 DTB leaves its SHA-256
unchanged. `avbtool verify_image` validates the complete recovery footer and
hash descriptor. The exact image hash is in the two-partition test allowlist,
but this preparation and allowlisting do not themselves authorize a launch.

The read-only live preflight passed on the connected tablet: exact test and
backup hashes matched, Android was on the sole working slot B, the bootloader
was unlocked and the battery reported 100%. Preflight performed no reboot and
no partition write. Launch remains a separate explicit action.

The user then explicitly authorized this exact stage-0 launch. Fastboot
accepted both temporary writes and the recovery reboot, but the tablet again
returned to fastboot before Linux USB enumeration. The monitor immediately
restored the exact stock `recovery_b` followed by signed `vbmeta_b`; every
write and the final reboot reported `OKAY`. The reboot entered stock recovery;
after `Reboot system now`, Android returned with authorized ADB,
`sys.boot_completed=1`, slot `_b`, ZUI 16.0.474, unlocked state and AVB state
`orange`. The stage-0 image was removed from the launch allowlist and must not
be repeated.

This result is narrower than the earlier full-DTS failures: removing GPU,
UFS, video, the second USB controller, Type-C role policy and almost all
TB371FC-specific devices did not change the pre-USB return to fastboot. The
correct upstream earlycon cannot be observed over the normal USB cable because
the debug UART is a separate serial engine. The next investigation should not
add peripherals. It must determine whether mainline reaches its first ARM64
instructions, using a persistent pre-console signal or a kernel/container
comparison against the successful Lenovo 4.19 control.

### Isolated ARM64 text-offset test

The successful Lenovo 4.19 kernel header reports `text_offset=0x80000`; the
failed mainline 7.1.8 stage-0 kernel reports `text_offset=0x0`. Both report
flags `0xa` and valid `ARMd` magic. The ARM64 boot protocol permits placement
at the advertised offset, and Lenovo ABL may preserve the legacy expectation.

`scripts/make-arm64-text-offset-image.py` refuses non-ARM64 input, a non-zero
source offset, reserved-header data and an existing output. It created
`D:\TB371FC-builds\diagnostic-7.1.8-text-offset\Image-text-offset-0x80000`
by changing only byte `0x0a`; its SHA-256 is
`aec2ef9ce9d13bebd433e85165a9cd0b1506dde746f339b0a25b4b55c0416da5`.

The corresponding recovery is
`D:\TB371FC-builds\diagnostic-7.1.8-text-offset\tb371fc-stage0-text-offset-recovery-7.1.8.img`:

- size: 104,857,600 bytes;
- SHA-256: `95bfe39f9ee6c37e9c6c09ed19ea8d25947d6081e796f8032128f344458d1db7`;
- same stage-0 DTB, link-local initramfs and 359-byte empty board-`0xb` DTBO;
- independent component comparison and `avbtool verify_image` passed.

This was a one-variable diagnostic image, not an installation image. Its
read-only preflight passed with all five pinned hashes, slot B, unlocked state
and 100% battery. The separately authorized launch wrote only `recovery_b` and
`vbmeta_b`, but the tablet returned to fastboot before Linux USB enumeration.
The monitor restored exact stock recovery first and signed vbmeta second; all
writes and the reboot reported `OKAY`. Android subsequently reported
`sys.boot_completed=1`, slot `_b`, ZUI 16.0.474, unlocked state and AVB state
`orange`. The image was removed from the allowlist and must not be repeated.

The unchanged result shows that advertising Lenovo's legacy `text_offset`
alone is insufficient. Investigation returns to the actual initial instruction
layout, ABL handoff state and the earliest mainline entry path.

### Built-in Qualcomm watchdog test

The text-offset and earlier stage-0 launches returned to fastboot about 15
seconds after the recovery request. Because the previous kernel had
`CONFIG_QCOM_WDT=m`, a clean one-variable config rebuild used
`CONFIG_QCOM_WDT=y`. `System.map` contains `qcom_wdt_probe` and
`qcom_wdt_start`, and `modules.builtin` identifies the driver as built in.

- Image SHA-256:
  `c668995b81cbb63eaa29d9ba127b66fc233b38443ce2e0f5e8a5052f388385a6`;
- unchanged stage-0 DTB SHA-256:
  `56a1af1b5466b380d2382cac947171bca5f90629f16151d18040fee6c1184d1d`;
- complete recovery SHA-256:
  `6a86facc8f1447e22e6a0f2e0c5c9aa5e8d8141c816a671c75583afa6764110c`.

Independent unpacking matched kernel, initramfs, DTB and empty DTBO
byte-for-byte, and AVB verification passed. The authorized launch still
returned to fastboot after about 15 seconds and before Linux USB. Automatic
rollback restored exact stock recovery and signed vbmeta with all writes
reported `OKAY`; Android then completed boot on slot `_b`. The image was
removed from the allowlist. A missing early Qualcomm watchdog driver is not the
sole cause of the reset timing.

### Pre-MMU continuous-splash marker test

The diagnostic-only config option `CONFIG_TB371FC_EARLY_FB_MARKER` executes at
the first common ARM64 `primary_entry`. Before MMU setup it fills the first
8 MiB of Lenovo's stock `cont_splash_region@9c000000` with `0xffff00ff`, issues
`dsb sy`, preserves the DTB pointer in `x0`, then continues the normal entry
path. Disassembly was checked instruction-by-instruction before packaging.

- Image SHA-256:
  `ce896b90a363ce9d34d6224bdd1548c8f2a56948148f81f004c167f6a9f74ca9`;
- recovery SHA-256:
  `abdbfe804ee991ff58f47a3842a025907614309310c67f28a2315856c79a8a2e`.

Independent component comparison and AVB verification passed. The authorized
test returned to fastboot after approximately 15 seconds and before Linux USB;
automatic rollback restored exact stock recovery/vbmeta and Android completed
boot on slot `_b`. The image was removed from the allowlist. A visible magenta
fill would prove entry into `primary_entry`; no host-side signal can substitute
for that observation because ABL may disable display scanout before handoff.

### Android return verification

The tablet previously enumerated as `<serial> unauthorized` in stock recovery,
where secure recovery ADB would not accept `adb reboot`. The user selected
`Reboot system now` on 2026-08-10. Android then returned normally and ADB
reported `device`, `sys.boot_completed=1`, ZUI 16.0.474, Android 14, active
slot `_b`, unlocked device state and verified-boot state `orange`. Battery was
100% and charging during the read-only check. This confirms the operational
return to Android; it does not authorize another launch.

The corrected artifact is a first-stage diagnostic Linux image. A successful
boot proves the kernel/DT/initramfs handoff and provides logs; it does not by
itself prove that the complete Arch rootfs, Plasma or every peripheral works.

After the latest stage-0 rollback, Android booted successfully and authorized
ADB confirmed `sys.boot_completed=1`, slot `_b`, ZUI 16.0.474, unlocked state
and AVB state `orange`. No experimental image remains intentionally installed.

The current 7.1.8 dock-and-touch recovery image is stored outside Git at
`D:\TB371FC-builds\diagnostic-7.1.8\tb371fc-dock-touch-test-recovery-7.1.8.img`
with SHA-256
`7f5d22a3300a585b4f3f4fccff41615f158879f5fec7ed173b704cd8fa529825`.
Both temporary recovery scripts accept it through `-RecoveryImage`, but only
because that exact hash is compiled into their allowlist. An arbitrary path or
arbitrary hash remains rejected.

Read-only two-partition preflight example for when the tablet is present and
ADB-authorized:

```powershell
.\scripts\temporary-vbmeta-recovery-test.ps1 \
  -Action Preflight \
  -PlatformToolsDir 'C:\path\to\platform-tools' \
  -RecoveryImage 'D:\TB371FC-builds\diagnostic-7.1.8\tb371fc-dock-touch-test-recovery-7.1.8.img'
```

`Preflight` performs no reboot and no write. `Launch` remains separately gated
by `-TwoPartitionWriteApproved` and PowerShell's high-impact confirmation.

## Test contract for a future supported launch route

Before booting:

1. Confirm that `adb devices` identifies the expected tablet.
2. Record the active Android slot and current bootloader variables.
3. Verify the boot-image SHA-256 against `MAINLINE_STATUS.md`.
4. Confirm that the reviewed launch method has a verified rollback path and
   changes only the explicitly approved partitions on the sole good slot B.

Read-only ADB baseline captured on 2026-08-10: device `TB371FC`, ZUI
`16.0.474`, active slot `_b`, `ro.boot.flash.locked=0`, verified-boot state
`orange`. Re-check these values immediately before the test rather than
assuming the recorded slot is still current.

The complete offline check can be repeated with
`scripts/verify-diagnostic-boot.sh`; it unpacks the image, compares every
component byte-for-byte and confirms that the AP500U module, both firmware
files and `input-monitor` are present.

On the Windows host, `scripts/temporary-boot.ps1` performs the image preflight.
Without `-ExecuteTemporaryBoot` it is strictly read-only: it checks the image
magic, size and pinned SHA-256, finds exactly one authorized TB371FC, then
records its build, slot and bootloader state. The legacy execution flag now
stops with an explanation before any reboot or fastboot operation.

Read-only example:

```powershell
.\scripts\temporary-boot.ps1 -PlatformToolsDir 'C:\path\to\platform-tools'
```

Once a different launch route is researched, backed up and separately
approved, the diagnostic image must show or record:

1. kernel start and the exact TB371FC model;
2. NT36532 chip ID, single/cascade selection, GPIO82 panel ID and selected
   BOE/Tianma `_6` firmware;
3. `NVTCapacitiveTouchScreen` and `NVTCapacitivePen` input devices;
4. ten-finger coordinates and edge coverage;
5. AP500U hover, pressure, tilt and both barrel buttons;
6. dock USB enumeration and Ethernet link without automatically configuring
   the network;
7. a clean power-off or reboot back to Android.

If the screen stays black, check the host for the CDC-ACM COM device before
forcing a reboot. This provides live logs without guessing a reserved-memory
address for ramoops.

Run `input-monitor` in the emergency shell to list event devices, then run
`input-monitor /dev/input/eventN` for the Novatek pen or touchscreen.

## Recovery and rollback

The failed `fastboot boot` probe did not replace any partition. The first two
recovery probes replaced only `recovery_b`, then restored its exact 100 MiB
backup. The separately approved third probe temporarily replaced both
`recovery_b` and `vbmeta_b`; the monitor restored the exact recovery backup
and signed vbmeta backup, and fastboot reported both writes successful.
No test changed `boot_a`, `boot_b`, `super` or userdata. The NT36532 is a
no-flash controller; its runtime firmware is also lost on controller reset or
power removal.

The size-constrained and direct-entry stage-0 tests on 2026-08-10 followed the
same two-partition contract. Both returned to fastboot before Linux USB and
triggered automatic rollback. The second test changed only the ARM64
`code0`/`code1` entry layout while preserving its branch target. After the
final rollback, ADB confirmed `sys.boot_completed=1`, slot `_b`, ZUI 16.0.474,
AVB `orange` and unlocked state. Both experimental hashes are absent from the
allowlist and must not be launched again without a new review.

A following combined test retained the minimal direct-entry layout and changed
only `text_offset` from zero to `0x80000`. It returned to fastboot before Linux
USB after about 8.6 seconds of host observation. Rollback and Android checks
again succeeded; recovery SHA-256
`8dbb06d28dc97d736510393782511fd914212044e9044e5e23451d212a044d47`
is not allowlisted and must not be repeated.

## Published 4.19.325 firmware runtime test (2026-08-10)

The rebuilt published downstream kernel was repackaged with the locally
extracted Lenovo firmware and a persistent USB-NCM diagnostic shell. Recovery
SHA-256 was
`12439d92fd29c34a1456df0ba433dddaa411e352eb815f4254ed39c3c32d1660`;
the initramfs SHA-256 was
`65216320af8c9d3b9f55837407656c57c65d4900874b9c931297e0fcf20dcccb`.
Both are test artifacts outside Git and the recovery hash was removed from the
launch allowlist after rollback.

Observed on the physical TB371FC:

- Linux `4.19.325-cip134-st18-perf+` booted repeatedly and exposed a stable
  shell at `169.254.77.2:2323` over USB NCM.
- UFS, a 119 GiB microSD card, DSI-1, DP-1, Type-C port/partner and USB gadget
  mode enumerated. The internal panel exposed 2944x1840 at 30, 60 and 120 Hz;
  this test did not expose 140 or 144 Hz.
- GPIO82 selected Tianma, the cascade NT36532 was identified,
  `novatek_ts_tm_fw_6.bin` loaded, firmware update completed, and Linux created
  `NVTCapacitiveTouchScreen` plus `NVTCapacitivePen`. AP500U event quality,
  pressure, tilt and buttons remain unverified without user interaction.
- QCA6390 PCIe device `17cb:1101` enumerated and requested
  `qca6390/amss20.bin`. Creating the vendor state node at `/dev/wlan` and
  writing the exact three bytes `ON\n` caused a kernel restart after about
  21 seconds. No second activation attempt was made. The platform has no
  pstore backend, so no persistent panic record was available.
- The Type-C power supply was online and the battery reported charging, but
  the external fuel gauge failed with `exfg not found`; SOC values in this
  diagnostic Linux are invalid. Bluetooth core initialized without an HCI and
  ALSA reported no sound cards.

Evidence is preserved in `diagnostics/vendor-4.19.325-*-20260810.txt`, notably
the full dmesg, subsystem, power/display, firmware-runtime and exact WLAN
activation captures. An embedded one-shot recovery-only module safely invoked
`kernel_restart("bootloader")`; fastboot then restored the exact EDL backups of
`recovery_b` and `vbmeta_b`. Android subsequently completed boot on slot `_b`
with ZUI 16.0.474 and expected AVB state `orange`.

## Safe QCA6390 firmware-start test (2026-08-11)

The next bridge build added all 28 exact stock `qca6390/bdwlan.*` files and
enabled `CONFIG_CNSS2_DIAGNOSTIC_NO_SSR=y`. Its diagnostic failure worker
captures the CNSS failure, powers WLAN down and deliberately suppresses the
normal subsystem restart, preventing a WLAN timeout from restarting the whole
tablet. The recovery SHA-256 was
`4bad062a9d301557aa2d326046bf9da5dc19bb081b44fb99c368272d09f7387c`;
the initramfs SHA-256 was
`b2624ea56f6e6b756cdd1320b1b3177f666c2513f0e412b17fa03cf376ee832e`.

One exact `ON\n` request advanced QCA6390 through PCI resume, MHI INIT,
POWER_ON and MISSION_MODE. LOOPBACK, DIAG and IPCR MHI channels probed, but
CNSS timed out after 20 seconds waiting for `FW_READY`. The diagnostic worker
then powered WLAN off without restarting Linux; the NCM shell and system
uptime remained available. No `wlan0` appeared.

This places the failure before board-data selection, so the BDF files were not
the immediate blocker. The minimal userspace had no `qrtr-ns` process,
`/proc/net/qrtr` or QRTR device/socket node even though the MHI IPCR channel
was present. The next controlled build must add and verify the QRTR/QMI name
service before another WLAN activation. Evidence is in
`diagnostics/vendor-4.19.325-wlan-safe-*-20260811.txt`.

For this old kernel, use the userspace name service from upstream QRTR tag
`v1.1`, pinned to commit
`8f9b2bc3b60f59ecc9e6193764fa885cdef7f0ce`. Build it with
`scripts/build-static-qrtr-ns.sh` and pass the resulting static AArch64 binary
as the optional fifth argument to
`scripts/inject-vendor-firmware-initramfs.sh`. It is intentionally included
without automatic startup: first run `qrtr-ns -f -v` from the NCM shell and
capture QRTR service announcements, then perform at most one separately
reviewed `ON\n` request.

The first offline QRTR diagnostic artifact is ready outside Git. The static
`qrtr-ns` SHA-256 is
`8b55cb89b91c02229996a53fbb65b4552a2e6c696926c68e362c5b280821ef1f`,
the initramfs SHA-256 is
`df8899af2d1db619aa16ee27ddab97e2f5cdc0389ffbbeecdc6fee0b99f67a89`,
and the 100 MiB recovery SHA-256 is
`c03683a4990ceae4397230ea6780767a544b6446378a261a1a31da62d0780a3b`.
Offline unpacking matched the kernel, ramdisk, stock concatenated DTB and
stock recovery DTBO byte-for-byte and verified the AVB NONE footer. This new
hash is not launch-allowlisted; do not add it or write it until the previous
rollback has been fully closed through authorized Android property checks.

An expanded unattended-session variant additionally contains static
`qrtr-lookup`, passive whole-device snapshots, bounded input-event capture and
QRTR start/stop helpers. Its initramfs SHA-256 is
`2e4f7999148279bd8da817a5b1839acd4e2ba9742523bc847911e7376d931e45`;
its 100 MiB recovery SHA-256 is
`b919da167ff2fe9e6b10cda0533ff018433c4aea483c0524da3e88ec1bd3ab8f`.
Offline AVB verification and byte-for-byte payload comparisons succeeded.
This recovery is also intentionally absent from the launch allowlist. See
`REMOTE_TESTING.md` for the long-test order and the expected physical reboot
limitation after restoring stock Recovery.

The final v2 unattended image adds incremental host-side log flushing plus
token-gated, per-boot single WLAN activation and token-gated bootloader exit.
Its initramfs SHA-256 is
`c96513dbd2dcce021e8a161404c8bd0dcd03f5078e86ce314c34b3062ef03bd0`;
its recovery SHA-256 is
`664ac94117ebc46af96f4d230958a8a91bf8b1712ec8cad5d61fa14664e8c7de`.
Offline AVB and byte-for-byte payload verification succeeded. This final hash
also remains absent from the launch allowlist.

The embedded reboot module returned Linux to fastboot. Fastboot reported
`OKAY` while restoring the exact stock `recovery_b` and signed `vbmeta_b`, and
then rebooted. After the owner selected `Reboot system now`, authorized ADB
confirmed `sys.boot_completed=1`, slot `_b`, ZUI 16.0.474, AVB `orange`,
unlocked state and 100% battery. The recovery SHA-256 `4bad062a...` was then
removed from the launch allowlist, fully closing this rollback.

- Normal exit: run `poweroff -f` from the diagnostic shell.
- Kernel hang: hold the tablet power button until it forcibly restarts.
- Fastboot screen: run `fastboot reboot` from the host.
- Failed `fastboot boot`: already recovered; no rollback action was needed
  because no partition was written.

Do not change the active slot, erase a partition, or flash any target outside
the reviewed script. Persistent installation and dual boot remain separate
later stages and require fresh authorization.

## Planned desktop environment

After repeatable temporary boots, the persistent userspace target is Arch
Linux ARM with KDE Plasma on Wayland. Plasma Mobile components can be added
for touch-first use, while the regular Plasma session remains suitable for a
keyboard, stylus and external DisplayPort monitor. No desktop environment is
part of the first diagnostic image.

## Sequence after the first successful diagnostic boot

1. Preserve `dmesg`, boot timing and USB gadget logs before enabling more
   hardware.
2. Verify CPU, RAM, UFS discovery, regulators, battery, thermals and a clean
   shutdown/reboot path.
3. Restore stock `recovery_b` and signed `vbmeta_b`, then confirm Android still
   boots on slot B.
4. Run separate diagnostic builds for native panel modes, touch/AP500U,
   QCA6390 Wi-Fi/Bluetooth, USB-C/DisplayPort and the dock.
5. Bring up audio, sensors and cameras only after the base power and recovery
   paths are repeatable.
6. Boot the minimal Arch rootfs, then start Mesa/Freedreno and Plasma Wayland
   manually. Permanent installation or dual boot remains a later project.

## Final unattended QRTR and hardware test (2026-08-11)

Recovery SHA-256
`664ac94117ebc46af96f4d230958a8a91bf8b1712ec8cad5d61fa14664e8c7de`
booted Linux successfully and exposed stable USB NCM. Baseline and post-test
captures are stored under
`D:\TB371FC-diagnostics\remote-final-20260811`; the corrected automated report
is `session-summary-v2.md`.

Starting upstream userspace `qrtr-ns` exposed local services and WCNSS DIAG
registrations. One exact `ON\n` request then reached MHI MISSION_MODE. QRTR
reported remote node 7, CNSS connected to WLFW at node 7 port 1, registered
for indications and sent host capabilities. This proves the userspace QRTR
name service fixed the earlier missing QMI service-discovery stage. Firmware
still failed to send `FW_READY` within 20 seconds. The diagnostic no-SSR path
captured the timeout, powered WLAN down and kept Linux/NCM alive; uptime
continued beyond 285 seconds, with no panic, SoC restart, storage I/O error or
OOM. `wlan0` did not appear and no second activation was attempted.

The same session reconfirmed 7.49 GiB usable RAM, UFS, a 119 GiB microSD,
2944x1840 panel modes at 30/60/120 Hz, Type-C device/sink operation, normal
post-test thermal readings around 32-37 C, touch and AP500U registration,
Bluetooth power control plus UART transport, and CamX/V4L2 topology. AP500U
event5 opened successfully but no stylus movement occurred during the bounded
capture. DP was not connected, Bluetooth had no `hci0`, ALSA had no sound
card, and active camera streaming was intentionally not attempted.

After all logs were copied, the tested reboot module returned Linux to
fastboot. Exact stock `recovery_b` and signed `vbmeta_b` were restored with
both writes reported `OKAY`, then reboot was requested. After physical
`Reboot system now`, authorized ADB confirmed `sys.boot_completed=1`, slot
`_b`, ZUI 16.0.474, AVB `orange`, unlocked state and 100% battery. The final
test hash was removed from the launch allowlist immediately after rollback;
the rollback is fully closed and the image must not be repeated.

## Prepared single-client QCA6390 and visible-console test

Source tracing narrowed the final WLAN timeout further. Stock DT contains
`cnss-daemon-support`, so CNSS2 sent `num_clients=2`; the final log confirms
`Number of clients is 2`. Stock Android runs both `qrtr-ns -f` and the
proprietary `/vendor/bin/cnss-daemon -n -l`, while the diagnostic initramfs
correctly contained only the upstream QRTR name service. The firmware stopped
after host capability and never emitted REQUEST_MEM. Therefore BDF selection
was not reached.

`vendor-kernel/patches/0002-cnss2-add-single-qmi-client-diagnostic-mode.patch`
adds a bring-up-only Kconfig option which ignores that DT property and lets the
existing in-kernel CNSS2 QMI handlers advertise one client. The kernel already
contains handlers for REQUEST_MEM, RESPOND_MEM, FW_MEM_READY, target
capability, regdb/BDF, M3 and FW_INIT_DONE. No proprietary Android daemon or
its shared-library chain was copied into Linux.

The same build enables debugfs for the existing Qualcomm IPC ring buffers and
MSM DRM fbdev/fbcon. The recovery command line keeps `console=tty0` and selects
`SUN12x22`, so the next test should replace the Lenovo splash with kernel/init
text after DRM initializes. USB NCM remains the recovery console if fbcon does
not bind.

Offline-verified artifacts are stored at
`D:\TB371FC-builds\diagnostic-vendor-4.19.325-single-qmi-fbcon`:

- Image SHA-256: `d7919c2f5a3706f220dea926eaf7c1d3d41c9f774cb4c2bef9523fb6571a5a77`;
- initramfs SHA-256: `9f409d38580ba75aa8dc32ed43030b625ce66b07cc29e91583c6bbd17627fc99`;
- recovery SHA-256: `b628dd2e9c083306200dd30f54dc65e2c50ca129557ce10ba49df6cc2c541ddb`.

Independent unpacking matched the Image, initramfs, stock DTB and stock
recovery DTBO byte-for-byte. AVB NONE verification passed and the image is
exactly 100 MiB. It is not launch-allowlisted and has not been written to the
tablet. The activation helper now refuses to touch `/dev/wlan` unless both
single-client and no-SSR guards are present, and captures CNSS/MHI IPC logs
after its one permitted request.

### Single-client hardware result and stock QCACLD INI follow-up

The authorized single-client test completed the WLFW handshake: one client,
REQUEST_MEM/RESPOND_MEM, FW_MEM_READY, target capability, exact stock
regdb/BDF, M3 and FW_INIT_DONE/FW_READY. MSM fbdev/fbcon also replaced the
retained splash with a 245x83 `tty0` console at 2944x1840. Linux and USB NCM
remained stable.

QCACLD then requested `wlan/qca_cld/WCNSS_qcom_cfg.ini` through the firmware
loader. The missing-file fallback timed out, host-driver probe failed and CNSS
powered WLAN down cleanly. The exact session is stored at
`D:\TB371FC-diagnostics\single-qmi-fbcon-20260811\session-full.txt` (SHA-256
`1cf0584d42b9b7091d36c59f8570e87c194c34328ad016c96c5ec23391dda4a4`).

The follow-up ramdisk contains the exact 8,775-byte stock Android INI at
`/lib/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini`, SHA-256
`ceebfa9bd1226ec748ecf28c5ed5543cb184fd8a55dd34ac1611300903598b17`.
Its guarded helper also captures early and final host-driver, interface,
rfkill, firmware-loader, CNSS/MHI and dmesg state. The test must establish
registration and `wlan0`; it must not scan, associate or activate WLAN twice.
The final recovery is exactly 100 MiB, passed AVB NONE and byte-for-byte
component verification, and has SHA-256
`27e37cb6690e6f4e05492924571f83b70c4c03adc96ee8dd55aece1f46527f9a`.

The authorized v3 hardware test succeeded. QCACLD consumed the stock INI,
completed WMI firmware-ready initialization and registered `wlan0`, `p2p0`
and `wifi-aware0`; rfkill `phy0` was unblocked and firmware advertised 11ax.
No scan or association was performed. The optional
`wlan/qca_cld/wlan_mac.bin` request timed out, after which the driver selected
its default MAC and exposed the interfaces. With no userspace client, its
normal idle timer then shut the powered WLAN instance down cleanly.

Full logs are in
`D:\TB371FC-diagnostics\qcacld-ini-success-20260811`; archive SHA-256 is
`df70ffa0d42cd5ec579ebbdbbb9cd024630754f7b9dd43465322ba53c199be6c`.
Exact stock recovery and vbmeta backups were restored with all fastboot writes
reported `OKAY`, and the v3 recovery hash was removed from the launch
allowlist. The next test should package `iw`, bring `wlan0` administratively
up before the idle timeout, inspect regulatory state and perform at most a
passive scan; it must not invent or persist a replacement MAC address.

## Persistent Arch development-loader v3 hardware result

The authorized v3 launch reached the downstream kernel, USB NCM and
`169.254.77.2`; Windows received a `UsbNcm Host Device`, ARP resolved the
tablet and repeated ICMP replies remained below 1 ms with TTL 64. This proves
the v3 block-device checks, exFAT/loop/ext4 handoff and Arch network setup ran.
Neither TCP 2222 nor the initramfs rescue port 2323 remained available. The
loader intentionally stopped the old rescue listener before `switch_root`, so
there was no remote reboot path in that session. After the physical fastboot
entry, the restore script wrote exact stock `recovery_b` first and signed stock
`vbmeta_b` second; every fastboot operation reported `OKAY`.

Offline inspection found that the installed v1 image contains no OpenSSH host
keys and relies on `ssh-keygen -A` during the earliest custom-init stage. The
schema-2 image now pre-generates per-image RSA, ECDSA, Ed25519 and hybrid host
keys and passes `sshd -t`; its SHA-256 is
`874aefbc65f176c94ad4e7dc7636993fd6d7f8b0bed8b77fee17da7d6609594e`.
Loader v4 keeps a BusyBox shell on port 2323 after `switch_root`, starts PID 1
through that static BusyBox, and writes SSH key/config diagnostics before the
daemon starts. Its verified recovery SHA-256 is
`0ae2b9a7929a1d8f75090ffbcfa4614540cf084bb067c58719f6241890eb5c4a`.
It is not allowlisted and has not been written. Android subsequently reached
`sys.boot_completed=1` on slot B with ZUI 16.0.474, AVB orange, unlocked state
and 99% AC-powered battery. The v3 hash was removed from the launch allowlist,
so that test and rollback are fully closed.

## Development-loader v4 NCM failure and prepared v7

Schema 2 was copied to microSD, verified there as exactly 6 GiB with SHA-256
`874aefbc65f176c94ad4e7dc7636993fd6d7f8b0bed8b77fee17da7d6609594e`,
and atomically selected. The runtime-modified schema-1 file was preserved as
`tb371fc-arch-development.schema1-backup.raw`, SHA-256
`865b3fe6900063f47536d3760a2088b4a117e2e02649007b011e5b9fda4c24ef`.

The authorized v4 launch enumerated the Linux CDC NCM gadget, but the tablet
never answered ARP, IPv4, IPv6 all-nodes multicast or broadcast traffic. Ports
2323 and 2222 remained unreachable. Cable reconnection, a Windows NCM-adapter
restart and a USB composite-device PnP reset did not change the state; none of
those operations rebooted the tablet. Offline extraction proved the v3 and v4
early init, NCM setup script, BusyBox and applet links are byte-identical. This
is consistent with `usb0` existing too late or remaining administratively down
without any surviving command channel. The tablet was intentionally left
running; stock rollback remains pending until a separately permitted reboot.

The unlaunched v5 prototype extended the `usb0` wait and moved the original
`/run` tmpfs through `switch_root`. Review then found that a listener process
created before `switch_root` can retain the old process root even when its
mount is moved, so v5 was superseded without being allowlisted or written.

Loader v7 uses stable locally-administered NCM MAC addresses, waits up to 60
seconds for `usb0`, makes a missing netdev a hard rescue stop and continuously
reapplies `169.254.77.2/16` plus `UP` through static BusyBox. After moving
`/run`, it terminates the old-root listener, creates a replacement already
chrooted into Arch, checks that PID is alive, and only then moves `/dev`,
`/proc`, `/sys` and calls `switch_root`. The Arch runtime adopts that exact PID
and runs a second network watchdog.

Automated checks validated shell syntax, required BusyBox applets and critical
operation ordering. A real ARM64 BusyBox listener was launched in a disposable
chroot and successfully executed a command over TCP. The schema-2 image passed
`e2fsck`, AArch64 chroot, pacman/systemd checks, host-key validation and
`sshd -t`.

An additional packaging audit found that v4-v6 used the stock 4.19.157 kernel
despite the Arch marker and return module targeting 4.19.325. Those candidates
are superseded without another launch. V7 pairs the corrected initramfs with
the exact 4.19.325 fbcon kernel that already displayed a 2944x1840 `tty0` on
this tablet. Kernel config checks require VT, VT console, DRM fbdev emulation,
fbcon and primary-console detection. The init creates a guarded `4:0` tty0
node when devtmpfs is absent and prints visible stage markers before Arch
starts its auto-login console.

Recovery v7 is exactly 100 MiB, passed AVB NONE and byte-for-byte
Image/initramfs/DTB/recovery-DTBO verification. SHA-256 values are:

- kernel: `d7919c2f5a3706f220dea926eaf7c1d3d41c9f774cb4c2bef9523fb6571a5a77`;
- initramfs: `64943db6c06e3d721516d35c752592173d6816ad3453c3d58deeefa717797374`;
- recovery: `8ad42e997216ddce47c4d679207eb04384530fa6feb060f5c3e3375c9975ac53`.

V7 is not allowlisted and has not been written to the tablet. The current v4
session must be returned to fastboot and exact stock backups restored before a
separately authorized v7 launch.

## Development-loader v8 live Arch and KMS result

The 2026-08-11 v8 session booted the hardware-proven
`4.19.325-cip134-st18-perf+` kernel, configured stable USB NCM, mounted the
schema-2 ext4 image from microSD and exposed an Arch-root shell on transition
port 2324. A manually started Arch runtime brought up OpenSSH 10.4 on port
2222 and accepted the pinned Ed25519 client key.

The automatic handoff stopped safely before `switch_root`. The early rescue
PID file contained a parent-shell PID while the actual `nc` child retained
port 2323. V10 fixes this by exec-replacing the listener process and using
separate transition port 2324 before starting a fresh Arch-root listener on
2323.

Display inspection found DSI-1 connected but disabled, with 2944x1840 modes at
120, 60 and 30 Hz. Creating `/dev/fb0` and writing fbcon/framebuffer content
did not replace the bootloader splash. A checksum-verified static ARM64 KMS
test created a dumb framebuffer, performed `SETCRTC`, changed DSI-1 to enabled
and visibly replaced the splash with a grey field and green stripe. V10 embeds
that same binary and creates `/dev/dri/card0` only after sysfs confirms device
number `226:0`. The full live snapshot is stored in
`diagnostics/arch-loader-v8-live-kms-20260811.txt`.
# V14 DSI lifecycle hardware result

V13 software screenshots showed complete 2944x1840 Weston output, but the
physical NT36532 panel initially refreshed only one 20-row DSC slice.
Downstream DSI debugfs showed both video engines off with all DSI clocks at
zero. The published source commit used by v13 contains unconditional early
returns in all four DRM bridge panel lifecycle callbacks. The display was
therefore never prepared or enabled by Linux.

Patch `vendor-kernel/patches/0003-display-enable-dsi-bridge-lifecycle.patch`
restores the existing Qualcomm lifecycle code. Kernel build, recovery
packing, independent component comparison, and AVB verification passed.
Recovery SHA-256:
`aaf9b27ab6cbca1a2a0face72a2f84c79f5d3dfddd375a07e5b68769e67856ad`.

The attended v14 boot succeeded and both DSI controllers now report their
control and video engines ON. At 120 Hz both byte clocks are 141250000 Hz,
both pixel clocks are 188333333 Hz, and both escape clocks are 19200000 Hz.
Weston, atomic page flips, legacy page flips and the standalone 2944x1840 KMS
test all run, but the physical panel still retains the bootloader image below
the top approximately 20 rows. The KMS test buffer itself is a full-screen
64x64 checkerboard, so the visible top strip is one DSC slice row rather than
a deliberately narrow test pattern.

Source review after this result found a second continuous-splash bug:
`dsi_display_enable()` cleans up and returns before the normal DSC PPS update.
Patch `vendor-kernel/patches/0004-display-refresh-dsc-pps-after-cont-splash.patch`
sends the Linux-computed PPS during that handoff and logs both panel PPS and
hardware DSC encoder dimensions.

The prepared v15 artifacts are:

- kernel SHA-256:
  `15bb920bad513ae90569e4f7ea4b5b03a29cab6a763708848466c4c2bdbd35f3`;
- recovery SHA-256:
  `782f8bbaee289865a25302808eb4603d2d19fd21d74b40cffd7b4740970c0245`.

Independent unpacking matched the v15 kernel, v13 initramfs, stock DTB and
stock recovery-DTBO byte-for-byte. AVBtool verified the NONE vbmeta and the
recovery hash. V15 booted successfully and logged the expected 2944x1840,
736x20, 8-bpc/8-bpp PPS. It did not repair the physical scanout. CTL routing,
both DSC blocks and both DSI video engines are active, but both interfaces
continuously accumulate underruns at 120 Hz even at a 460 MHz MDP clock and
maximum debug bus vote.

# V16 continuous-splash DSI soft-reset test

The normal DSI prepare path resets the controller state machines after host
enable and link-clock enable. The continuous-splash path skipped that reset,
leaving bootloader FIFO/controller state in place after Linux programmed its
dual-DSI DSC configuration. Patch
`vendor-kernel/patches/0005-display-soft-reset-dsi-during-cont-splash.patch`
executes the same controller-only reset during splash handoff without cycling
panel power, panel reset GPIO or the panel initialization sequence.

Tested artifacts:

- kernel SHA-256:
  `c1cf3b53ccf471061c7dc72f26c5b6165a9dcf75a815920466f9f4be878bbf2a`;
- recovery SHA-256:
  `d3df3b95f6d12ef2f9230da30515588ef86e17d9af7d7d1faffd4338d84b3dcf`.

Independent unpacking matched the intended kernel, v13 initramfs, stock DTB
and recovery-DTBO. The new log marker is present and AVB uses algorithm NONE.
V16 booted Arch and retained USB NCM/SSH/Weston, but controller soft reset did
not repair scanout: the internal panel remained gray or dark with the top
strip corrupted. A live 60 Hz switch failed its atomic commit and was restored
to the original 120 Hz mode.

# V17 send DSC PPS before continuous-splash video

The normal DSI enable path sends DSC PPS before starting video. V15/v16 did
the reverse in their added continuous-splash branch. Patch
`vendor-kernel/patches/0006-display-send-cont-splash-pps-before-video.patch`
moves continuous-splash engine enable after PPS and checks its return code.

Prepared, independently verified and not written:

- kernel SHA-256:
  `768b1afdc851e3a9875725626430a5407c6fab5519eb0228b346aecb0241e48a`;
- recovery SHA-256:
  `561ad47f94960c8a65e2347a624d584ad13f57a3bcc1e2b3de897c7d421c526d`.

Independent unpacking matched the kernel, v13 initramfs, stock DTB and stock
recovery-DTBO byte-for-byte. The new marker is in the packaged kernel and AVB
uses algorithm NONE. Flash/reboot requires a fresh attended authorization.

# V17 result, v13 comparison and rooted Android reference

V17 booted kernel build `#12`, Arch, USB NCM and SSH successfully. The kernel
executed the intended continuous-splash order, but Weston still produced a
gray/dark panel with a corrupted green top strip. Stopping Weston disabled
active scanout; rebinding fbcon and blank/unblank did not recover visible
text. V17 therefore did not repair the dual-DSI/DSC transport.

The exact verified v13 recovery was then retested. A standalone KMS client
should have displayed a dark green checkerboard, but the panel instead showed
a nearly white field with periodic green blocks along the top edge. Linux
reported CRTC 136 split into two 1472x1840 mixers. DSI0 and DSI1 controller
register dumps were byte-identical, while encoder status showed 14 underruns
on each interface and no advancing vsync count on the second interface after
the test client exited. This proves the visible strip is corrupted DSC output,
not a usable top portion of an otherwise correct framebuffer.

Exact stock recovery and signed stock vbmeta were restored in that order.
Android completed boot on slot B. SurfaceFlinger reports the Tianma panel as
2944x1840 video mode, dynamic FPS 30 through 144 Hz, current 120 Hz, HDR,
`LM_Split: true`, and logical mixer size 2944x1840. Linux currently exposes
only 30/60/120 Hz. The 144 Hz Android mode and mixer/topology representation
must be accounted for in the next display investigation.

Rooted Android reference archive v3:

- `D:\TB371FC-diagnostics\android-root-reference-20260811\tb371fc-root-reference-v3.tar.gz`;
- SHA-256 `0f05f716406502bf262aee7f1528d023da87a1f444f6213dc431a6ca53060eae`.

It contains SurfaceFlinger/DisplayManager, HAL/service inventories, camera,
sensor, touch/pen, audio, Wi-Fi, Bluetooth, USB, power and vendor porting
configuration. The stock kernel has no debugfs. SELinux also refused both a
temporary permissive transition and live-policy access to protected
`mipi_reg`; Enforcing remained active. Do not attempt riskier display-HAL
injection on the working Android installation.

# V18 safe dual-DSI/DSC trace image

The stock active DTB plus overlay establishes a two-tile 2944x1840 panel:
each DSI interface carries 1472x1840, topology is `<2 2 2>`, DSC slices are
736x20 at 8 bpc / 8 bpp, and synchronized DCS broadcast is enabled. Existing
Linux logs prove the topology parser already returns two layer mixers, two
compression encoders and two interfaces. The failed v17/v13 comparison instead
showed no VSYNC progress on the second physical interface and underruns on
both.

V18 is built from clean downstream commit
`9d8abebf4ac4d45cf4cc11b5b6bc5e4483d10fd1` with only the two established
CNSS2 diagnostic patches and
`vendor-kernel/patches/0007-display-trace-dual-dsi-dsc-kickoff.patch`.
It deliberately excludes display patches 0003-0006 and retains the v13
continuous-splash behavior. The bounded trace records broadcast mode, tile
mapping, physical encoder interfaces and roles, affected-display masks,
kickoff counters and 2/2/2 DSC dimensions without changing display ordering.

- kernel SHA-256:
  `41545ac5a7cb16e00c3a89586a014bbb487f29fb0e21b0e49573ebbfae3ad407`;
- recovery SHA-256:
  `337ed5b4bea68c957b01cf4ba95a803813df43f69591ee2d6dc79ebb67f108ce`.

The recovery is exactly 100 MiB, uses AVB algorithm NONE, and was independently
unpacked. Kernel, v13 initramfs, stock DTB and stock recovery-DTBO all matched
their selected inputs byte-for-byte. It is allowlisted but has not been
written or booted. An attended launch requires a fresh explicit authorization.

# V18 hardware result

V18 booted and provided Arch/USB-NCM/SSH access. Its bounded trace established
that the driver creates INTF1 master plus INTF2 slave, selects both with
`affected_displays=0x3`, and configures two 1472x1840 mixers for the complete
2944x1840 framebuffer. After controlled KMS commits INTF1 reported 32 VSYNC
and 17 underruns; INTF2 reported zero VSYNC and 17 underruns. Both DSI software
states had `VIDEO_ENGINE=OFF` and zero link clocks. The panel remained
dark/gray with backlight and a corrupted green top strip.

The topology-specific DSC trace was absent. Source review then confirmed a
state-ordering bug: ROI is recorded before DSC setup, video continuous splash
is excluded from setup, and later unchanged-ROI commits return before
programming DSC. Patch 0008 removes only that exclusion. It does not include
display patches 0003-0006 and does not change DSI lifecycle, PPS or panel reset.

The evidence archive is
`D:\TB371FC-diagnostics\v18-20260812\tb371fc-v18-evidence.tar.gz`, SHA-256
`38129e72d74ef06e92f3a54b00f405245266eff069eacbfdd400acc69cef9c72`.
After collection, exact stock recovery and signed vbmeta were restored and
Android completed boot on slot B.

V19 packages patch 0008 on top of the v18 trace baseline. Verified hashes:

- kernel: `83da51fba2393e1e621d20f0b39a23b0aa0ff0c1905c8fad6efa7f0f31b32384`;
- recovery: `baad93ea48260608a73874d16e4564e04719b9232ee1a6f1912612ab4442a0f5`.

Independent unpacking matched the selected kernel, v13 initramfs, stock DTB
and stock recovery-DTBO. AVB verification passed. V19 is allowlisted but has
not been written or booted; it requires a fresh attended authorization.

# V19 and v20 hardware results

V19 booted and executed the missing 2/2/2 DSC setup, but retained the bridge
early returns; both DSI video engines and link clocks therefore remained off.
V20 combined the same DSC fix with the vendor's normal bridge lifecycle and
booted directly from fastboot without an Android round trip.

V20 is the first test with all of these conditions true at once:

- DSC programmed for the full 2944x1840 ROI and both physical interfaces;
- DSI0 and DSI1 control/video engines on;
- matching byte, pixel and escape clocks on both controllers;
- a full-size XR24 plane accepted by KMS at 30 Hz.

The post-commit underrun counters remained stable. The second physical
encoder's software VSYNC count still reads zero, and the held framebuffer
still needs direct visual confirmation. The v20 evidence archive is
`D:\TB371FC-diagnostics\v20-20260812\tb371fc-v20-evidence.tar.gz`, SHA-256
`770df1e85fa49dd0721a0e1437e20a2f9727b82559909a0989673825924c6b6c`.

# V21–V23 controlled panel reinitialization

V21 attempted to bypass continuous splash before the first Linux KMS commit.
That ordering was unsafe: stale bootloader scanout generated SMMU faults and
the DSI PLL path failed with busy/lock errors. V21 is a diagnostic-only failed
branch and must not replace the v20/v23 baseline.

V22 retained the v20 kernel and placed a disable/re-enable cycle in the KMS
test client. Because the cycle was its first commit, the downstream display
driver rejected dynamic mode switching on the first frame and never reached a
valid dual-DSI video state.

V23 adds a gate instead of changing the kernel. Its boot sequence is:

1. commit and hold 2944x1840@120 normally for 10 seconds;
2. verify `VIDEO_ENGINE=ON` independently on DSI0 and DSI1;
3. disable the inherited pipeline through KMS;
4. enable a fresh full-size KMS pipeline;
5. hold the green checkerboard for 86400 seconds.

All five stages completed automatically. Both DSI controllers report their
control and video engines on with identical 141.25 MHz byte, 188.333333 MHz
pixel and 19.2 MHz escape clocks. Encoder counters settled at INTF1
VSYNC/underrun 30/18 and INTF2 0/18 without subsequent growth. Final MISR:
SDE INTF1 `0x42754c43`, SDE INTF2 `0xfefaec69`, DSI0 `0x5bd2f21e`, DSI1
`0x468c1cad`.

Evidence archive:
`D:\TB371FC-diagnostics\v23-20260812\tb371fc-v23-evidence.tar.gz`, SHA-256
`01e09a38e6fa3aab4d5447f7e43293695511d77575146709ec859281ae241c98`.

The hardware path is stable after a complete Linux-controlled cycle, but the
test remains open until the held checkerboard is physically confirmed on the
internal panel. Keep v23 booted and do not restore the stock partitions before
that checkpoint.

# Prepared v24 DSC/PPS trace build

V24 is a non-behavioral PPS trace build made from a separate clean v20 source
baseline. It adds only bounded DSC/PPS and dual-DSI broadcast logging and
reuses the byte-identical v23 initramfs. Failed reset/PPS experiments and the
v21 cold-start patch are excluded.

The final 100 MiB recovery image was independently unpacked. Its kernel,
initramfs, stock concatenated DTB and stock recovery-DTBO matched the packaged
inputs byte-for-byte; AVB algorithm `NONE` and all header sizes were verified.
Recovery SHA-256:
`ba9f185b03d1421a9a06917d83cd3236f90250e9eeaf82b23dd052bbadd8a12f`.

V24 has not been flashed because preserving the active v23 visual checkpoint
is more valuable than collecting the additional trace before physical
observation. See `diagnostics/arch-v24-pps-trace-build-20260812.md`.

## V24 live KTZ8866 result and prepared v25

During the live v24 test, both DSI interfaces, DSC and the native framebuffer
remained active after the physical LCD became dark. Neither external KTZ8866
DT node had a bound driver. A read-only diagnostic module found identical
registers on buses 2 and 4: brightness `0x7ff`, six sinks selected, and
`BL_EN=0x3f`. A bounded write of only the global LED-enable bit produced
`BL_EN=0x7f` on both chips and immediately lit the screen.

V25 adds the synchronized dual-KTZ8866 driver and DSI external-backlight
integration. Its independently verified recovery SHA-256 is
`a4dcdd7ada974f751164e3105e4cd918ccbcb188cac3aa77aac18bbcde3abe9c`.
It is prepared, not flashed. Full evidence and artifact paths are in
`diagnostics/arch-v25-dual-ktz8866-build-20260812.md`.
