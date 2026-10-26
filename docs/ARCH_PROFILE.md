# Arch Linux ARM runtime profile

The final TB371FC userspace target is Arch Linux ARM with KDE Plasma 6 on
Wayland. The graphical profile is deliberately separate from the diagnostic
boot image: a broken display stack must never prevent access to the tablet.

## Bring-up stages

1. **Diagnostic initramfs** — BusyBox, USB gadget console, input monitor and
   firmware only. No package manager, display manager or writable rootfs.
2. **Minimal Arch** — systemd in `multi-user.target`, SSH/USB console,
   NetworkManager CLI and hardware diagnostic tools.
3. **Graphics validation** — Mesa/Freedreno and KWin Wayland started manually
   from a text login. No automatic graphical login.
4. **Normal tablet profile** — Plasma Desktop 6, Plasma Login Manager,
   Plasma Keyboard, PipeWire and the KDE network/Bluetooth controls.
5. **Optional mobile session** — `plasma-mobile` may be added as a second
   session after the desktop session is stable. It is not the default.

The 12.7-inch 2944x1840 panel, keyboard accessories, AP500U pen and external
DisplayPort make full Plasma Desktop a better default than a phone-style shell.
The initial scale target is 175-200%, but the exact value will be chosen after
native DSI is working.

## Package manifests

- `rootfs/packages-base.txt` contains the minimal recoverable Arch layer.
- `rootfs/packages-plasma.txt` adds the full Wayland tablet environment.
- `rootfs/packages-plasma-mobile.txt` is an optional second shell.

The manifests contain package names rather than pinned package archives. A
release build must resolve them against a dated Arch Linux ARM mirror and save
the resulting package versions and package-file hashes in its build manifest.
Run `python3 scripts/verify-arch-package-manifests.py` to reject stale package
names. Pass `--write-lock PATH` to record the repository and resolved versions
as build metadata; this lock alone does not replace package signature checks.

Current Arch Linux ARM carries native aarch64 Plasma 6 packages. Plasma's
current meta package uses Plasma Login Manager and Plasma Keyboard, so those
are preferred over an extra SDDM/Maliit configuration. SDDM remains a possible
recovery alternative, not part of the default image.

## Recovery layers

There are three separate rollback mechanisms:

- **Graphics failure:** add `systemd.unit=multi-user.target` to the kernel
  command line or select the console boot entry. Plasma and KWin are skipped,
  while USB console/SSH remains available.
- **Userspace update failure:** the eventual installed rootfs will use Btrfs
  subvolumes and a pre-update snapshot. Rollback changes only Linux userspace;
  Android partitions are untouched.
- **Boot failure:** restore the exact `recovery_b` and signed `vbmeta_b`
  backups described in `RECOVERY.md`. Filesystem snapshots cannot repair the
  boot chain.

Automatic graphical login stays disabled during bring-up. A release may offer
it later, after the lock screen, on-screen keyboard and suspend/resume have all
been tested.

## Session services

- Networking: NetworkManager with `plasma-nm`.
- Bluetooth: BlueZ with `bluedevil`.
- Audio and camera routing: PipeWire with WirePlumber.
- Graphics: Mesa Freedreno, KWin Wayland and Vulkan Freedreno where supported.
- Camera applications: libcamera/PipeWire after kernel sensor drivers exist.
- Input: libinput; AP500U pressure, hover, tilt and buttons come from the kernel
  input driver and do not depend on an X11 Wacom driver.

## References

- [Arch Linux ARM Plasma meta package](https://archlinuxarm.org/packages/any/plasma-meta)
- [Arch Linux ARM Plasma Desktop package](https://archlinuxarm.org/packages/aarch64/plasma-desktop)
- [Arch Linux ARM Plasma Login Manager](https://archlinuxarm.org/packages/aarch64/plasma-login-manager)
- [ArchWiki PipeWire](https://wiki.archlinux.org/title/PipeWire)

## Prepared Plasma subset (V55 and 12 GiB v2)

The current 6 GiB development root has been updated and contains the following
runtime baseline:

```text
plasma-workspace 6.7.4-1       plasma-desktop 6.7.4-1
kwin 6.7.4-5                   konsole 26.04.3-1
qt6-wayland 6.11.1-1          xorg-xwayland 24.1.13-1
networkmanager 1.58.0-1       bluez/bluez-utils 5.87-2
plasma-nm 6.7.4-1
```

`rootfs/packages-plasma-bringup.txt` records this console-first subset. The
full desktop manifest remains a later step because the current root has only
489 MiB free. No display manager or graphical target is enabled.

The verified 12 GiB v2 image extends that baseline with KScreen, Plasma PA,
Dolphin, the KDE portal, Mesa diagnostics, Freedreno Vulkan, PipeWire,
WirePlumber, ALSA, brightness, battery and power-profile tools. Its 633-package
manifest leaves 5.7 GiB free and passed the ARM64 rootfs, OpenSSH,
package-manifest and ext4 checks. Its SHA-256 is
`ae0fe97debbb6b6c485546dd130e9a9a15724784b41af3fb862bad1f1cf58b44`.
It is an offline replacement candidate only; it has not replaced the stable
6 GiB V55 microSD root. All 1,510 modules from the verified Linux 7.1.8-r4
release are staged under `/lib/modules/7.1.8-tb371fc`; none is loaded
automatically.

`rootfs/development-overlay/usr/local/sbin/start-tb371fc-plasma` is the only
approved first-session entry point. It refuses all kernels except
`7.*-tb371fc*`, requires a connected DSI connector and explicit acknowledgement,
and leaves the V55 4.19 console untouched. The first Plasma session therefore
cannot precede successful Linux 7.x DRM console validation. The development
init also refuses to launch the legacy DRM smoke test unless its volatile
opt-in marker is created explicitly, and Plasma refuses to start while that
test owns DRM master.
