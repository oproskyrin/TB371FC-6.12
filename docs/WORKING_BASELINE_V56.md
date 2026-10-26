# Working desktop baseline: V56.3 r2 / development r3.3

Status date: 2026-08-15 — r2 preserved as immutable rollback; r3.3 boot verified

V56.3 r2 is the successful immutable vendor-kernel desktop baseline for Lenovo
TB371FC. It is the reference for comparing hardware behavior while the Linux
6.12 LTS port is developed and the primary Linux rollback target after a
failed modern-kernel test. V56.2 and V55 remain unchanged as secondary rescue
baselines.

V56.3 r3.3 is the current development desktop. It keeps r2 untouched and adds
deterministic cleanup of failed KWin sessions, removal of obsolete persistent
hardware-rendering overrides and a guarded software-rendering fallback.

## Boot artifact

```text
D:\TB371FC-builds\arch-development-loader-v56-3-r2-community-simplefb-qca6390-kde-kexec-safe\tb371fc-arch-development-loader-v56-3-r2-community-simplefb-qca6390-kde-kexec-safe-recovery.img
size: 104857600 bytes
SHA-256: 39a088020bb69a8e44636603b1379160d89a6996aeb9e73605c2f602025ea666
kernel: 4.19.157-perf-v56.3+
```

Current development artifact:

```text
<repo>\artifacts\arch-development-loader-v56-3-r3-3-community-simplefb-qca6390-kde-kexec-safe\tb371fc-arch-development-loader-v56-3-r3-3-community-simplefb-qca6390-kde-kexec-safe-recovery.img
SHA-256: 2f31f5e76702e2a5c6b72204ca98dc7c67fd88ef593b7fdf45da2b88a1f7db24
kernel: 4.19.157-perf-v56.3+
```

Hardware verification on 2026-08-15: Arch root mounted, Wi-Fi obtained
`192.168.1.199`, SSH worked over Wi-Fi and USB ACM, KDE reported `ready`, and
KWin, Plasma Shell and Plasma Keyboard remained alive with
`LIBGL_ALWAYS_SOFTWARE=1`. The obsolete persistent renderer override was
ignored, its hardware marker was cleared, and the API 3 override was then
installed persistently on the microSD.

The image was booted successfully on hardware and restored after the r10
Linux 7 test. It reaches the persistent Arch
Linux ARM root on microSD, keeps the visible simplefb console available for
recovery and starts the KDE Plasma Wayland desktop.

## Hardware-proven functions

- internal 2944x1840 panel with a stable visible desktop;
- Arch Linux ARM persistent root and package manager;
- KDE Plasma Wayland login and desktop;
- QCA6390 Wi-Fi association and network SSH;
- guarded USB/serial development access from the rescue stage;
- Novatek capacitive touchscreen after calibration;
- AP500U pen input groundwork retained;
- Lenovo magnetic keyboard, touchpad, gestures and two-finger scroll;
- system timezone set to Asia/Yekaterinburg;
- Adreno 650 detected by KGSL;
- Turnip Vulkan 1.3 hardware rendering proven with `vulkaninfo`, Wayland
  `vkcube` and a Qt Quick Vulkan smoke test.

## Deliberate limitations

- KWin and the normal Plasma session stay on `llvmpipe`/software rendering;
- the internal mode currently exposed to KWin is approximately 52.54 Hz;
- a whole-shell Qt Quick Vulkan experiment produced an unstable image and was
  rolled back immediately;
- full desktop GPU acceleration is deferred to the Linux 6.12 LTS DRM_MSM port;
- camera, audio, Bluetooth, USB-C DisplayPort and all dock functions are not
  yet accepted as complete.

The successful GPU experiment is documented in
`diagnostics/v56-2-adreno650-kgsl-turnip-result-20260814.md`.
The translation of these hardware results into Linux 6.12 is tracked in
[MAINLINE_V56_MIGRATION.md](MAINLINE_V56_MIGRATION.md).

## Rollback hierarchy

1. V56.3 r2 is the primary rollback target and hardware-reference desktop.
2. V56.2 and V55 are secondary immutable rescue baselines.
3. The exact stock recovery/vbmeta pair remains the Android boot-chain
   recovery path.
4. Linux 6.12 images remain separate experimental payloads and must not replace
   either known-good artifact until they pass the same console, SSH, display,
   input and storage gates.

## Transition to Linux 6.12 LTS

The next modern-kernel line starts from the TB371FC Linux 6.12 donor branch
and ports the already proven Arch/microSD, USB ACM and SSH contract. First
prove boot, persistent root and SSH with panel/GPU disabled.
Then enable upstream DRM_MSM, Adreno 650/GMU firmware and native KMS in guarded
stages. The first graphical acceptance target is a stable hardware-accelerated
KWin session with a normal DRM render node; panel refresh modes and KDE follow
only after that contract is reliable.
