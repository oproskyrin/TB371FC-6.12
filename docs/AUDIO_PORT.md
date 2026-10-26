# TFA9894 speaker port

The TB371FC has four NXP/Goodix TFA9894 N1A1 smart amplifiers. This file
records the evidence needed to bring them up without loading the wrong speaker
calibration or writing amplifier MTP.

## Runtime status on V56.3

The 2026-08-15 hardware check on the working `4.19.157-perf-v56.3+`
desktop baseline confirmed that internal audio is **not working yet**:

- `/proc/asound/cards` reports `--- no soundcards ---`;
- `/dev/snd` contains only the ALSA timer and no PCM/control devices;
- `CONFIG_SND_SOC_QCOM` is disabled in the V56.3 kernel;
- `CONFIG_SND_USB_AUDIO=y` and `CONFIG_SND_USB_AUDIO_QMI=y`, so a USB audio
  adapter/headset is the safest short-term playback path to test.

This is not a PipeWire-only failure. The vendor bridge needs the SM8250
Qualcomm ASoC/QDSP6 machine path, its topology and routing, and the exact
TFA9894 codec links before the four internal speakers can appear as an ALSA
card. Do not enable the amplifiers merely to make an ALSA card appear: the
calibration and TDM safety gate below still applies.

## Confirmed hardware

All four devices are on the stock `i2c15` bus and share the primary TDM audio
link:

| Position | I2C address | Reset GPIO |
|---|---:|---:|
| Primary left | `0x34` | TLMM 115 |
| Primary right | `0x35` | TLMM 117 |
| Secondary left | `0x36` | TLMM 118 |
| Secondary right | `0x37` | TLMM 116 |

The stock primary TDM clock is 6.144 MHz. The exact slot map and channel order
still need to be captured from Android before playback is enabled.

## Stock calibration selection

ZUI 16.0.474 contains two different TFA container files. They are not
interchangeable acoustic presets:

| Container | SHA-256 | Profiles |
|---|---|---|
| `tfa98xx_YC.cnt` | `8e7d4a1c4d9587382150cd949e202100d64e17447719a6b6efdb7611ffb952f5` | `pri_l`, `pri_r`, `sec_l`, `sec_r` |
| `tfa98xx_QS.cnt` | `a3f641609cbb617ea2c3169e5a9edc6c04f89a342e99fd96dacc44f216cdfa81` | `pri_l`, `pri_r`, `sec_l`, `sec_r` |

Static analysis of the unstripped stock `audio_tfa98xx.ko` establishes the
selection contract:

- the driver requests a hard-coded legacy Linux GPIO number `1171` under the
  label `tfa98xx_spk_id`, configures it as input, reads its raw value and frees
  it;
- raw value `0` selects module parameter `fw_name_first`, whose stock default
  is `tfa98xx_YC.cnt`;
- a non-zero raw value selects `fw_name_second`, whose stock default is
  `tfa98xx_QS.cnt`.

The number `1171` is from the vendor kernel's global GPIO namespace. It must be
mapped to the corresponding PMIC/TLMM controller and pin from live Android;
it must not be copied into mainline DT as though it were a TLMM pin number.

## Linux 7.1 implementation

`mainline-port/patches/0003-wip-ASoC-codecs-add-support-for-TFA98xx-based-on-dow.patch`
imports the current sdm845-mainline community driver from commit
`121d75c9b5d8bbdcd320290529d6e1347a23e28b`. It is a temporary,
downstream-derived driver rather than an upstream-quality codec driver.

The driver:

- builds as `snd-soc-tfa98xx.ko` with `CONFIG_SND_SOC_TFA98XX=m`;
- advertises the `nxp,tfa9894` device-tree alias;
- accepts one `fw_name` module parameter, so the selected container will be
  supplied explicitly from `lenovo/tb371fc/` after speaker-ID detection;
- currently produces compiler warnings typical of the imported WIP source,
  but no build errors.

The reproducible Linux 7.1.8 build produced an 848,064-byte module with
SHA-256 `a3310646dabf67f9dd22012b345b6bff11cc81b8eba42c83b7b27a5eb17d02c8`
and vermagic `7.1.8-tb371fc-dirty`.

The four exact codec nodes are present in the TB371FC DTS but have
`status = "disabled"`. This is intentional: merely probing the codec can
toggle reset lines and load the DSP container.

## Safe activation gate

Do not enable the nodes or connect the speaker DAI links until all of these are
true:

1. Read and map vendor GPIO `1171`, and record whether this tablet is YC or QS.
2. Verify the selected container hash against the table above.
3. Capture the stock TDM slot count, slot width, TX/RX masks and channel order.
4. Confirm reset polarity and idle state for all four amplifiers.
5. Disable all calibration, factory-test and MTP-writing controls for the first
   Linux probe.
6. Probe at zero playback volume, inspect revision/impedance telemetry, then
   test one channel at a time with a bounded signal.

Until this gate passes, the compile-tested module is transport groundwork only;
speaker playback is not yet claimed working.

## References

- [sdm845-mainline TFA98xx driver commit](https://gitlab.com/sdm845-mainline/linux/-/commit/121d75c9b5d8bbdcd320290529d6e1347a23e28b)
- [Goodix TFA9894 product page](https://www.goodix.com/en/product/audio/smart_amplifier/tfa9894)
