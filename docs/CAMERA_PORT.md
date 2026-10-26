# Camera port

The TB371FC has two camera pipelines described by the exact ZUI 16.0.474 DT.
Mainline Linux 7.1 already contains the SM8250 CAMSS and CCI controllers, but
the fitted sensor models and their register tables must be confirmed before
any camera rail is enabled. The read-only Android capture completed on
2026-08-10 identifies this tablet as OFILM S5K4H7 rear plus TXD HI1339 front.

## Confirmed electrical topology

| Function | Rear camera | Front camera |
|---|---|---|
| CCI controller/bus | CCI0, master 0 | CCI1, master 0 |
| CSI PHY | CSIPHY0 | CSIPHY1 |
| MCLK | CAM_CC_MCLK0, 24 MHz, TLMM GPIO94 | CAM_CC_MCLK1, 24 MHz, TLMM GPIO95 |
| Reset | TLMM GPIO93 | TLMM GPIO92 |
| I/O rail | PM8150A L5, 1.8 V | PM8150A L5, 1.8 V |
| Analog rail | PM8150 L13, 2.8 V | PM8150A L4, 2.8 V |
| Digital rail | PM8150A L3, 1.2 V | PM8150A L2, 1.1 V |
| Focus rail | PM8150A L7, 2.8 V actuator | none in stock DT |
| Orientation | roll 90, pitch 0, yaw 180 | roll 270, pitch 0, yaw 0 |
| Extras | actuator, EEPROM, PM8150L flash/torch | EEPROM |

The stock CCI pins are GPIO101/102 for CCI0 and GPIO105/106 for CCI1. The
mainline `sm8250.dtsi` already has matching CCI pinctrl groups and disabled
CCI/CAMSS controller nodes.

## Stock-specific sensor candidates

The ZUI 16.0.474 `vendor` filesystem is an ext4 image with SHA-256
`384209bf046ee9c3ef06c5548ec689e991a723d65a629fe0a4ba0709a465f79c`.
A read-only inventory of that exact image reduces the broad multi-product
Lenovo source list to four CamX modules carrying the board code `AX6637`:

| Position | Module supplier and sensor | Stock companion hardware | CamX module SHA-256 |
|---|---|---|---|
| Rear | OFILM S5K4H7 | `gt9772_ofilm_s5k4h7` actuator, OFILM OTP/EEPROM, `AX6637_main_flash` | `0ebb6bb75fc86e1bd45e9c68881e095cec3042a6608e8fb4e1c3208cb36d38eb` |
| Rear | QTECH GC08A3 | `dw9718p_qtech_gc08a3` actuator, QTECH OTP/EEPROM, `AX6637_main_flash` | `f6a85bf7eb4e214d4c5b07893846b267a62ec3f312e35bb8a14bf7cae510c0bc` |
| Front | OFILM HI1339 | module-specific EEPROM configuration, no actuator or flash | `99ff4c931a7018c77cf79e71e0b677c9b22caf3379f9134192b132c8be131a0b` |
| Front | TXD HI1339 | module-specific EEPROM configuration, no actuator or flash | `351dcae4ff3f124e1de31a0440a47997131074da71989b79006357268694c6a5` |

These files prove the alternatives shipped for TB371FC/AX6637. On this
physical tablet, Android properties report `ofilm_s5k4h7_rear_i` and
`txd_hi1339_front_i`; CameraService reports two cameras and a 3264x2448 rear
stream. The stock DT uses generic Qualcomm camera slots and CamX probes the
binary definitions at runtime, so no sensor node is added to the normal Linux
DTB even after identification.

The CamX binaries identify themselves as `QTI Chromatix Header`, Parameter
Parser V2.0.0 build `1910091319`. They contain the sensor register tables,
power sequences, lane assignment and mode data, but the generated binary
schema must be decoded before those values can be treated as verified.

The probe prefix is now decoded directly from the binary records rather than
inferred from filenames:

| Sensor | CamX write address | Linux 7-bit address | ID register | Sensor ID | ID mask | Register address/data width |
|---|---:|---:|---:|---:|---:|---:|
| S5K4H7 | `0x20` | `0x10` | `0x0000` | `0x487b` | `0x0000ffff` | 2/2 bytes |
| GC08A3 | `0x62` | `0x31` | `0x03f0` | `0x08a3` | `0xffffffff` | 2/2 bytes |
| HI1339 (both suppliers) | `0x40` | `0x20` | `0x0716` | `0x1339` | `0xffffffff` | 2/2 bytes |

Together with the timing and power records below, this is enough to construct
separate identification DTBs. It is not enough to enable cameras in the normal
DTB: the fitted supplier still has to be identified on the live tablet and the
matching driver must complete an ID-only hardware probe before streaming.

The decoded stock stream records define two RAW10 (`CSI-2 DT 0x2b`) modes for
each candidate:

| Sensor | Full mode | Cropped mode |
|---|---:|---:|
| S5K4H7 | 3264x2448, crop origin 0,0 | 3264x1836, crop origin 0,306 |
| GC08A3 | 3264x2448, crop origin 0,0 | 3264x1836, crop origin 0,0 |
| HI1339 (both suppliers) | 4208x3120, crop origin 0,0 | 4208x2368, crop origin 0,376 |

The two HI1339 supplier modules have identical mode-table hashes. Their module
and EEPROM metadata still differ, so they remain separate fitted-hardware
possibilities until the live inventory identifies the supplier.

All candidates use four-lane D-PHY, not C-PHY. The packed CamX lane assignment
is `0x3210`, a straight logical-to-physical mapping `0,1,2,3`; the equivalent
mainline endpoint uses `data-lanes = <1 2 3 4>`. Both modes of each sensor share
the same timing record:

| Sensor | Line length / frame length | Maximum fps | Output pixel clock | D-PHY link frequency | Settle time |
|---|---:|---:|---:|---:|---:|
| S5K4H7 | 3580 / 2530 | 30.03 | 292.8 MHz | 366 MHz | 18 ns |
| GC08A3 | 3640 / 2548 | 30.19 | 268.8 MHz | 336 MHz | 20 ns |
| HI1339 (both suppliers) | 720 / 3332 | 30.01 | 499.2 MHz | 624 MHz | 20 ns |

The link frequency is derived from the stock `outputPixelClock` as
`outputPixelClock * RAW bit width / (2 * lane count)`. The 336 MHz GC08A3
result independently matches the first link-frequency entry in Linux 7.1's
upstream driver. Values such as HI1339's line length are retained exactly as
encoded rather than normalised to assumptions from another sensor family.

The stock power records are also decoded. The type values match
`enum msm_camera_power_seq_type` in the tablet's downstream camera kernel at
[commit `dfb2dc3f`](https://github.com/kotC9/tb371fc_kernel/commit/dfb2dc3f7d20ed123ba525c1c2ce2b446f73e14b);
the HAL loader confirms that each record is `(sequence type, configuration
value, delay in milliseconds)`.

| Sensor | Verified power-up sequence |
|---|---|
| S5K4H7 | VAF=1/1 ms, VANA=1/0 ms, VIO=1/0 ms, VDIG=1/5 ms, RESET=1/12 ms, MCLK=24 MHz/10 ms |
| GC08A3 | VAF=1/1 ms, VIO=1/1 ms, VDIG=1/5 ms, VANA=1/5 ms, RESET=1/1 ms, MCLK=24 MHz/5 ms |
| HI1339 (both suppliers) | RESET=0/1 ms, VIO=1/1 ms, VANA=1/1 ms, VDIG=1/1 ms, MCLK=24 MHz/1 ms, RESET=1/10 ms |

| Sensor | Verified power-down sequence |
|---|---|
| S5K4H7 | VAF=0/1 ms, MCLK=0/1 ms, RESET=0/1 ms, VDIG=0/0 ms, VIO=0/0 ms, VANA=0/0 ms |
| GC08A3 | VAF=0/1 ms, MCLK=0/5 ms, RESET=0/1 ms, VANA=0/5 ms, VDIG=0/5 ms, VIO=0/1 ms |
| HI1339 (both suppliers) | RESET=0/1 ms, MCLK=0/1 ms, VDIG=0/1 ms, VANA=0/1 ms, VIO=0/1 ms |

These sequences agree with the rear/front regulator sets and 24 MHz clocks in
the stock DT. They are preserved in stock order; no generic ordering is
substituted. The rear VAF step must be coordinated with the supplier-specific
actuator rather than enabled in the normal DT before identification.

`scripts/capture-camera-inventory.ps1` performs a read-only Android capture of
`/sys/hwinfo/hardwareinfo`, CameraService state, camera properties and filtered
Camera HAL logs. That capture is the gate for choosing the sensor drivers.

## Reproducible stock inspection

The proprietary files are not committed or redistributed. They can be
recovered locally from an owned stock package and stored outside the Git tree:

```sh
sudo ./scripts/inspect-stock-camera.sh VENDOR_EXT4_IMAGE ODM_EXT4_IMAGE
sudo ./scripts/extract-stock-camera-metadata.sh \
  VENDOR_EXT4_IMAGE /mnt/d/TB371FC-reference/stock-camera-16.0.474
./scripts/analyze-stock-camera.sh \
  /mnt/d/TB371FC-reference/stock-camera-16.0.474
./scripts/decode-camx-sensor-probe.py \
  "/mnt/d/TB371FC-reference/stock-camera-16.0.474/lib64/camera/com.qti.sensormodule.AX6637_qtech_gc08a3_main.bin"
./scripts/compare-gc08a3-registers.py \
  "/mnt/d/TB371FC-reference/stock-camera-16.0.474/lib64/camera/com.qti.sensormodule.AX6637_qtech_gc08a3_main.bin" \
  /path/to/linux-7.1/drivers/media/i2c/gc08a3.c \
  --verify-tb371fc
```

Extraction mounts the source `ro,noload`, refuses to overwrite an existing
directory, copies only the 11 AX6637 sensor/module/EEPROM files plus the camera
service, HAL and Lenovo initialization script, and writes a SHA-256 manifest.
The current verified extraction occupies about 11 MiB on `D:`.
Its expected hashes are recorded without the proprietary payloads in
`reference-manifests/stock-camera-16.0.474.SHA256SUMS`.

The decoder validates the declared file size, all three section bounds, the
24-byte section records, every 72-byte symbol record and the referenced sensor
name before reporting the probe prefix, referenced power-up/down sequences,
resolution timing, lane assignment and derived D-PHY link frequency.
`--symbols` emits a payload-free symbol directory for further reverse
engineering; `--raw-root` exposes the remaining aligned root slots without
assigning unproven field names. `--register-table` decodes a selected local
`regSetting` symbol, including its referenced data and delay arrays, without
writing proprietary output into the repository.

The comparison helper resolves the stock init and two mode-table references
from the CamX symbol graph, reduces repeated writes to final register maps and
checks the exact differences documented below. It rejects a non-GC08A3 module,
non-write operations, slave-address changes, delayed writes and unexpected
Linux table structure instead of silently producing a loose comparison.

## Mainline driver status

- SM8250 CAMSS, CSIPHY0/1, VFE and CCI0/1 support is present in Linux 7.1.
- Linux 7.1 contains an upstream `galaxycore,gc08a3` V4L2 driver: chip ID
  `0x08a3`, four CSI-2 lanes, 24 MHz input clock, and 3264x2448@30 plus
  1920x1080@60 modes. `CONFIG_VIDEO_GC08A3=m` is staged in our config, but it
  cannot probe because all experimental sensor nodes remain disabled.
- The apparent stock/upstream GC08A3 table-size difference is mostly ordering
  and repeated writes. The 263-record stock init table contains every final
  value from Linux 7.1's 259-record common table plus four timing-register
  writes. After applying init plus the full-resolution mode, both sides have
  exactly the same 275 final register addresses. Only `0x009a` (`0x00` stock,
  `0x66` upstream) and `0x0336` (`0x72` stock, `0x70` upstream) differ.
- Relative to stock full resolution, the 3264x1836 crop changes only five final
  registers: `0x0336` from `0x72` to `0x70`, output height `0x034e/0x034f` from
  `0x0990` to `0x072c`, and vertical offset `0x0351/0x0352` from `0x0006` to
  `0x0138`. This makes a clean Lenovo mode extension feasible without copying
  hundreds of redundant register writes.
- Linux 7.1 does not contain dedicated S5K4H7 or HI1339 drivers. The project
  now carries an exact S5K4H7 V4L2 CCI driver with the stock 3264x2448 and
  3264x1836 tables, controls and ordered VANA/VIO/VDIG/reset/MCLK sequence.
  `scripts/verify-s5k4h7-driver.py` compares every table write against the
  locally owned CamX module. The fitted TXD HI1339 driver is the next camera
  task.
- libcamera/PipeWire userspace can only be configured after both V4L2 sensor
  subdevices bind and the CAMSS media graph produces raw frames.

## Safe activation gate

1. Capture the exact front/rear module labels and Camera HAL sensor IDs.
2. Decode or independently confirm I2C slave addresses, CSI lane maps, link
   frequencies, native modes and register tables from the matching stock CamX
   module.
3. Port or select exact V4L2 sensor drivers and validate their power sequence
   against the voltage table above.
4. Add sensor and endpoint nodes with `status = "disabled"`, compile and check
   schemas before creating a separate camera-test DTB.
5. First hardware test: CCI identification only, with streaming and flash
   disabled. Confirm every rail returns to zero/idle after probe.
6. Test raw streaming before autofocus, flash, ISP tuning or camera apps.

The normal TB371FC DTB must not enable CCI, CAMSS, sensor regulators or flash
until this gate is complete.

## S5K4H7 diagnostic DTB

`sm8250-lenovo-tb371fc-s5k4h7-test.dts` is a separate, non-installable rear
camera variant for the fitted OFILM S5K4H7. It enables CAMSS, CCI0 master 0,
the three sensor rails, GPIO93 reset and GPIO94 24 MHz MCLK. It deliberately
leaves the actuator/VAF rail, EEPROM and flash disabled. The normal TB371FC
DTB remains unchanged.

The endpoint uses the verified `0x10` I2C address, CSIPHY0, four straight
D-PHY lanes and 366 MHz link frequency. Linux 7.1.8 compiled both the driver
and DTB; the binding example and diagnostic tree pass `dtschema` 2026.6, and
`checkpatch.pl` reports no driver errors, warnings or checks. The focused
module build has no full kernel `Module.symvers`, so its `.ko` is not a
loadable release artifact; a complete kernel build remains required before a
tablet probe.

The retained test DTB is
`D:\TB371FC-builds\camera-7.1.8\sm8250-lenovo-tb371fc-s5k4h7-test.dtb`,
127,018 bytes, SHA-256
`6fe7798e753af68a2c306bbbcf6fd684a4cefa0a39adfa43a96a03782740e6ce`.
It is a diagnostic build artifact, not an image to flash.

## GC08A3 diagnostic DTB

`sm8250-lenovo-tb371fc-gc08a3-test.dts` is a separate, non-installable rear
camera identification variant. It enables only CAMSS, CCI0 master 0 and the
GC08A3's analog, digital and I/O rails. The actuator/VAF rail, EEPROM and flash
remain disabled. It must only be selected after Android identifies the fitted
rear module as QTECH GC08A3; the normal DTB remains unchanged.

The variant encodes the verified `0x31` I2C address, GPIO93 RESETB, GPIO94
24 MHz MCLK, CSIPHY0, four straight D-PHY lanes and 336 MHz link frequency.
Mainline CAMSS uses zero-based receiver lanes `<0 1 2 3>` while the standard
sensor endpoint uses `<1 2 3 4>`. CAMSS analog supplies follow the SM8250
binding example: PM8150 L5 at 0.88 V and L9 at 1.2 V.

Linux 7.1.8 compiled the variant successfully and `dtschema` 2026.6 validated
it with `CHECK_DTBS=y` against both `qcom,sm8250-camss.yaml` and
`galaxycore,gc08a3.yaml`. The retained local artifact is
`D:\TB371FC-builds\camera-7.1.8\sm8250-lenovo-tb371fc-gc08a3-test.dtb`, size
127,047 bytes, SHA-256
`59b3c44dec3252ff339836fa0f8bd9c8bab8905fcb60a9b0a3133001e9e3ba56`.
An unfiltered schema run also completes, with only the already known missing
upstream schemas for the new TB371FC board compatible, Novatek touch and
TFA9894 codecs; it reports no additional camera-node warning.
