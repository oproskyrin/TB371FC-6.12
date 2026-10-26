# V56 findings carried into Linux 6.12 LTS

Status date: 2026-08-15

The project target changed from the experimental Linux 7.1.8 line to Linux
6.12 LTS. The 7.1.8 artifacts remain diagnostic evidence only. Linux 6.12 is
the integration target because a TB371FC-specific donor branch already exists
and the kernel series provides the upstream DRM MSM/Freedreno architecture
needed for a normal accelerated Plasma session.

V56.2 remains the accepted hardware-reference desktop.  The modern kernel does
not copy its downstream KGSL/SDE implementation; it carries each proven result
through the corresponding upstream subsystem.

| V56 hardware result | Linux 6.12 implementation | Status |
|---|---|---|
| Adreno 650 firmware and hardware Vulkan | `DRM_MSM`, A650 GMU and the board `a650_zap.mbn` path | Staged; driver and configuration compile, hardware test pending |
| 2944x1840 internal panel | Dual DSI, DSC 1.1, NT36532 panel extension and dual KTZ8866 backlights | Staged behind the guarded display test |
| Calibrated capacitive touch and AP500U groundwork | Novatek NT36523/NT36532 SPI input driver plus userspace calibration | Driver compiles; hardware test pending |
| QCA6390 Wi-Fi and network SSH | Upstream `ath11k_pci`, board firmware and USB rescue/SSH path | Staged; first mainline association pending |
| Lenovo keyboard/touchpad, VID:PID `17ef:6175` | I2C13 HID at `0x60`, IRQ GPIO110, reset GPIO114 and wake GPIO108 | Added and compile-tested in r7 source |
| KDE Plasma Wayland | Normal DRM render node and stock Mesa/Freedreno | Userspace retained; launch remains gated until KMS and GPU pass |
| Asia/Yekaterinburg timezone | Arch userspace timezone configuration | Retained; not a kernel setting |

## Keyboard evidence and implementation

The stock overlay describes QUPv3 SE13 at 1 MHz and an I2C-HID device at
`0x60`.  The running V56.2 system independently confirmed bus device
`5-0060`, VID:PID `17ef:6175` and a level interrupt on TLMM GPIO110.  Driving
physical GPIO114 and GPIO108 high made the keyboard, touchpad and consumer
controls operational.

The previous 7.1.8 experiment contains the following board description work,
which must be rebased and audited for Linux 6.12 rather than copied blindly:

- a real `keyboard-cover@60` node under `&i2c13`;
- `reset-gpios = <&tlmm 114 GPIO_ACTIVE_LOW>` so deassertion is physical high;
- `wake-gpios = <&tlmm 108 GPIO_ACTIVE_HIGH>`;
- level-low IRQ GPIO110, HID descriptor address `0x1` and a 120 ms settle time;
- an optional `wake-gpios` extension to `i2c-hid-of` with suspend/resume power
  sequencing;
- built-in generic HID, HID multitouch and I2C-HID OF support.

The driver object, decoded board DTB and full r7 release compile correctly.
The offline verifier checks the exact compiled GPIO/IRQ/delay contract. This
is not yet a hardware result for Linux 6.12. A later attended test must verify
cold boot, detach/reattach and suspend/resume.

## Deliberately not copied from V56.2

- The global `llvmpipe`/Qt Quick software fallback is not the target for the
  modern image.
- The experimental KGSL Mesa build remains an isolated V56 diagnostic and is
  not installed system-wide.
- Downstream SDE and KGSL interfaces are replaced by upstream DRM_MSM and a
  standard render node, which is required before enabling accelerated Plasma.

## Boot order

1. Keep V55 and V56.2 unchanged.
2. Prove the existing r4 Arch/microSD/USB-SSH gate with display and GPU off.
3. Import only verified board data into the TB371FC Linux 6.12 donor branch.
4. Prove kernel boot, Arch root and SSH before enabling display or GPU.
5. Use an attended guarded DRM_MSM test before enabling automatic KDE.
