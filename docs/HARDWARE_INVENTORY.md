# TB371FC live hardware inventory

This is the privacy-filtered result of a read-only ADB capture from the target
tablet in stock ZUI 16.0.474 on 2026-08-10. The full local archive contains
network and device identifiers, remains outside Git on `D:`, and must not be
published. No partition was written and the tablet was not rebooted.

## Confirmed hardware

| Area | Live result | Port consequence |
|---|---|---|
| Boot state | Android boot complete on slot B; bootloader unlocked; verified boot orange | Keep slot A unused and retain the established slot-B recovery path |
| Display | 1840x2944; factory modes 30, 60, 120 and 144 Hz; 120 Hz active during capture; HDR types 1-4 | Preserve all four native modes; validate each independently after basic DRM is stable |
| Touch | Novatek capacitive touchscreen, ten contacts, logical range 18400x29440 | Existing NT36532 test driver has the correct coordinate range |
| AP500U pen | Novatek pen input; pressure 0-4095, tilt +/-60, hover/distance and two side buttons | Driver must expose pressure, tilt, hover and both stylus buttons, not only touch coordinates |
| Rear camera | `ofilm_s5k4h7_rear_i`; CameraService maximum 3264x2448, autofocus and flash | Use the S5K4H7 driver and OFILM companion path; keep actuator and flash disabled for first ID probe |
| Front camera | `txd_hi1339_front_i` | Port the exact TXD HI1339 tables and EEPROM metadata next |
| Wi-Fi | QCA6390 transport active; Wi-Fi 6 at 5 GHz observed | Validate `ath11k_pci`, stock firmware and board data in Linux |
| Bluetooth | QCA6390 Bluetooth active in Android | Validate UART6, enable GPIO and matching firmware in Linux |
| USB-C | Dual-role Type-C reports device/sink and host/source combinations | Test device mode first, then host/PD; dock stays disconnected until Linux boots |
| Ethernet | Android Ethernet service present; no interface without dock | Test the dock's USB Ethernet controller only in Linux |
| Audio | Stock `tfa98xx_dlkm` module loaded | Continue four-amplifier TFA9894 validation before speaker playback |
| Motion/environment | BMI3x0 accel/gyro, QMC630x magnetometer, TCS3408 ambient/RGB, BU52053NVX Hall | Match Linux drivers, interrupt wiring and orientation matrices |

## Deferred dock inventory

The USB/HDMI/Ethernet dock is intentionally not connected during Android
capture. After a non-writing Linux boot reaches a stable console, test in this
order: USB device recovery, Type-C role switching, dock USB enumeration,
Ethernet, USB peripherals, then DisplayPort Alt Mode/HDMI. Record `dmesg`,
`udevadm`, Type-C class state, DRM connectors and network interface IDs before
enabling automatic services.
