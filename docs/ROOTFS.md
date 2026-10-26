# Arch Linux ARM rootfs

The first complete userspace is a console-first Arch Linux ARM image. KDE
Plasma is intentionally a later layer: hardware discovery, networking and
rollback must work from the console before a display manager is introduced.

## Reproducible build

`scripts/build-arch-rootfs.sh` accepts an official Arch Linux ARM aarch64
archive, one installed TB371FC module tree, the locally extracted firmware,
the kernel `Image`, and the safe and touch-test DTBs. It then:

1. rejects unsafe archive paths, missing firmware and existing output;
2. optionally verifies the archive with `ARCHIVE_SHA256`;
3. initializes the Arch and Arch Linux ARM signing keyrings;
4. updates and installs `rootfs/packages-base.txt` with signature checking;
5. installs modules, firmware and `/boot/tb371fc` artifacts;
6. enables NetworkManager and Bluetooth, but leaves SSH disabled;
7. records installed packages and SHA-256 manifests for all copied modules and
   firmware.

On a non-AArch64 WSL2 host, pacman's Landlock downloader sandbox and
`CheckSpace` mount probe cannot run through qemu-user. The builder disables
only those two host-incompatible checks. Package signature verification stays
enabled. Output is assembled in a temporary sibling directory and renamed
only after success.

Example:

```sh
ARCHIVE_SHA256=EXPECTED_SHA256 ./scripts/build-arch-rootfs.sh \
  ArchLinuxARM-aarch64-latest.tar.gz rootfs-tb371fc \
  modules-install firmware Image safe.dtb touch-test.dtb
```

## Verified 7.1.8 result

- rootfs size: 3.7 GiB;
- 47 explicitly requested packages, 336 installed packages with dependencies;
- 1,565 TB371FC kernel modules under
  `/usr/lib/modules/7.1.8-tb371fc-dirty`;
- module and firmware SHA-256 manifests verify;
- default target: `multi-user.target`;
- NetworkManager and Bluetooth enabled;
- SSH disabled;
- user-mode smoke test reports AArch64 Arch Linux ARM, pacman 7.1 and
  systemd 261;
- system QEMU boot with Arch's generic 7.1.6 kernel reaches the multi-user
  login prompt from an ext4 copy of this rootfs.

The QEMU result proves that userspace, systemd and the root filesystem are
coherent. It does not prove the TB371FC kernel, display, USB, Wi-Fi or other
physical hardware.

## First-boot security

Before enabling SSH or attaching an untrusted network:

1. change every password inherited from the source rootfs;
2. create the intended non-root administrator and verify `sudo`;
3. install an SSH public key if remote access is needed;
4. only then enable `sshd.service`;
5. preserve `/usr/share/tb371fc-port/BUILD-MANIFEST` and both hash manifests
   with the test log.

The hardware report helper is `/usr/local/sbin/tb371fc-hardware-report`. It is
read-only and writes a timestamped diagnostic bundle for comparison between
boots.
