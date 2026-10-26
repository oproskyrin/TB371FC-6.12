# Development and virtual test environment

The TB371FC port uses two deliberately separate environments. Ubuntu 24.04
under WSL2 is the reproducible build host. QEMU AArch64 is a userspace and
generic-machine preflight, not an emulator of the Lenovo tablet.

## Installed host environment

- Windows platform tools provide `adb` and `fastboot` for read-only inventory,
  explicit test launches and exact restoration.
- Ubuntu 24.04 under WSL2 provides the AArch64 cross compiler, `dtc`, kernel
  build tools and image assembly scripts.
- QEMU 8.2 AArch64 system and user emulation, `binfmt-support` and
  `systemd-container` provide isolated rootfs checks.
- ShellCheck validates the host-side build and QEMU scripts.
- Python helper scripts use the Ubuntu system Python unless a third-party
  dependency is introduced. If that happens, use a project-local `.venv`;
  never install Python packages into the Arch target rootfs to run host tools.

The QEMU packages installed on the current host are `qemu-system-arm`,
`qemu-user-static`, `binfmt-support` and `systemd-container`.

## Persistent tablet laboratory

The real tablet is being prepared as a long-running hardware development
target, not as the kernel build host. Full kernels remain reproducibly
cross-compiled under WSL; the installed persistent Arch ARM64 ext4 image is an
ordinary file on the existing exFAT microSD. Verified loader v10 is intended to
provide USB NCM, a static rescue channel and public-key-only SSH after its
separately gated hardware test. Once validated, this permits repeated
userspace, logging and loadable-module work without rebooting. Kernel, DTB and
built-in driver changes still require a controlled recovery reboot.

The complete architecture, pinned hashes, installation gate and connection
workflow are documented in [PERSISTENT_DEVELOPMENT.md](PERSISTENT_DEVELOPMENT.md).

## Static hardware-metadata analysis

Large reverse-engineering tools and generated databases are kept on `D:`:

- Ghidra 12.1.2: `D:\TB371FC-tools\ghidra_12.1.2_PUBLIC`
- Eclipse Temurin JDK 21.0.12+8: `D:\TB371FC-tools\jdk-21.0.12+8`
- Ghidra project: `D:\TB371FC-analysis\ghidra\zui-camera-16.0.474`
- Targeted decompiler output: `D:\TB371FC-analysis\camera-decompile`
- DT schema Python environment: `D:\TB371FC-tools\dtschema-2026.6-venv`
- Clean Linux 7.1.8 source: `D:\TB371FC-builds\linux-7.1.8-s5k4h7-clean`
- Focused camera build output: `D:\TB371FC-builds\linux-7.1.8-s5k4h7-out`

The official Ghidra archive SHA-256 is
`b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d`;
the Temurin archive SHA-256 is
`e4446ff06a276155697597cc0f1b15da004ff083f4964a35271ecee567177370`.
Both were verified before extraction. Their download archives remain under
`D:\TB371FC-tools\downloads`; no Java runtime or Ghidra payload was installed
on `C:`.

`dtschema` 2026.6 plus its validation helpers `yamllint`, `ply` and
`GitPython` are installed in an isolated virtual environment on `D:`.
Prepend `/mnt/d/TB371FC-tools/dtschema-2026.6-venv/bin` to `PATH` when running
kernel `CHECK_DTBS=y` or `dtbs_check`; the Ubuntu system Python remains
unchanged.

The stock `camera.qcom.so` contains an XZ-compressed `.gnu_debugdata` ELF with
10,095 local symbols. It identifies `ParameterSetManager::LoadBinaryParameters`
and the generated sensor loaders even though the outer HAL is stripped.
`ghidra_scripts/DecompileNamedFunctions.java` provides a deterministic
headless export of uniquely selected functions. Decompiled proprietary code,
Ghidra databases and stock binaries must remain outside Git; only original
analysis helpers, hashes and independently stated findings are committed.

Upstream tool sources:

- [NSA Ghidra release](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.2_build)
- [Eclipse Temurin 21 binaries](https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.12%2B8)

Install the same layer on a clean Ubuntu/WSL2 host with:

```sh
sudo apt install qemu-system-arm qemu-user-static binfmt-support \
  systemd-container
```

## What QEMU proves

QEMU can validate that an AArch64 Arch rootfs has a coherent package set,
starts systemd on a generic virtual machine and can launch basic Wayland/Plasma
components with virtual graphics. User-mode emulation can also run package
post-install scripts while constructing the rootfs.

QEMU does **not** model the TB371FC SM8250 board, Lenovo dual-DSI panel,
QCA6390 wiring, USB-C DisplayPort path, TFA9894 amplifiers, cameras, AP500U pen
or sleep states. Passing QEMU is therefore only a userspace preflight; it is
never evidence that those devices work.

## Test ladder

1. Verify package names against current published Arch Linux ARM repository
   metadata with `scripts/verify-arch-package-manifests.py`.
2. Build the minimal AArch64 rootfs and run package/userspace smoke tests under
   QEMU or `systemd-nspawn` plus `qemu-aarch64-static`.
3. Boot the diagnostic initramfs on the tablet and keep USB serial recovery.
4. Boot the minimal Arch console image, with the graphical target disabled.
5. Start KWin/Wayland manually, then enable Plasma only after DRM and input are
   stable.
6. Test each physical subsystem separately on the tablet with an exact restore
   path prepared before any partition write.

The default graphical session is KDE Plasma 6 on Wayland. Plasma Mobile may be
installed later as an optional second session; it is not the virtual test
environment and is not the initial default.

For the current official Arch Linux ARM rootfs, run both emulation levels with:

```sh
sudo ./scripts/smoke-test-arch-rootfs.sh /root/arch-tb371fc/rootfs
sudo ./scripts/build-qemu-rootfs.sh \
  /root/arch-tb371fc/rootfs /root/arch-tb371fc/qemu-rootfs.raw 6G
sudo ./scripts/build-qemu-initramfs.sh \
  /root/arch-tb371fc/rootfs /root/arch-tb371fc/qemu-initramfs.img
sudo ./scripts/test-qemu-arch-boot.sh \
  /root/arch-tb371fc/rootfs /root/arch-tb371fc/qemu-rootfs.raw \
  /root/arch-tb371fc/qemu-initramfs.img
```

The first command executes target binaries through QEMU user emulation. The
remaining commands create a new, isolated ext4 image, add the QEMU
`virtio_mmio` transport to a separate initramfs, and boot Arch's generic
AArch64 kernel on QEMU `virt`. Existing output files are never overwritten
automatically.

## Current verified baseline

On 2026-08-10 the locally retained official rootfs archive matched its
published MD5 sidecar (`23eec86365b24f7913c403e8f4e8719b`) and had SHA-256
`42a4eeaa038994ffd31fa173256ef2f0ef511358eeb41b9ea1f8626391b9b319`.
QEMU user emulation executed AArch64 Pacman 7.1 and systemd 261. QEMU system
emulation then booted the archive's Linux 7.1.6 generic kernel, detected the
isolated image as `vda`, mounted the `archroot` ext4 filesystem, switched root
and reached the serial `alarm login:` prompt. The generated disk, initramfs and
serial log remain local build artifacts and are not committed.

## Isolation and rollback

QEMU images and generated root filesystems stay outside Git and never share a
writable block device with Android. Tablet tests follow `TESTING.md` and
`RECOVERY.md`: slot A is never used, automatic installation is forbidden, and
the exact slot-B recovery/vbmeta backups remain the boot-chain rollback.

## Storage maintenance on 2026-08-14

The WSL ext4 filesystem was repaired with the documented offline `e2fsck`
flow before the clean 7.1.8 build. After exporting a hash-verified 82 MiB
release set to D, `scripts/cleanup-old-wsl-kernel-outputs.sh` removed only
named, reproducible `*-out` object trees and retained the current clean source
and output. This reclaimed 98,441,273,344 bytes inside WSL.

`fstrim /` released the unused extents, but the host `ext4.vhdx` cannot be
compacted by the current non-administrative process. `Optimize-VHD` returned a
permission error. WSL's `--set-sparse true` demanded `--allow-unsafe`; that
unsafe override was not used. To reclaim the host allocation later, close WSL
and run an elevated PowerShell:

```powershell
wsl.exe --shutdown
Optimize-VHD -Path 'D:\WSL\Ubuntu-24.04\ext4.vhdx' -Mode Full
```

Several superseded D-side 7.1.7/early-7.1.8 products were also removed after
the new release set passed verification. V55, stock backups, community 6.12,
U-Boot and the new 7.1.8 artifacts were preserved. Approximately 4 GiB was
free on D after this conservative cleanup.

The larger Plasma development root is kept as a sparse WSL file rather than a
second 12 GiB copy on D:

```text
/root/arch-tb371fc/tb371fc-arch-development-v2-12g.raw
logical size 12 GiB; physical allocation about 6.2 GiB
SHA-256 ae0fe97debbb6b6c485546dd130e9a9a15724784b41af3fb862bad1f1cf58b44
```

Its final independent verifier passed on 2026-08-14 after installing the exact
1,510-module archive from Linux 7.1.8-r4. The small reproducibility record is
in `artifacts/arch-development-v2-12g`; copying the raw image to D would exceed
the current free-space margin and is intentionally deferred.
