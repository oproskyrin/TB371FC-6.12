# TB371FC community-source port map

Date: 2026-08-13

Reference tree:

`D:\TB371FC-builds\community-6.12-tb371fc-files-v3`

This map separates tested implementation from comments and unfinished TODOs in
the `tb371fc-desktop` source.  The complete DTS must not be copied wholesale:
it mixes working downstream 4.19 properties, compatibility notes for newer
trees and intentionally disabled experiments.

| Area | Useful community evidence | Port status / next use |
| --- | --- | --- |
| Internal display | simplefb at `0x9c000000`, 2944x1840, stride 11776, nine clocks; MDP 460 MHz; parallel SSPP `0x758` implementation | Adopted. V50 physically produced a stable full-panel fbcon. Linux 7.1.8 r6 now maps `0x758` to a board-specific DPU catalog so upstream `dpu_plane_split()` requests two SSPPs; hardware validation remains pending. |
| Display power | PMIC regulator corrections, always-on L1/L8 clues, display GDSC and clock retention | Compare live regulator consumers before adopting additional always-on properties. AVDD retention is already proven. |
| DSI PHY | Both PHY nodes and vendor lane-config delta are documented | The lane data is commented because its newer-kernel equivalent was unresolved. Use as a register-level comparison, not a ready patch. |
| Wi-Fi / Bluetooth | QCA6390 identity, PCIe1 wake GPIO 81, PM8150 S6 rail clue; CNSS2 and QCA6390 BT options enabled | WLAN node itself is commented out. Combine these clues with the stock DT, firmware/BDF dump and live PCIe/QMI logs. |
| Touch | `CONFIG_TOUCHSCREEN_NT36XXX`, evdev and I2C input support | Useful driver/config baseline. No complete new touchscreen DTS is supplied; retain the stock TB371FC node and firmware. |
| AP500U stylus | No AP500U-specific node or driver found | Community tree does not solve the pen. Identify its Android input/HID transport and firmware separately. |
| Remote control | Community commit `c2adf4b` enables configfs ACM PID 0104 and runs `serial-getty@ttyGS0`; its defconfig also enables NCM | ACM enumeration was confirmed in V51. The normal user/developer channel is V52 NCM-only plus key-only OpenSSH; serial remains optional rescue work. |
| USB-C / dock | DWC3 host/gadget, Type-C/PD, RTL8152 and USB networking options; extensive USB3/DP PHY tuning notes | Good basis for USB hub and Ethernet. FSA4480 connector graph and PHY tuning are commented TODOs; HDMI/DP output is not yet a working implementation. |
| Cameras | CCI0 GPIO 101/102 and CCI1 GPIO 105/106 topology, removal of unused second I2C buses | Bus topology is useful, but sensor nodes, clocks, regulators and calibration are not provided. Port cameras sensor-by-sensor from stock DT/dumps. |
| Audio | Four TFA98xx address/reset clues, FSA4480 address 0x42, short-sync TDM setting | Amplifier and Type-C analog-audio nodes are commented. Treat as hardware map, then validate codecs and DSP routing live. |
| GPU / media | KGSL, Kona GPU/video/camera clock controllers, media and NPU configuration | Reuse as configuration inventory. Firmware and remoteproc/QMI bring-up must be validated from Arch. |
| Sensors / NFC | Hall sensor, SSC and NQ NFC options plus pinctrl notes | Inventory only until live buses and firmware services are available. |

## Integration order after V51 remote access

1. capture a stable live inventory from Arch without touching DRM;
2. validate USB host, dock hub and RTL8152 Ethernet;
3. bring up QCA6390 PCIe/firmware and Bluetooth transport;
4. validate Novatek touch and identify AP500U events;
5. test GPU and then native DRM using a reversible helper;
6. add audio, sensors and cameras after their power/I2C dependencies are known.
