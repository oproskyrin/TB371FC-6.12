# Future Windows 11 on ARM port

Windows 11 on ARM is a planned second operating-system target for the Lenovo
TB371FC. It is not part of the current Linux diagnostic image and is not yet
safe to install. The Linux bring-up remains first because it gives us open
drivers, hardware traces and a recoverable way to validate every subsystem.

## Start gate after Linux

Windows adaptation begins only after Linux has all of the following:

- repeatable temporary boots and a tested return to Android;
- native panel operation, including safe mode selection and backlight;
- working touch and AP500U reports;
- stable UFS, battery, charging, thermal control and shutdown;
- validated USB-C host/device, DisplayPort and dock Ethernet/USB;
- working Wi-Fi, Bluetooth and speaker audio;
- saved hardware logs and a versioned, reviewable board description.

Cameras and suspend remain Linux release requirements, but early UEFI/ACPI
work may begin in parallel once the safety and core-hardware gates above are
met. No Windows partitioning starts at that point: the first milestone is an
external, reversible UEFI diagnostic payload.

## Intended architecture

The likely Windows path is:

1. A TB371FC platform port in `edk2-msm` for SM8250/Kona.
2. UEFI GOP for the internal 2944x1840 panel and Block I/O for UFS.
3. Device-specific ACPI tables describing CPUs, memory, interrupts, clocks,
   power domains and peripherals.
4. ARM64 Windows drivers packaged as signed INF/CAT/SYS components.
5. A separate Windows partition set and boot entry, with Android and recovery
   preserved until dual boot is proven.

The Renegade Project already contains an SM8250 platform foundation, while the
WOA Project maintains Snapdragon 865/Kona platform-driver work. These are
references, not a drop-in TB371FC port: the panel, touch, power, USB-C, audio,
cameras and board wiring are device-specific.

## Shared evidence with the Linux port

The following work is reusable across both operating systems:

- exact EDL partition map and verified byte-for-byte rollback images;
- SM8250 memory map and reserved-memory inventory;
- BOE/Tianma NT36532 panel command sequences and 2944x1840 timing;
- Novatek NT36532 touch and AP500U pen report format;
- QCA6390 Wi-Fi/Bluetooth wiring and firmware inventory;
- PM8150B USB-C/PD, QMP PHY, FSA4480 and ONNN redriver topology;
- four TFA9894 addresses, reset GPIOs and YC/QS calibration selection;
- camera sensor and GPIO/clock/rail inventory.

Linux DT cannot simply be converted mechanically into Windows ACPI. It is,
however, the strongest hardware description and runtime validation source for
building those ACPI tables and drivers.

## Linux-to-Windows handoff record

Before Windows work starts, freeze a Linux port milestone containing:

1. the final DTS/DTSI and every TB371FC-specific kernel patch;
2. panel command tables and timings for both BOE and Tianma variants;
3. GPIO, IRQ, I2C/SPI/PCIe addresses, regulators, clocks and power sequences;
4. AP500U HID/report captures and touch-controller firmware selection rules;
5. QCA6390 board-data identifiers and Bluetooth firmware names;
6. USB-C/PD/QMP/DisplayPort traces, including the dock topology;
7. UFS, memory/reserved-memory, SMMU and remote-processor maps;
8. audio calibration-selection rules and camera sensor mode tables;
9. clean boot, suspend, shutdown and thermal logs;
10. hashes of stock boot-chain backups and the proven rollback procedure.

This milestone becomes the evidence source for `edk2-msm`, ACPI and Windows
driver work. Linux firmware blobs, Windows binaries and Microsoft installation
media remain outside Git; only redistributable source, scripts, manifests and
hashes belong in the future Windows project.

## Windows-specific workstreams

| Area | Required result | Current state |
|---|---|---|
| UEFI core | Repeatable recovery test, serial or USB debug, memory map, clocks and PSCI handoff | Not started |
| Display | Native-resolution GOP that remains scanning after `ExitBootServices()` | Linux panel groundwork only |
| Storage | Reliable UFS Block I/O and an isolated ESP/Windows layout | UFS known; no Windows layout approved |
| ACPI | Valid MADT, GTDT, DSDT/SSDT, IORT and power/resource descriptions | Not started |
| GPU | Adreno 650 WDDM-capable ARM64 driver and matching firmware | No TB371FC Windows driver validated |
| Touch/pen | HID touch plus AP500U pressure, hover, tilt and buttons | Linux report format recovered |
| Wi-Fi/BT | QCA6390 ARM64 drivers with correct board data | Linux transport staged |
| USB-C/DP | Device/host, charging, PD and DP Alt Mode drivers | Linux topology staged |
| Audio | Qualcomm audio DSP/machine driver plus four TFA9894 amps | Codec groundwork only |
| Cameras | Sensors, CAMSS/ISP and Windows camera stack | Not implemented |
| Power | Battery, thermal, suspend, charging and safe shutdown | Not validated |

## Boot and recovery policy

- Do not repartition the tablet for Windows during the Linux bring-up phase.
- Do not use slot A: it is already marked unbootable and is not a safe test
  slot.
- First UEFI tests must use the same reversible `recovery_b` method and exact
  EDL backups used by Linux, with a separately reviewed image and rollback.
- A future dual-boot design must preserve stock recovery and provide an
  external EDL restoration path before any GPT or userdata change.
- Windows installation media and proprietary Qualcomm/Microsoft drivers will
  not be committed to this repository. Build scripts and hashes may be tracked.

## Definition of a usable Windows image

The Windows target is not considered usable merely because the desktop boots.
It must have internal display and touch/AP500U, UFS, USB-C data and charging,
Wi-Fi, Bluetooth, speakers, battery reporting, thermal control and reliable
shutdown/reboot. Suspend, external DisplayPort and cameras remain explicit
release requirements, not optional polish.

## References

- [Renegade Project `edk2-msm`](https://github.com/edk2-porting/edk2-msm)
- [WOA Project Snapdragon/Kona work](https://github.com/WOA-Project)
- [Microsoft UEFI requirements for Windows on SoC](https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/uefi-requirements-that-apply-to-all-windows-platforms)
- [Microsoft Windows 11 hardware requirements](https://learn.microsoft.com/en-us/windows/whats-new/windows-11-requirements)
