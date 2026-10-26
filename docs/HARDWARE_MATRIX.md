# Lenovo TB371FC native Linux hardware matrix

Target: Arch Linux ARM on stable Linux 7.1.y. “Reported working” means demonstrated by the independent 2026 port on 4PDA; it is not yet a result of our local build.

| Subsystem | Exact hardware / wiring | Evidence | Upstream path | Local status |
|---|---|---|---|---|
| SoC / GPU | Qualcomm SM8250 (Snapdragon 870), Adreno 650 | Android properties and stock DT | `qcom/sm8250`, MSM DRM/Freedreno | GMU/GPU enabled and stock firmware packaged; not boot-tested |
| Internal display | Dual DSI 2944x1840, BOE or Tianma NT36532, DSC 1.1; Android advertises up to 144 Hz | Live Android DRM, exact stock panel DTS and 4.19.325 diagnostic boot | Extended upstream NT36523 dual-DSI driver | Vendor bridge boot identified Tianma and exposed 30/60/120 Hz; 140/144 Hz was not exposed there. MSM DRM fbdev plus `tty0` is now built for the next test so Linux can replace the retained Lenovo splash; hardware validation is pending. Mainline graph remains staged |
| Touch / AP500U inking | Novatek NT36532 SPI at 9.6 MHz on GPIO40-43, reset GPIO56, IRQ GPIO68; 10x 18400x29440 reports; pressure 4095, hover, tilt +/-60, two buttons | Live Android input capabilities, exact stock overlay, source and 4.19.325 diagnostic boot | Out-of-tree Novatek SPI input driver, later upstream cleanup | Tianma cascade controller firmware loaded successfully and both touch/AP500U input nodes registered on hardware; live event quality still needs interactive validation; Linux 7.1 port remains compile-tested |
| Magnetic keyboard / touchpad | Lenovo keyboard cover I2C-HID at QUPv3 SE13 address `0x60`, VID:PID `17ef:6175`; reset GPIO114, wake GPIO108, level IRQ GPIO110 | Exact stock overlay and working V56.2 keyboard/touchpad/gestures | `i2c-hid-of`, generic HID and HID multitouch | V56.2 hardware-proven. Linux 7.1.8 r7 full release and exact compiled GPIO contract are offline verified; cold boot, hotplug and suspend/resume remain to be tested |
| AP500U dock charging | NXP CTN730 NFC wireless-charging transmitter at I2C `0x28`; reset GPIO84, enable GPIO160, IRQ GPIO111. Lenovo moved PCIe1 wake from GPIO84 to GPIO81 to free this pin | Vendor-derived overlay and [4PDA post #1751](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144438358) | No upstream CTN730 driver identified; requires clean-room/vendor-driver study | PCIe1 remap is already correct; CTN730 is not enabled and magnetic pen charging is not yet supported |
| Storage | UFS | Stock DT, Android partitions and 4.19.325 diagnostic boot | `ufshcd-qcom` | UFS and 119 GiB microSD enumerated on the vendor bridge; mainline still untested |
| Wi-Fi | Qualcomm QCA6390 over PCIe 1; wake GPIO 81 | Stock DT, live Android, 6.12 port notes and 4.19.325 diagnostic boot | `ath11k_pci` + board/firmware blobs | Downstream bridge now reaches the complete single-client WLFW handshake and loads the stock QCACLD INI. Hardware created `wlan0`, `p2p0` and `wifi-aware0`; `phy0` was unblocked and firmware reported 802.11ax support. Missing optional `wlan_mac.bin` caused a firmware-class delay and fallback MAC, then the unused device entered clean idle shutdown. Scan/association and stable-7.1 `ath11k` remain untested. |
| Bluetooth | QCA6390 on UART6; enable GPIO 21 | Stock DT, live Android and 4.19.325 diagnostic boot | `qcom,qca6390-bt` + `btqca` firmware | `bt_power` rfkill and `ttyHS0` on `msm_geni_serial` confirmed; soft-blocked in diagnostic Linux, no `hci0` yet |
| USB-C data | DWC3 at `a600000`, dual-role | Live Android USB HAL and 4.19.325 diagnostic boot | DWC3 + PM8150B Type-C | USB NCM device mode and Type-C partner verified; host mode/dock remains untested |
| USB-C charging / PD | PM8150B Type-C/PD; Android reports sink/device and source/host combinations | Live Android USB HAL, stock DT and 4.19.325 diagnostic boot | PM8150B Type-C, power-supply framework | Sink/device and charging observed, but external fuel gauge did not bind, so SOC is invalid and charging policy is not yet safe |
| External display | DP Alt Mode; ONNN redriver at I2C 0x1c; DP connector exists as `DP-1` | Live sysfs, stock DT, 4PDA reports working hubs/adapters | MSM DP + QMP combo PHY + NB7VPQ904M-compatible redriver | DRM/PHY/Type-C graph staged; needs hardware test |
| USB-C analog audio | FSA4480 at I2C 0x42 | Live driver binding and stock DT | `TYPEC_MUX_FSA4480` | Node staged; audio routing pending |
| Speakers | Four NXP TFA9894 N1A1 smart amps at 0x34-0x37; reset GPIOs 115/117/118/116; YC/QS ID is vendor GPIO 1171 | Stock DT, firmware containers and static analysis of stock `audio_tfa98xx.ko` | Temporary sdm845-mainline downstream-derived TFA98xx codec, later proper upstream driver | V56.3 hardware check: no ALSA cards (`/dev/snd` has only `timer`) because `CONFIG_SND_SOC_QCOM` and the SM8250 machine path are absent. USB audio is built in as a temporary route. Linux 7 TFA98xx module and disabled DT nodes compile; YC/QS GPIO mapping and TDM slots must be captured before probing |
| Fuel gauge | Mitsumi MM8013C06 at I2C 0x55 | Exact stock overlay and 4.19.325 diagnostic boot | `FUEL_GAUGE_MM8013` | Corrected from the J716F BQ27541 assumption; diagnostic boot reports `exfg not found` and invalid SOC, so binding/power sequencing is a blocker |
| Cameras | Fitted rear: OFILM S5K4H7 on CCI0/CSIPHY0, MCLK GPIO94/reset GPIO93. Fitted front: TXD HI1339 on CCI1/CSIPHY1, MCLK GPIO95/reset GPIO92 | Read-only Android properties and CameraService; exact stock DT and AX6637 CamX modules | SM8250 CAMSS/CCI plus new exact S5K4H7/HI1339 V4L2 drivers; libcamera | S5K4H7 driver, binding and isolated DTB compile and validate; HI1339 pending; normal DT remains disabled |
| Sensors | Bosch BMI3x0 accel/gyro, QST QMC630x magnetometer, ams TCS3408 ambient/RGB, ROHM BU52053NVX Hall plus Qualcomm sensor fusion | Read-only live Android sensor service and stock DT | `qcom_q6v5_pas`, IIO, firmware | Exact inventory confirmed; ADSP/CDSP/SLPI firmware packaged; Linux drivers and orientation matrices still need validation |
| Suspend/resume | Platform sleep plus panel power sequencing | 4PDA reports working screen suspend/resume | RPMh, remoteprocs, panel/DRM | Not tested |

## Safety gates

1. Keep the first boot temporary and non-writing.
2. Preserve the stock panel power sequence before enabling native DSI; use simple framebuffer first.
3. Do not enable camera rails or clocks from guessed data.
4. Validate USB device mode first, then host mode/PD, then DP Alt Mode with logs.
5. Do not design dual boot or write partitions until the temporary image boots reliably and recovery paths are verified.

## Primary references

- [4PDA TB371FC topic](https://4pda.to/forum/index.php?showtopic=1086877)
- [Older TB371FC kernel project](https://github.com/tb371fc-desktop/linux-android-msm-lenovo-p12)
- [4PDA post #1751: 6.12 DTS, recovered overlay and GPIO84/PCIe warning](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144438358)
- Exact vendor-derived DTS in `tb371fc-devicetree/qcom/lenovo-tb371fc-overlay.dts`
- Linux 7.1 reference boards `qrb5165-rb5.dts` and `sm8250-xiaomi-elish-common.dtsi`
