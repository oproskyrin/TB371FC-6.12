# Novatek touch and Lenovo AP500U port

AP500U support is a required part of the TB371FC Linux port. The tablet uses
one Novatek NT36532 SPI controller for capacitive touch and the active-pen
digitizer. The inking path is not a generic Bluetooth tablet: coordinates,
pressure, hover distance, tilt and both barrel buttons arrive in the Novatek
SPI report. Bluetooth pairing and any remote-button/battery service are a
separate userspace/HID task. Magnetic charging is a third, independent path
through an NXP CTN730 NFC wireless-power controller.

## Confirmed stock interface

The stock DT and the connected ZUI 16.0.474 tablet agree on:

- QUPv3 SE14 SPI at 9.6 MHz;
- SPI pins GPIO40-43, active-low reset GPIO56 and IRQ GPIO68;
- `compatible = "novatek,NVT-ts-spi"`;
- `novatek,pen-support` and `novatek,stylus-resol-double`;
- a 60x40 sensing matrix and NT36532 single/cascade memory maps;
- touch input: 10 contacts, X 0..18400, Y 0..29440, touch-major 0..255;
- pen input: X 0..18400, Y 0..29440, pressure 0..4095, hover distance
  0..1, X/Y tilt -60..60, `BTN_STYLUS` and `BTN_STYLUS2`.

Lenovo's source explains the otherwise unusual ranges: TB371FC uses a
108-byte, 10x super-resolution report instead of the older 65-byte Novatek
format. Base geometry is 1840x2944, and both touch and pen are exposed at
18400x29440. Reusing the Xiaomi Pad 5 parser unchanged would therefore lose
precision and decode pressure/width from the wrong bytes.

## Linux 7.1 implementation

`mainline-port/patches/0002-input-touchscreen-add-nt36523-spi-pen.patch`
ports the cleaned SM8150-mainline Novatek SPI driver to Linux 7.1 and adds the
TB371FC-specific pieces:

- descriptor-based reset/IRQ GPIO handling;
- standard kernel PM callbacks, without Xiaomi DRM notifier dependencies;
- 108-byte super-resolution touch reports and 10x coordinate ranges;
- AP500U pressure, hover, tilt and two barrel-button events;
- NT36532 chip-ID matching and single/cascade memory maps;
- automatic BOE/Tianma `_6` firmware selection from panel-ID GPIO82;
- the newer NT36532 trim/reset register family;
- Lenovo's NT36532 firmware end-marker validation, three-byte CRC length and
  `0x56` auto-copy completion path;
- compatibility with the stock `stylus-resol-double` property.

The resulting AArch64 module `nt36523_ts.ko` compiles against Linux 7.1.8.
That mainline module is still compile-only; the first hardware evidence below
comes from the rebuilt Lenovo-derived 4.19.325 bridge kernel.

The reproducible 7.1.8 build produced a 222,808-byte module with SHA-256
`6fda240a8fe5e1d31723a4d44a176858c5403beb8c6bbf0b19ee931db1c4b06f`.

`sm8250-lenovo-tb371fc-touch-test.dtb` is a separate diagnostic variant. It
enables only SPI14 and the Novatek child on top of the conservative board DTS.
The normal DTB remains disabled, so an ordinary build cannot accidentally
probe the untested controller. The diagnostic initramfs includes and loads
`nt36523_ts` when this test DTB is selected. It also provides a static
`input-monitor` utility: run it without arguments to find the Novatek pen
event device, then pass that `/dev/input/eventN` path to inspect pressure,
hover, tilt and barrel-button reports.

## Firmware selection safety gate

The stock package contains several runtime firmware candidates. Lenovo's
TB371FC source selects only the `_6` pair and reads GPIO82:

| GPIO82 | Panel | Runtime firmware |
|---:|---|---|
| 0 | BOE | `novatek_ts_fw_boe_6.bin` |
| 1 | Tianma | `novatek_ts_tm_fw_6.bin` |

Both files are proprietary and remain outside Git. The driver now reads GPIO82
and selects the matching DT filename. The NT36532-specific auto-copy loader is
also ported. The mainline DTS still keeps SPI14 and its child disabled because
firmware loading, reset polarity and interrupt handling have not yet been
validated on hardware.

## Provenance

The initial cleaned driver comes from these SM8150-mainline commits:

- `7514687cf6dbf1ab6beac2d8f4c01aff48cf41a0` - initial NT36523 SPI driver;
- `25aa7c55b4f7f1e8745271705e5cbe1a933abaa3` - pen enable path;
- `f16d6f0a1f8d19d9017485b81914e46cd130c17c` - pen resolution metadata;
- `467818900080a7a868d879b45d19da2cdc22c572` - firmware timing update;
- `defb39db31e6e2de8d7319c77ad697f9581070bd` - newer Xiaomi pen scale.

TB371FC packet layout, 10x coordinates, NT36532 maps and firmware selection
come from Lenovo-derived source published by the earlier desktop Linux port:
<https://github.com/tb371fc-desktop/linux-android-msm-lenovo-p12>.

The recovered vendor overlay linked from [4PDA post #1751](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144438358)
adds `nxp,ctn730` at I2C address `0x28`, using reset GPIO84, enable GPIO160
and interrupt GPIO111. GPIO84 is why the board moves QCA6390 PCIe1 wake to
GPIO81. Mainline has no identified CTN730 driver, so this node remains absent
from the active DTS until a reviewable driver and binding exist.

## First runtime result

The 2026-08-10 firmware-equipped 4.19.325 diagnostic boot confirmed GPIO82=1
(Tianma), cascade NT36532 detection, successful loading of
`novatek_ts_tm_fw_6.bin`, firmware version `0x1a`, PID `0x6068`, and registration
of both `NVTCapacitiveTouchScreen` and `NVTCapacitivePen`. The reported X/Y
limits were 18400/29440. This proves the controller, firmware-selection path
and AP500U input endpoint; it does not yet prove live coordinates, pressure,
hover, tilt, buttons, palm rejection or magnetic charging.

## Remaining interactive test

The temporary boot test must verify, in this order:

1. ten-finger coordinates and edge coverage with `libinput debug-events`;
2. AP500U hover, pressure sweep, tilt and both barrel buttons with `evtest`;
3. palm rejection while writing and touch suppression near the pen;
4. suspend/resume and repeated firmware reloads;
5. Bluetooth pairing and any AP500U auxiliary button/battery interface;
6. CTN730 probe, pen-dock detection and bounded charging telemetry; never
   infer charging support merely from successful inking.

## V55 passive input evidence (2026-08-14)

The persistent Arch session kept the already-proven vendor input stack alive
without a DRM modeset. `/dev/input/event4` produced 1,470 touch events during
a bounded 300-second capture. `/dev/input/event5` is the registered
`NVTCapacitivePen` endpoint and `/proc/support_pen` currently reports
`Pen state 1!`.

This confirms a live touch event stream and the presence of the AP500U
endpoint. It does not yet prove AP500U pressure, hover, tilt, barrel buttons,
palm rejection or charging because no person was available to move the pen
during the capture. Those remain attended acceptance tests; no synthetic
event result may be recorded as hardware success.

## V56.1 attended touch result and V56.2 ABI fix

While Plasma was visibly running on V56.1, an attended `evtest` capture from
`/dev/input/event4` recorded real position, pressure, tracking-ID and
`BTN_TOUCH` transitions. The touchscreen hardware path is therefore working
end to end through the kernel input layer.

Plasma did not react because systemd-udevd could not populate `/run/udev/data`.
The V56.1 kernel has `# CONFIG_FHANDLE is not set`; systemd 261 requires that
kernel feature, and without udev metadata libinput does not attach event4 or
event5 to the Wayland seat. V56.2 enables `CONFIG_FHANDLE=y` and starts/settles
udev before Plasma. The remaining attended test is to confirm libinput touch
mapping and then exercise AP500U hover, pressure, tilt and both barrel buttons.
