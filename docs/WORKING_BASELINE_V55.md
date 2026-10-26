# TB371FC confirmed working baseline: V55

Status date: 2026-08-14

V55 is the frozen, physically verified recovery/development baseline currently
running on the tablet. It must remain available unchanged while V56 adds WLAN
and guarded KDE, and later while Linux 7.x is developed in separate profiles.

## Exact recovery image

```text
D:\TB371FC-builds\arch-development-loader-v55-community-simplefb-arch-loopback-ssh\tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img
size: 104857600 bytes
SHA-256: c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5
```

Embedded components recorded by the verified build:

| Component | SHA-256 |
| --- | --- |
| initramfs | `b634b92d265fc73f4770e9595055f9a101acd28383b96f75a07bce0a56008e06` |
| kernel | `86bb9ad1513dff5e20fa83ef7c7794725acac40f3db1b64b8bb1eef543453a9d` |
| DTB | `176e6117698582c79795c3e2ef73079cd0c35cce683358aa554bf26a2e611e39` |
| recovery DTBO | `fbf7d0c2f2fe0f90040f6fb6675ccbf456b7eddeb2a293168f7653c9ff6ffc59` |

## What is physically proven

- community/vendor Linux `4.19.157-perf+` boots through the temporary
  `recovery_b` path;
- the inherited simple framebuffer gives a stable, readable internal Linux
  console across the panel;
- the Arch ARM loop-ext4 root on microSD mounts read-write and `switch_root`
  succeeds;
- CDC ACM enumerates on Windows;
- the serial-to-loopback bridge exposes public-key-only OpenSSH at
  `127.0.0.1:22223` and repeated logins work;
- Android/UFS filesystems are not mounted by this Linux environment;
- the guarded return-to-bootloader and exact stock rollback artifacts exist.

V55 is therefore the working development and recovery reference. It is not
evidence that native DRM, KDE Plasma, Wi-Fi, Bluetooth, cameras, audio,
USB-C DisplayPort or every dock function already works. Those remain separate
acceptance tests for the new kernel.

## Freeze policy

1. Do not overwrite, rebuild in place, rename or delete the exact V55 image.
2. Verify its size and SHA-256 before every reuse.
3. Build V56 and every Linux 7.x experiment under new versioned directories;
   never reuse the V55 source output or artifact directory.
4. Never describe a new kernel as replacing V55 until it independently proves
   boot, readable internal display, microSD Arch root and remote control.
5. Keep V55 available until a newer candidate passes those requirements and
   the user explicitly promotes it to the working baseline.

## Android rollback anchors

```text
stock recovery_b SHA-256:
94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668

stock signed vbmeta_b SHA-256:
58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05

temporary verification-disabled vbmeta_b SHA-256:
5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169
```

The stock pair restores normal Android. V55 is a Linux test baseline, not an
Android replacement and not a permanent dual-boot installation.

Run `scripts/verify-v55-working-baseline.ps1` for an offline, read-only check
of all pinned V55 and rollback files. The verifier does not query, reboot or
write the tablet.

## V56 promotion gate

V56 is a candidate, not a replacement for V55. It may be promoted only after
one attended boot proves all of the following together:

- the same readable early simplefb console and Arch microSD handoff;
- automatic serial rescue SSH before any DRM modeset;
- the signed QCA6390 `wlan.ko` loads and NetworkManager creates `wlan0`;
- KDE Plasma Wayland reaches a stable desktop on the internal DSI panel;
- failure or termination of KWin leaves serial SSH usable and attempts to
  restore the text console;
- the exact V55 image above remains byte-for-byte intact.
