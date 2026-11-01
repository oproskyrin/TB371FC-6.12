# R226 v2: SD150 + USB3 peripheral candidate (2026-11-01)

Experimental, board-specific work on the existing TB371FC Linux 6.12.114 setup.
This directory is a development snapshot, not a universal installer or a promise
that every microSD/cable/connector orientation will work.

## Hardware results

- Real SDCC2 150 MHz SDR104, not a requested rate rounded down to 100 MHz.
  Three fresh-boot 256 MiB random-file write/fsync/remount/direct-read comparisons
  passed, all MMC error counters zero. Sequential write 43.55–44.99 MB/s;
  file read 65.42–67.34 MB/s (decimal). The existing 100 MHz baseline reads ~47 MB/s.
- The combined v2 reached the KDE desktop; the operator confirmed visible image
  and working touchscreen. Post-panel Novatek firmware refresh runs automatically.
- USB3 automatically reached `super-speed / configured / U0` with the saved R209
  stock-board TX/RX tables and the actual PS5169 redriver. SD remained at 150 MHz.
- A separate 64 MiB owned ext4 file passed O_DIRECT write + fsync + read + SHA256
  on the combined desktop: write 1.708014 s, read 1.143526 s, all MMC errors zero.
  Only that test file was removed. No raw-sector test writes or repartitioning.

These are bounded tests on one card, not endurance certification. **202 MHz
write is not fixed.** The SD transition is deliberately guarded to the tested
card identity; do not remove that check to try another card without RO-first
validation and a verified backup.

## Limitations

USB3 currently uses fixed orientation=2, `fine_lfps=1`, peripheral mode only.
Automatic Type-C orientation, USB host/hub, charging PD and external HDMI/DP are
not provided by this work. NCM measured only ~3–6 MB/s in the earlier R209 tests;
the same networking bottleneck also appeared in the USB2 control. A negotiated
SuperSpeed link is not proof of high application throughput.

The first R226 candidate FAILED automatic startup: adding the post-panel service
to multi-user.target created an ordering cycle, since the existing touch service
is ordered after that target. Touch loaded after the panel and chip ID failed;
the operator saw a black screen. **Do not use the first candidate.** v2 uses a
timers.target timer, then an asynchronous USB service start. The existing rootfs
unit ordering is not rewritten.

## Design and build map

- `mainline-port/patches/mmc-r223-gcc-sm8250-sdcc2-150mhz.patch`: one SDCC2 GCC
  frequency-table addition, GPLL0 600 MHz / 4. No PLL rate change.
- `scripts/r224-sd150-boot/`: exclusive/read-only, pre-root transition through
  verified SDR50 100 MHz, then verified SDR104 150 MHz. Filesystems remain
  unmounted during the timing change. Failure stops in rescue before root writes.
- `scripts/r225-touch-pm/`: invokes the bound Novatek driver's own suspend/resume
  callbacks after the native panel and desktop have started. Firmware/IRQ success
  must be checked with real input events, not just insmod return status.
- `scripts/r226-*.service`, `.timer`, `prepare-r226-initrd.py`: candidate-only
  runtime services in `/run`, retained across switch_root. No persistent service
  files are installed in the rootfs by the candidate initrd.
- `scripts/build-r209-qmp.sh`, `prepare-r209-qmp-source.py`, `r207-ps5169/`:
  scoped USB PHY table candidate plus PS5169 save/readback/restore helper.
- `scripts/package-r226-combined.sh`: R224 kernel/initrd + known R209 DT profile,
  both USB2 and USB3 DTs, and a hash manifest. `verify-r226-candidate.py` rejects
  unrelated initrd content changes against the R224 base.
- `scripts/package-r226-autoboot-recovery.py`: changes only the R201 ramdisk
  selection logic; first-stage kernel/DT/recovery_dtbo/cmdline stay unchanged.
  R226 is selected only when ENABLE and all three pinned hashes match; otherwise
  the preserved R201 directory is selected. Countdown cancellation remains.

Scripts retain the original developer's WSL/workspace/build paths and exact ABI
`6.12.114-tb371fc-r199+`, clang/LLVM18, and pre-existing R201/R203/R207 artifacts.
They are references for that environment, **not self-contained build commands**
for a clean checkout. Place/adapt them in the corresponding workspace layout;
rebuild modules against the exact configured kernel and verify Module.symvers.
Never mix arbitrary `.ko` files, DTs or initrds based on their filename alone.
`reference/r209-qmp.c` preserves the generated GPL driver source and the table
change list, so the reviewed USB register changes can be inspected without the
developer's private Android DT capture. Auxiliary unchanged modules still come
from the matching configured kernel build.

## Validated v2 payload identities

| File | SHA256 |
|---|---|
| Image | `7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157` |
| board-usb3.dtb | `d061e7e3445936db745308098a625fe060a69d6874840ded62cb110b5f18f775` |
| initramfs.cpio.gz | `0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219` |
| R226 first-stage recovery v3 | `7bdf6412f91cc37b05909c5b672973f78ab0da44fda9d788b0c75dcead130840` |

The payload tarball is for kexec, **not fastboot flash**. Only a properly packed
and audited recovery image may be written to its verified recovery partition.
Original R201 payload and recovery image must be retained before installation.
Remove R226's ENABLE file to select R201 on the next recovery boot. A normal
reboot may return to Android; ADB `reboot recovery` re-enters the first stage.

Raw backups, rootfs images, SSH material and unrestricted device logs are not
published. Binary initrds can contain provisioned keys/configuration; do not
publish personal images without an explicit credential audit.

The first recovery-selector revision incorrectly relied on an unset `bb`
variable in the early rootfs staging script and therefore selected the R201
fallback. Recovery v3 uses an explicit `/bin/busybox` path. The generated selector
is now exercised without inherited `bb`: valid payload selects R226; missing
ENABLE or a bad SHA selects R201. The first-stage kernel, DT and recovery_dtbo
are still byte-identical to R201. Only the ramdisk selection logic differs.
