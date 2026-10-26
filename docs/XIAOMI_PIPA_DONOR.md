# Xiaomi Pad 6 (`pipa`) donor map

## Why it is relevant

Xiaomi Pad 6 and Lenovo TB371FC use Qualcomm SM8250/Snapdragon 870 with the
Adreno 650 GPU. Linux 7.1.8 already contains the upstream
`sm8250-xiaomi-pipa.dts`, so `pipa` is a useful mainline reference rather than
only an Android-vendor donor.

Useful upstream/community references:

- <https://github.com/torvalds/linux/tree/master/arch/arm64/boot/dts/qcom>
- <https://git.mainlining.org/pipa-mainline/linux>
- <https://github.com/TheMojoMan/xiaomi-pipa>

## Components that can be reused or compared

| Area | Donor value | TB371FC rule |
| --- | --- | --- |
| ARM64/SM8250 boot | High | Reuse common SM8250 kernel configuration and boot fixes. |
| Adreno 650 GMU/GPU | High | Reuse mainline `gmu`, `gpu`, zap-shader and Freedreno expectations; keep Lenovo firmware path. |
| RPMh/interconnect/clocks | High | Reuse common SoC support; do not copy board regulator phandles blindly. |
| UFS and Venus | High | Compare enablement and firmware-loading order; use Lenovo firmware names. |
| USB PHY | Medium | Common SM8250 PHY drivers apply, but TB371FC Type-C mux, retimer and DP endpoints are board-specific. |
| KTZ8866 backlight | Medium/high | `pipa` confirms an upstream KTZ8866 implementation and useful ramp/bias properties. TB371FC has a dual-controller topology and different GPIO/I2C wiring. |
| PCIe/ath11k | Medium | Common PCIe and QCA6390/ath11k code is reusable. `pipa` enables PCIe0; TB371FC Wi-Fi uses PCIe1 and Lenovo-specific wake/power wiring. |
| KDE/Plasma userspace | High | Packaging, Mesa/Freedreno and desktop configuration are reusable after kernel DRM works. |

## Components that must remain Lenovo-specific

- dual-DSI NT36532 panel command tables, DSC PPS and timing;
- BOE/Tianma panel variant detection;
- display reset, bias and dual KTZ8866 sequencing;
- Novatek touch wiring and AP500U stylus path;
- keyboard-cover GPIO/I2C sequence;
- Type-C NB7VPQ904M/FSA4480 routing and DisplayPort endpoints;
- cameras, speaker amplifiers, battery gauge and board regulator map.

## Important limitation

The upstream `sm8250-xiaomi-pipa.dts` present in Linux 7.1.8 still declares a
`simple-framebuffer` and does not provide a ready native MDSS/DSI panel node.
Linux distributions do run on `pipa`, and current community images report
Freedreno/ath11k support, but that does not make its panel description a
drop-in solution for TB371FC. Use `pipa` primarily as an SM8250 GPU/platform
donor and as a checklist for userspace, not as a replacement board DTS.

## Integration order

1. Complete stable Linux 7 entry and initramfs/SSH.
2. Compare TB371FC GMU/GPU firmware and reserved-memory nodes with `pipa`.
3. Prove `/dev/dri/renderD128` and hardware Mesa rendering without native DSI.
4. Enable Lenovo dual-DSI/NT36532 separately.
5. Reuse `pipa` packaging ideas only after the Lenovo hardware matrix passes.
