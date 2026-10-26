# TB371FC V56: QCA6390 and guarded KDE

Status date: 2026-08-14 — V56.2 accepted on hardware

V56.2 is the successful desktop baseline on the physically proven
community/vendor `4.19.157` display path. It does not overwrite V55, which
remains the immutable rescue fallback. The accepted state is summarized in
`WORKING_BASELINE_V56.md`.

Adreno 650 hardware Vulkan was also proven through a KGSL-aware Mesa 26.2.0
test build after restoring the downstream firmware lookup names.
`vulkaninfo`, Wayland `vkcube` and a Qt Quick Vulkan smoke test succeeded. A
whole-`plasmashell` Vulkan experiment produced an unstable image and was
rolled back to the software renderer. Full desktop acceleration is therefore
assigned to the Linux 7.x DRM_MSM port. See
`diagnostics/v56-2-adreno650-kgsl-turnip-result-20260814.md`.

The candidate recovery is now built at:

```text
D:\TB371FC-builds\arch-development-loader-v56-community-simplefb-qca6390-kde\tb371fc-arch-development-loader-v56-community-simplefb-qca6390-kde-recovery.img
size: 104857600 bytes
SHA-256: 943a658b99065d59fd40c56a3f792938aa306669d8963511559d3a07942c8cd5
hardware status: OFFLINE VERIFIED; NOT BOOTED
```

## Frozen fallback

The exact V55 recovery image remains at SHA-256
`c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5`.
It was rechecked before starting V56 work.

## Separate build contract

- source: `/root/tb371fc-desktop-v56-kde-wlan-src`;
- output: `/root/tb371fc-desktop-v56-kde-wlan-out`;
- release staging: `/root/tb371fc-desktop-v56-kde-wlan-release`;
- expected release prefix: `4.19.157-perf-v56`;
- base commit: `bf6d1ec43ec1ae2781351cb5179ff73793e441a3`;
- compiler: Snapdragon Clang 10.0.7;
- V55 source and `/root/tb371fc-desktop-working-out-v49` are read-only inputs.

The build imports `qcacld-3.0`, `qca-wifi-host-cmn` and `fw-api` together from
Lenovo's 4.19.325 tree. Configuration enables `CNSS_QCA6390` and builds the
`qca6390` QCACLD profile as signed module `wlan.ko`.

The first compile exposed four newer stable-kernel helper names used by the
Lenovo WLAN source: `nla_parse_deprecated`,
`nla_parse_nested_deprecated`, `nla_nest_start_noflag` and
`ktime_get_boottime_ns`. Patch `0023` backports aliases with the semantics of
the older 4.19.157 APIs. This is a source compatibility correction, not a
change to panel timing or the V55 boot path.

Final component hashes are stored beside the recovery in `SHA256SUMS`.
Important anchors are:

| Component | SHA-256 |
| --- | --- |
| V56 Image | `33ae3fa2b0407dbbb31f6e03a435792d7a3eb2c058ef6bb68ee038d8cef600a9` |
| signed/stripped `wlan.ko` | `7286ee0aa828815dc04134d2f122851f5c277ea366dc916805d5458f4b2fbbf1` |
| V56 initramfs | `71177d1163ce61ac10c0e6f5100ec2fdfb7b9e2ab5c4d79193989ba3e27f116f` |
| unchanged V55 DTB | `176e6117698582c79795c3e2ef73079cd0c35cce683358aa554bf26a2e611e39` |
| unchanged V55 recovery DTBO | `fbf7d0c2f2fe0f90040f6fb6675ccbf456b7eddeb2a293168f7653c9ff6ffc59` |

## Runtime order

1. Display the proven simplefb console.
2. Mount the Arch loop root from microSD.
3. Start key-only OpenSSH and the CDC ACM serial gate.
4. Load the V56-signed `wlan.ko` and start system D-Bus/NetworkManager.
5. Start seatd and Plasma Wayland only on the exact V56 kernel.
6. Keep a watchdog on the Plasma process and internal DSI connector.
7. If Plasma exits or DSI disconnects, terminate the graphical session,
   switch back to VT1 and leave serial SSH running.

The first KDE boot defaults to Mesa software rendering to separate display
modesetting from GPU acceleration. Hardware GL can be enabled later with the
explicit `/etc/tb371fc/enable-v56-hardware-gl` marker after the desktop is
visibly stable.

## Security and persistence

The connection profile is stored only on the persistent Arch filesystem with
owner `root:root` and mode `0600`. No SSID password is included in source,
initramfs, diagnostics or checksums. V56 listens for public-key SSH on WLAN in
addition to retaining the serial tunnel.

## Hardware acceptance test

Do not flash or reboot until the kernel, module and recovery package pass
offline unpacking, module-vermagic, script-syntax, hash and V55-integrity
checks. The first V56 boot must be attended so the panel, KDE and fallback can
be observed directly.

Those offline checks now pass, including the temporary-launch allowlist and a
second verification of all V55/Android rollback hashes. The only remaining
gate is the attended hardware boot.

## Hardware result and V56.1 follow-up

V56 subsequently booted and preserved its console/Arch/serial-SSH path. KDE
6.7.4, KWin, seatd, D-Bus and NetworkManager all ran, but the internal DSI
connector remained kernel-disabled. The decisive errors were an SDE
`rsvp_nxt` poll timeout followed by `RM failed ... rc = -22`: KWin's independent
userspace `DRM_MODE_ATOMIC_TEST_ONLY` probes were treated as pending real
commits. One guarded V56 WLAN `ON` request also rebooted the tablet because V56
did not yet include the no-SSR guard. Full evidence is in
`diagnostics/v56-hardware-kde-wifi-result-20260814.md`.

V56.1 was then hardware-proven. The internal DSI connector became enabled and
Plasma Wayland rendered correctly at 2944x1840. QCA6390 reached firmware-ready,
created `wlan0`, associated over WPA2/Wi-Fi 6 and provided DHCP, DNS, HTTPS and
direct public-key SSH. The recovery SHA-256 remains
`0cdf91ede1f046e2e842e3d6b21162c32b2e8b4562da8f6921c15718b4e3a710`.

The remaining V56.1 desktop blocker is udev input discovery. Raw Novatek touch
events are correct, but the kernel was built without `CONFIG_FHANDLE`, causing
systemd-udevd 261.2 to fail and leaving `/run/udev/data` empty. V56.2 preserves
the proven display/WLAN stack, enables `CONFIG_FHANDLE=y`, settles udev before
Plasma and retains a bounded direct Wi-Fi fallback.

The offline-verified V56.2 image is 104857600 bytes with SHA-256
`b0cd0e66e9bade28c56c8215ed4f39503cf4649e02639cb72e779e6b4699447b`.
V55 and V56.1 were reverified unchanged. V56.2 has not been flashed and needs
its own explicit temporary-write approval.
