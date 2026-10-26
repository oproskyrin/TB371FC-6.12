# Lenovo TB371FC (Xiaoxin Pad Pro 12.7, Snapdragon 870 / SM8250) · Linux 6.12

**English** · [Русский](README.ru.md)

Arch Linux ARM with KDE Plasma running on the Lenovo **TB371FC** tablet, using a
**Linux 6.12** kernel that is started from microSD. Android on the internal UFS stays
untouched: Linux lives entirely on the microSD card and is started through the
tablet's second recovery slot (`recovery_b`).

> ⚠️ **Status: experimental / research project.** It works daily on the author's
> tablet, but installing it requires an unlocked bootloader, Linux build skills and
> comfort with `fastboot`. You can soft-brick the tablet. Everything here is at
> your own risk.

## Screenshots

| | |
|---|---|
| ![KDE Plasma desktop](screenshots/desktop.jpg) | ![Application launcher (Russian UI)](screenshots/launcher.jpg) |
| KDE Plasma desktop | Application launcher (Russian UI) |
| ![Terminal: kernel, CPU, memory, microSD layout, sound, Bluetooth](screenshots/terminal.jpg) | ![System Settings](screenshots/settings.jpg) |
| Terminal: kernel, CPU, memory, microSD layout, sound, Bluetooth | System Settings |

*Screenshots are taken on the tablet itself (2944×1840, scaled down) by reading the framebuffer — `scripts/r184-fbgrab/`.*

## What works

| Area | Status |
|---|---|
| Boot of Linux 6.12 from microSD (autoboot, Android untouched) | ✅ |
| KDE Plasma 6 desktop (Wayland), Russian/English UI, on-screen keyboard | ✅ |
| Touchscreen (NT36532) | ✅ |
| Wi-Fi (QCA6390, ath11k) via NetworkManager | ✅ |
| Bluetooth (QCA6390 over UART6) | ✅ |
| Speakers (4 × TFA9894), PipeWire | ✅ |
| Backlight (dual KTZ8866), brightness control | ✅ |
| Persistent root filesystem on microSD partition 2 (ext4) | ✅ |
| microSD: DMA, UHS SDR50 — ~46 MB/s read, ~32 MB/s write | ✅ |
| CPU frequency scaling, thermal throttling | ✅ |
| Adreno 650 GPU (freedreno, GLES 3.2) — headless only | ⚠️ |
| Display: framebuffer handed over from the bootloader (simpledrm, 60 Hz) | ⚠️ |
| Native DPU/DSI display driver, 120 Hz | ❌ in progress (left half correct, right half noise) |
| GPU-accelerated compositing in KWin | ❌ (QPainter/software rendering) |
| microSD SDR104 writes | ❌ (reads work; needs BH201 output tuning) |
| Cameras, sleep/suspend, dock keyboard pogo pins | ❌ / not tested |

## How it boots

```
power on ─► ABL bootloader ─► recovery_b slot
                                │  Lenovo 4.19 kernel + our ramdisk ("first-stage console")
                                │  · USB console / SSH for a PC (172.31.77.2)
                                │  · 60 s window if a PC is attached, otherwise ~7 s
                                ▼
          microSD p1 (exFAT): tb371fc-linux/autoboot-6.12-rNNN/{Image, board.dtb, initramfs.cpio.gz, ENABLE}
                                │  SHA-256 pinned, started with kexec (RAM only)
                                ▼
          Linux 6.12 initramfs ─► mounts microSD p2 (ext4, label tb371fc-root) read-write as /
                                ▼
                        systemd ─► NetworkManager, Bluetooth, PipeWire ─► KDE Plasma
```

* Delete the `ENABLE` file on p1 to disable autoboot — the tablet then stays in the console.
* Adding `tb371fc.maint` to the 6.12 command line starts a **maintenance mode**: the root
  partition is not mounted and a USB rescue shell is available at `172.31.77.2:2323`
  (`scripts/tb371fc-ncm.py`). It reboots by itself after 15 minutes without contact.
* Booting Android: just reboot normally into slot A / the regular boot partition; nothing
  in Android is modified.

## microSD layout

| Partition | FS | Size (author's 128 GB card) | Content |
|---|---|---|---|
| p1 | exFAT | 20 GiB | `tb371fc-linux/` — console image `tb371fc-arch-development.raw`, autoboot payloads, layers |
| p2 | ext4, label `tb371fc-root` | rest | Arch Linux ARM root filesystem (persistent) |

If p2 with the label `tb371fc-root` is missing, the loader falls back to the older
read-only image + RAM overlay (changes are lost on reboot).

## Repository layout

| Path | What |
|---|---|
| `mainline-port/` | Device tree (`arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc.dts`), kernel patches, kernel config |
| `scripts/build-*.sh` | Kernel / module builds (run in WSL2 Ubuntu 24.04 or any Linux, clang 18) |
| `scripts/package-rNNN-*.sh/.py` | Assemble an autoboot payload and the recovery image of a release |
| `scripts/rNNN-sd-install-419.sh` | Writes a payload to the microSD from the 4.19 console (hash-verified) |
| `scripts/rNNN-recovery/` | The autoboot helper that lives in the recovery ramdisk |
| `scripts/r175-loader/` | Loader: persistent root on p2, maintenance mode |
| `scripts/r1xx-config/` | Systemd units/scripts baked into the initramfs (Wi-Fi, BT, desktop defaults…) |
| `scripts/*.ps1` | Windows-side tools: flashing, console hold, reboot, release cycle |
| `initramfs/`, `rootfs/` | Initramfs and root filesystem pieces |
| `opus/` | Engineering reports for every release (R1xx) — the most detailed documentation |
| `docs/` | Older port notes (panel, audio, touch, recovery, hardware matrix…) |

The project grew release by release (R1 … R183); file names carry the release number.
The current production release is **R178/R179**.

## Installation (overview)

There are **no prebuilt images in this repository**: the recovery image is derived from
the stock Lenovo `recovery_b` and the payload contains Qualcomm/Lenovo firmware, which
cannot be redistributed. You build them yourself from your own device backup.

### 0. Requirements

* Lenovo TB371FC with an **unlocked bootloader** (`fastboot flashing unlock` — wipes Android data).
* microSD card, 64 GB+ recommended (UHS-I, A1/A2).
* PC with `adb`/`fastboot` (Android platform-tools), Windows 10/11 + WSL2 Ubuntu 24.04
  (the scripts are written for this setup) or a Linux PC.
* Build tools in WSL/Linux: `clang-18`, `lld`, `make`, `python3`, `cpio`, `mkbootimg`
  (`unpack_bootimg.py`), `avbtool`, `e2fsprogs`, `exfatprogs`.

### 1. Back up the device

Before anything else, dump your stock partitions (at least `recovery_a/b`, `vbmeta_a/b`,
`boot_a/b`, `dtbo_a/b`) and keep them safe. The scripts expect the stock recovery at
`artifacts/device-backup/lun0-recovery_b.bin`. Set your fastboot serial:

```powershell
$env:TB371FC_SERIAL = '<serial from "fastboot devices">'
```

### 2. Build the kernel and modules

1. Get Linux 6.12 (the project used 6.12.30) and apply the patches from
   `mainline-port/patches/` (the active ones are listed in `scripts/build-r179-kernel.sh`).
2. Use `mainline-port/tb371fc-arch.config` as the base config.
3. Build `Image`, the device tree `sm8250-lenovo-tb371fc.dtb` and modules
   (`scripts/build-r174-bh201.sh`, `build-r178-uhs.sh` build the out-of-tree microSD modules).

Paths inside the scripts default to `/mnt/d/TB371FC-builds` and `/root/tb371fc/...`;
adjust them to your machine.

### 3. Prepare the microSD

1. Partition: p1 exFAT (~20 GiB), p2 ext4 with label `tb371fc-root` (rest of the card).
2. Unpack an Arch Linux ARM (aarch64) root filesystem to p2 and install KDE Plasma,
   NetworkManager, bluez, pipewire (see `docs/ROOTFS.md`, `docs/ARCH_PROFILE.md`).
   Add firmware from your own device (`scripts/package-stock-firmware.sh` extracts it
   from your stock partitions; see `docs/FIRMWARE.md`).
3. Put the console image to `p1:/tb371fc-linux/tb371fc-arch-development.raw`.

### 4. Build the payload and the recovery image

```bash
bash scripts/package-r179-autoboot.sh                 # Image + board.dtb + initramfs.cpio.gz
python3 scripts/package-r178-autoboot-recovery.py     # recovery_b image with the autoboot helper
```

Copy the payload to `p1:/tb371fc-linux/autoboot-6.12-r179/` together with an empty
`ENABLE` file (or let `scripts/r178-sd-install-419.sh` do it from the console).

**Wi-Fi:** your own network is provisioned at build time from a `wpa_supplicant`-style
file that contains only the **PSK hash** (`wpa_passphrase` output, plaintext line
removed). Keep it outside the repository. **SSH:** generate your own key
(`ssh-keygen -t ed25519`) into `artifacts/tb371fc-development-ssh/` — it is git-ignored.

### 5. Flash recovery_b

```bash
fastboot flash recovery_b tb371fc-rNNN-recovery.img
fastboot flash vbmeta_b vbmeta-disabled.img      # vbmeta with verification disabled
fastboot reboot recovery
```

`scripts/tb371fc-flash-release.ps1` automates the whole cycle (console → upload →
SD install → fastboot → wait for SSH). Never flash anything to `boot`, `userdata`
or slot A unless you know exactly why.

### 6. First boot

Boot into recovery (`fastboot reboot recovery`, `adb reboot recovery`, or the recovery entry of the bootloader menu). The console
appears, autoboot starts Linux 6.12 after a few seconds, and KDE Plasma comes up
(user `alarm`). Keyboard layout is switched with Alt+Shift; display scale, wallpaper,
themes are yours to change and persist across reboots.

### Recovery / rollback

* Remove `ENABLE` from p1 (card reader on a PC) → the tablet stays in the console.
* Flash your backed-up stock `recovery_b`/`vbmeta_b` → everything is back to stock.
* Android is not touched at any step.

## Credits

* [smith-dog/kernel-tb371fc](https://github.com/smith-dog/kernel-tb371fc) — community 4.19 kernel for the TB371FC.
* Xiaomi Pad 6 (pipa) mainline community (PAD6-DEV) — the nt36532 panel and SM8250 tablet work.
* Linux, freedreno/Mesa, Arch Linux ARM and KDE projects.

## Support the project ☕

If this project helped you, you can buy the author a coffee:

[![Support on Boosty](https://img.shields.io/badge/Boosty-support%20the%20project-F15F2C?logo=boosty&logoColor=white)](https://boosty.to/slvgb)

**Boosty:** <https://boosty.to/slvgb>

## License

Kernel patches and device-tree files are GPL-2.0 (like the Linux kernel). Scripts and
documentation: see the header of each file; unless stated otherwise, GPL-2.0.
Lenovo/Qualcomm firmware is **not** included and is not covered by this repository.
