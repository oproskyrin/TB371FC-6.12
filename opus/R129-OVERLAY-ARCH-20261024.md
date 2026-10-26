# R129: Arch systemd on read-only SD with RAM overlay

Status: CONFIRMED Arch/systemd boot on Linux 6.12, multi-user.target active.

R128 milestone: photo confirms eight matched buffered reads and RO access to
exFAT, 12 GiB ext4 Arch image and its marker. Repeated buffered reads can be
cached; R129 requires O_DIRECT reads (three repeats at each of 0/32/128 MiB)
before attempting the full userspace boot. GPIO DTB and R118 Image unchanged.

Artifacts: D:/TB371FC-builds/linux-6.12.30-tb371fc-r129-overlay-arch
Image SHA256: dbcffeead9750aa41228269f2101c32c76cbde42d1bea554db1132ad30eac11d
DTB SHA256: 0e312dab299e034b056e1e2e6550c7726415bf6a161cf074bc1f077c6432f828
Initramfs SHA256: f0b56e6badf79a380843089e84f10f4c0038326d5c9aba8efef6d9986ef3c8b4

Card and partition are set read-only via blockdev; failure stops boot.
exFAT mounts RO; loop image attaches -r; ext4 mounts ro,noload. OverlayFS
(CONFIG_OVERLAY_FS=y, TMPFS_XATTR=y) supplies writable root backed by a
512 MiB tmpfs, preserving SD-backed lower root. Mounts live below /run/r129
and /run moves into the new root before switch_root /sbin/init.
Root fstab is replaced only in the RAM upper layer; fsck-root/remount-fs and
display-manager are masked there. Journald storage is volatile and capped.
No original root/image file is modified by these changes; state disappears
after reboot. USB and graphics remain disabled in the current DTB.

The evidence timer triggers after startup; its service orders after
multi-user.target and prints uname, PID1 comm, root mount type and target
state to journal+console. Evidence file: /run/r129/arch-evidence.txt.
The unit is not itself a prerequisite of multi-user.target (avoid cycle).

Validation:
- Shell syntax checks passed; payload hashes checked.
- Host WSL mounted the original image RO/noload, created overlay on tmpfs,
  changed overlay fstab and confirmed lower fstab hash unchanged.
- Actual ARM systemd 261.2-1-arch executed --version under QEMU.
- Actual ARM systemd-analyze verified the evidence service/timer. Arch's
  environment generator emitted an ignored warning in the host QA context.
- BusyBox O_DIRECT dd successfully read a block from the host source image.
- BusyBox mount --make-rprivate passed inside a disposable mount namespace.
- Configuration permissions corrected to 0644; scripts 0755.

Scripts: prepare-r129-overlay-arch.sh (supports --repack),
validate-r129-overlay.sh, r129-overlay-arch-loader.sh,
test-r121-r129-overlay-arch.sh and scripts/r129/*.

Reference: https://docs.kernel.org/filesystems/overlayfs.html
This is the first confirmed Arch/systemd 6.12 checkpoint in this test sequence.
It is a headless diagnostic checkpoint, not a fully adapted hardware release.

## Hardware handoff

User returned to the initial console. SSH confirmed 4.19.157-perf-v56.6+,
panic=0 and boot ID 2e20a5cf-cf05-42f8-959d-2a1083b264ca.
Transferred the R129 bundle to RAM. Runner checked all three payload hashes
and reached calling kexec -e, with systemd.unit=multi-user.target and
systemd.show_status=1. No partition writes needed.
Host log: diagnostics/r121-r129-control-20261024.log.
Persistent first-stage record: /var/log/tb371fc-r121/r129-control.txt.
Photo D:/image-24-10-26-12-46.jpeg confirms:
- Arch Linux ARM login on tty1 with 6.12.30-tb371fc-r118-pinctrl+.
- Evidence timer executed at approximately 108 seconds uptime.
- uname reports Linux alarm 6.12.30-tb371fc-r118-pinctrl+ aarch64 GNU/Linux.
- PID1: systemd; multi-user.target: active.
- Root is writable overlay with lower/upper/work below /run/r129.
- systemctl --failed prints zero loaded units (no failed units at that moment).

Reaching this evidence service also implies that the mandatory O_DIRECT and
mount checks in the verified loader passed, though their individual output
is not visible on this photo. This establishes an actual Arch userspace boot,
not merely an initramfs shell. No second-stage remote connection was obtained.

Remaining limits: GPIO75 alone enabled; USB/SSH and graphics not enabled;
all system writes are volatile RAM changes; persistent SD writes untested.
PMIC/SPMI bad_chained_irq diagnostics remain visible around 71 seconds.
No long-duration stability, restart reproducibility, or full peripheral claim.

Frozen checkpoint copy:
D:/TB371FC-builds/checkpoints/r129-arch612-headless-20261024
Contains Image, DTB, initramfs, bundle, loader/runner sources, config sources,
photo evidence, README and checksums. First-stage R121 recovery remains a
separate prerequisite; it was not reflashed for this successful run.
