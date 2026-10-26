# TB371FC stock recovery and rollback

No experimental partition write is allowed until the device-specific readback
described below exists. The only known-good Android slot is B; bootloader
variables report slot A as unbootable.

## Verified stock package

The exact official package matching the connected tablet is:

- build: `TB371FC_CN_OPEN_USER_Q00028.1_U_ZUI_16.0.474_ST_241129`;
- archive: `TB371_ZUI_16.0.474_Tool.7z`;
- source: Lenovo's `zsk-cdn.lenovows.com` service CDN;
- size: 4,623,185,188 bytes;
- SHA-256: `1a60d59d450268cf1b2e8cbd49b07760f58bb44dda679fe0ee52bfa28b29c6d3`;
- extracted size: 8,870,887,872 bytes, 211 files;
- archive password used by Lenovo Quick Fix: `FC(fv:SknR`.

The archive was tested and extracted successfully with 7-Zip. Run the tracked
auditor after extraction:

```sh
python3 scripts/audit-stock-package.py /path/to/TB371_ZUI_16.0.474_Tool
```

The auditor checks every size and MD5 listed in `image/MD5_DATA.xml`, reports
SHA-256 for critical boot files, checks all six default rawprogram files and
verifies that the launcher preserves `persist`.

## What the official restore actually does

The Lenovo launcher sends `FHLoaderErase.xml`, then uses:

```text
rawprogram0_save_persist1.xml, rawprogram1.xml, rawprogram2.xml,
rawprogram3.xml, rawprogram4.xml, rawprogram5.xml
```

It deliberately leaves `persist` untouched and finishes with
`--setactivepartition=1`, selecting slot A. The package writes a complete
slot-A boot chain and the shared `super` container; many B-slot entries are
left empty. Therefore the stock package is a last-resort recovery source, not
a substitute for backing up the current working slot B.

The stock XML contains empty entries for `vm-linux_a/b`, `vm-system_a/b` and
the Qualcomm/OEM multi-image partitions. No Linux payload for those partitions
is shipped in ZUI 16.0.474, so their names alone do not provide a supported
dual-boot mechanism.

## Host recovery tools

- Google platform-tools are installed through WinGet.
- Android Bootloader Interface for `USB\\VID_18D1&PID_D00D` is installed.
- Qualcomm HS-USB QDLoader 9008 for `USB\\VID_05C6&PID_9008` is installed as
  `oem69.inf`; the package came from Microsoft Update Catalog and is signed by
  Microsoft Windows Hardware Compatibility Publisher.
- Official Lenovo Quick Fix 1.7.25.1023 was downloaded and its Authenticode
  signature was verified as Lenovo (Beijing) Limited.
- The stock package includes `prog_firehose_ddr.elf`, `fh_loader.exe`,
  `QSaharaServer.exe` and QFIL/QPST binaries.

## Completed device-specific readback

On 2026-08-10 the tablet entered EDL with `adb reboot edl`. The pinned stock
Firehose programmer read 44 regions (632,209,408 bytes) without a program or
erase command, verified every expected size and SHA-256, then reset normally.
The saved set includes:

- `persist`, `modemst1`, `modemst2`, `fsg`, `fsc`;
- `devinfo`, `dip`, `apdp`, `msadp`, `secdata`, `storsec`, `uefivarstore`;
- `boot_b`, `recovery_b`, `dtbo_b`, `vbmeta_b`, `vbmeta_system_b`;
- all six primary and backup GPT regions;
- an inventory containing LUN, start sector, sector count, byte size and
  SHA-256 for every saved file.

The exact `recovery_b` backup is 104,857,600 bytes with SHA-256
`94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668`.
It is byte-identical to Lenovo's ZUI 16.0.474 `recovery.img`. Current `boot_b`,
`dtbo_b`, `vbmeta_b` and `vbmeta_system_b` differ from their package files, so
the device readback—not a generic package image—is the rollback source.

All `vm-linux_a/b`, `vm-system_a/b`, `multiimgoem_a/b`, `multiimgqti_a/b`,
`vm-data`, `vm-keystore`, `fsc`, `fsg`, `modemst1` and `modemst2` readbacks are
entirely zero-filled. This confirms that ZUI does not contain a dormant Linux
guest in those named partitions.

Generate the read-only XML and expected-size inventory directly from the
verified stock GPT descriptions:

```sh
python3 scripts/generate-edl-readback.py STOCK_PACKAGE_ROOT OUTPUT_DIR
```

After Firehose has completed every `<read>` command, verify every file and
create the SHA-256 manifest:

```sh
python3 scripts/verify-edl-readback.py \
  OUTPUT_DIR/tb371fc-critical-readback.json READBACK_DIR \
  --manifest READBACK_DIR/sha256-manifest.json
```

The generated set intentionally excludes the very large shared `super` and
`userdata` partitions because the verified stock package restores `super` and
the first Linux test must not touch either one. It includes both VM partition
sets, the current B-slot boot/recovery chain, unique radio/security state and
all primary/backup GPT regions.

On Windows, `scripts/edl-readback.ps1` performs the complete gated workflow.
Its default mode only validates pinned tool hashes, proves that the XML
contains 44 `<read>` commands and no write/erase command, checks free space and
reports whether the requested QDLoader COM port is present:

```powershell
.\scripts\edl-readback.ps1 -ComPort COM12
```

`-ExecuteReadback` remains protected by PowerShell's high-impact confirmation
and refuses to run unless the exact QDLoader USB ID is present. It uploads the
stock Firehose programmer, performs the reads, verifies every byte count and
writes `sha256-manifest.json`, then requests a normal Firehose reset. It
contains no flash, program or erase command.

Ordinary ABL does not implement `fastboot fetch` on this tablet; the command
was tested read-only and returned `Device does not support fetch command`.
Android then rebooted normally on slot B.

## Recovery launch results

The first two and least invasive tests temporarily replaced `recovery_b`, not
`boot_b`, `vbmeta_b`, `super` or userdata:

1. read back and verify the original `recovery_b` through EDL;
2. build a diagnostic recovery image using the stock recovery header layout
   and recovery DTBO;
3. flash only `recovery_b` after separate user approval;
4. boot recovery explicitly and collect logs through USB CDC-ACM;
5. reboot to the untouched Android `boot_b`;
6. immediately restore and hash-check the original `recovery_b`.

The first probe used a valid Android boot-header-v2 image and stock
`recovery_dtbo`, but omitted the AVB footer and returned to fastboot before the
Linux USB console appeared. The exact backup was restored and Android returned.

The second image also reproduced the stock recovery AVB hash-footer structure:
partition name `recovery`, algorithm `NONE`, stock salt and stock recovery
fingerprint property. `avbtool verify_image` validated its embedded hash. It
also returned to fastboot before Linux USB enumeration, and the exact backup
was restored again.

The current signed `vbmeta_b` contains a SHA-256 descriptor for the unmodified
stock recovery payload. This was tested as one possible explanation for the
rejection, but the separately authorized verification-disabled experiment
showed that AVB was not the only blocker. A `vbmeta_b` change remains outside
the recovery-only procedure and always requires its own approval.

## Executed two-partition gate

`scripts/make-verification-disabled-vbmeta.py` starts from the exact 65,536-byte
EDL backup of `vbmeta_b` (SHA-256
`58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05`).
It validates the AVB header and changes flags from `0x00000000` to
`0x00000003`. The only changed byte is offset 123; the resulting SHA-256 is
`5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169`.
This is exactly the byte modified by Android platform-tools when both
`--disable-verity` and `--disable-verification` are requested.

`scripts/temporary-vbmeta-recovery-test.ps1` validates all four pinned images
and the one-byte vbmeta diff. Its launch action additionally requires
`-TwoPartitionWriteApproved`. It writes diagnostic `recovery_b` first and
test `vbmeta_b` second. If the second write fails, it restores recovery before
leaving fastboot. Normal rollback restores stock recovery first, then the
signed vbmeta backup, and only then reboots.

The launch action was separately authorized and executed on 2026-08-10. Both
test partitions were accepted by fastboot, but recovery boot returned to
fastboot before Linux USB enumeration just as the recovery-only probes did.
The new monitor detected that state and immediately restored the exact
`recovery_b` backup first and signed `vbmeta_b` backup second; fastboot
reported both writes successful. Its subsequent normal reboot entered stock
recovery, whose secure ADB did not authorize the host key. The user selected
`Reboot system now` on 2026-08-10; Android returned on slot B, completed boot
and exposed authorized ADB with the expected ZUI build and AVB state `orange`.

Therefore disabling AVB verification was insufficient. Further launches must
not reuse this image or expand to `boot_b`; first determine the independent
ABL/recovery-container acceptance requirement offline.

That offline comparison identified an incompatible DTBO handoff: the rejected
recovery reused ZUI's Kona QRD overlay, but `fdtoverlay` cannot apply it to the
complete mainline TB371FC DTB and returns `FDT_ERR_NOTFOUND`. A new 359-byte
Android DT table contains a single empty board-`0xb` overlay; applying its
payload succeeds and does not alter the mainline DTB. A rebuilt recovery with
that DTBO passed byte-for-byte component checks and AVB verification.

The rebuilt image was separately authorized and launched on 2026-08-10. It
also returned to fastboot before Linux USB enumeration. The monitor restored
the exact stock recovery first and signed vbmeta second; every write and the
final reboot command reported `OKAY`. The tablet then entered stock recovery
with secure, unauthorized ADB. The failed image was removed from the allowlist
and must not be reused. DTBO incompatibility was real but was not the only ABL
launch blocker.

A later no-EFI Linux 7.1.8 image removed the PE/COFF-compatible `MZ` entry and
used a direct ARM64 kernel entry like stock. It passed component and AVB checks
and was separately authorized, but still returned to fastboot before Linux USB
enumeration. The same monitor restored stock recovery and signed vbmeta with
all writes reported `OKAY`. This image was also removed from the allowlist.
Further recovery launches are paused pending a different boot-route analysis.

## Successful control boot and final rollback

The next separately authorized test used the exact Lenovo 4.19 kernel, stock
recovery DTBs and stock `dtbo_b` content with the project's diagnostic Linux
initramfs. Unlike every mainline recovery, it stayed in Linux and enumerated a
USB NCM device on Windows. This proves that the reviewed recovery/vbmeta route
can execute a non-Android userspace; the unresolved failure is specific to
mainline kernel/DT bring-up.

After the control test, the tablet was forced back to fastboot. The restore
action verified all pinned hashes, wrote the exact 100 MiB EDL `recovery_b`
backup (SHA-256
`94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668`),
then the exact signed `vbmeta_b` backup (SHA-256
`58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05`).
Fastboot reported both writes and reboot as `OKAY`. Authorized ADB then
confirmed `sys.boot_completed=1`, ZUI 16.0.474 and active slot `_b`. `boot_b`,
`super`, userdata and slot A were not written.

The later Linux 7.1.8 stage-0 test used the same reviewed two-partition gate.
It returned to fastboot before Linux USB enumeration. Automatic rollback again
wrote the exact stock recovery first and signed vbmeta second, with both writes
and reboot reported `OKAY`. After selecting `Reboot system now`, Android
completed boot on slot `_b` and authorized ADB confirmed the expected ZUI
build, unlocked state and AVB state `orange`. The stage-0 image was removed
from the allowlist. No boot, super, userdata or slot-A partition was written.

The subsequent `text_offset=0x80000` stage-0 image had recovery SHA-256
`95bfe39f9ee6c37e9c6c09ed19ea8d25947d6081e796f8032128f344458d1db7`;
its separately authorized launch also returned to fastboot before Linux USB.
Automatic rollback restored exact stock recovery and signed vbmeta, then
Android completed boot on slot `_b`. It is absent from the allowlist and must
not be repeated.

The later built-in-watchdog stage-0 recovery had SHA-256
`6a86facc8f1447e22e6a0f2e0c5c9aa5e8d8141c816a671c75583afa6764110c`.
Its authorized launch returned to fastboot after approximately 15 seconds,
despite `CONFIG_QCOM_WDT=y`. Automatic rollback again restored exact stock
recovery and signed vbmeta; Android completed boot on slot `_b`. The image was
removed from the allowlist and must not be repeated.

The pre-MMU framebuffer-marker recovery had SHA-256
`abdbfe804ee991ff58f47a3842a025907614309310c67f28a2315856c79a8a2e`.
It also returned to fastboot after about 15 seconds. Automatic rollback restored
both exact stock partitions and Android completed boot on slot `_b`. It was
removed from the allowlist; the visual screen-marker result must be supplied by
the observer before drawing a conclusion about `primary_entry` execution.

The size-constrained stage-0 recovery had SHA-256
`2c18b21de60dfe7363ca961976fc71ce3b0c3b6ef35775c56f7c2e7804f653bf`.
Its kernel was 24,422,408 bytes with `primary_entry` at about 15.05 MiB, but it
still returned to fastboot before Linux USB. Automatic rollback restored both
stock partitions. This excludes total Image size and a 32 MiB entry boundary
as sole causes.

The direct-entry recovery had SHA-256
`27feff143b528ddf00f87d9bdf7296958f37cb85062771c5ab463e0a6b4e5041`.
It moved the existing ARM64 entry branch from `code1` to `code0`, zeroed
`code1`, and preserved the same target. It returned to fastboot after about
16 seconds. Fastboot reported exact stock `recovery_b` and signed `vbmeta_b`
restoration as `OKAY`; ADB then confirmed completed Android boot on slot `_b`.
The image was removed from the allowlist and must not be repeated.

The subsequent direct-entry plus `text_offset=0x80000` recovery had SHA-256
`8dbb06d28dc97d736510393782511fd914212044e9044e5e23451d212a044d47`.
It also returned to fastboot before Linux USB, after about 8.6 seconds of host
observation. Automatic rollback restored both exact stock partitions, and ADB
confirmed completed Android boot on slot `_b`. It is absent from the allowlist
and must not be repeated.

## Rebuilt downstream recovery test

A later authorized bridge test replaced the stock kernel with the project's
own build of the published TB371FC lineage source, version
`4.19.325-cip134-st18-perf+`. The independently verified recovery SHA-256 was
`1bd81ac7e53d13c44e64c500fee730a65b8edbd1dbb656b8a858b31430399f33`.
It booted Linux and enumerated NCM as `1d6b:0105`, proving that ABL accepts the
rebuilt downstream kernel. TCP diagnostics remained unreachable.

After a transient fastboot entry, `fastboot reboot bootloader` was used to hold
the device in the bootloader. The restore action then wrote the exact EDL
`recovery_b` backup first and exact signed `vbmeta_b` second; every operation
reported `OKAY`. Android subsequently completed boot on slot `_b` with ZUI
16.0.474 and AVB `orange`. The test hash was removed from the allowlist. No
boot, super, userdata or slot-A partition was written.

The follow-up firmware/NCM recovery had SHA-256
`12439d92fd29c34a1456df0ba433dddaa411e352eb815f4254ed39c3c32d1660`.
It booted repeatedly and exposed the diagnostic shell. The WLAN activation
experiment restarted the kernel automatically back into recovery; no partition
was changed by that restart. A built-in, one-shot recovery module then called
`kernel_restart("bootloader")`, after which fastboot was detected normally.
The restore script stabilized fastboot, wrote the exact 100 MiB EDL
`recovery_b` backup and exact 64 KiB signed `vbmeta_b` backup, and received
`OKAY` for both. ADB confirmed Android boot completion, slot `_b`, ZUI
16.0.474, unlocked state, AVB `orange` and 100% battery. The recovery hash was
then removed from the allowlist. No installation, repartitioning or write to
`boot`, `super`, userdata or slot A occurred.

The safe QCA6390 follow-up recovery had SHA-256
`4bad062a9d301557aa2d326046bf9da5dc19bb081b44fb99c368272d09f7387c`.
Its no-SSR diagnostic mode contained the expected WLAN firmware failure and
left Linux and the NCM shell responsive. The embedded reboot module returned
the tablet to fastboot. The restore action wrote the exact stock `recovery_b`
and exact signed `vbmeta_b`; fastboot reported `OKAY` for both writes and the
following reboot. No other partition was written.

After physical `Reboot system now`, authorized ADB confirmed Android boot
completion, slot `_b`, ZUI 16.0.474, unlocked state, AVB `orange` and 100%
battery. The recovery hash was removed from the temporary launch allowlist;
this rollback is fully closed.

The final unattended recovery had SHA-256
`664ac94117ebc46af96f4d230958a8a91bf8b1712ec8cad5d61fa14664e8c7de`.
It booted Linux, completed the single QRTR/WLAN experiment and remained
responsive. After host logs were flushed to disk, the tested reboot module
entered fastboot. The restore action wrote exact stock `recovery_b` first and
exact signed `vbmeta_b` second; both writes and reboot reported `OKAY`.

The tablet then entered stock Recovery with unauthorized ADB, matching the
known persistent recovery-request limitation. After physical `Reboot system
now`, authorized ADB confirmed `sys.boot_completed=1`, slot `_b`, ZUI
16.0.474, AVB `orange`, unlocked state and 100% battery. The test hash was
removed from the launch allowlist and the rollback is fully closed. No boot,
super, userdata, misc or slot-A partition was written.

## Persistent development loader

The prepared development loader reuses the tested recovery-only route but
keeps its writable Arch root in a 6 GiB ext4 file on the existing exFAT
microSD. It never mounts Android partitions. Missing image, wrong size, failed
exFAT/ext4 mount or missing marker falls back to the USB NCM rescue shell.
The verified v3 recovery SHA-256 is
`de24caff50d0a382cbec72b1599a1d7d9e489fe83bc15d2a95d60257bf9d8fab`.
It is not launch-allowlisted. The separately gated microSD image installation
has completed and its 6 GiB size and SHA were verified on the tablet, so the
loader is now eligible for a separately authorized first boot. Session
rollback remains exact stock `recovery_b` first, signed `vbmeta_b` second.
See [PERSISTENT_DEVELOPMENT.md](PERSISTENT_DEVELOPMENT.md).
