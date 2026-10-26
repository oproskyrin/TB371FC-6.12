# Community TB371FC Linux status

This file separates runtime reports on 4PDA from source code that is actually
available for review. Status was last checked on 2026-08-10.

## Reported working port

4PDA user `kletn98` reports the following progression on Linux 7.1.5:

| Post | Reported result |
|---|---|
| [Initial Arch boot](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144414834) | Linux first booted on 6.15, then Arch on 7.1.5 |
| [DRM/Wayland and touch](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144428932) | Freedreno/DRM, Wayland, battery/charging and a reverse-engineered touch driver work |
| [USB/DP/PD](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144434453) | USB, DisplayPort through a hub and approximately 27 W charging work |
| [AP500U inking](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144443531) | Pen pressure, angle and buttons work without Bluetooth pairing |
| [Audio and pen split](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144457366) | USB-C headphones work; pen coordinates come through touch, while Bluetooth carries button/battery functions |
| [Speaker audio](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144471815) | Native speaker audio is reported working |
| [Subsystem summary](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144484541) | CPU/GPU, remote processors, display, touch/pen, audio, sensors, Wi-Fi/BT and USB are reported working; cameras remain in development |
| [Display limitations](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144502888) | Display works, but 10-bit, HDR10 and 144 Hz are not finished |
| [Latest camera status](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144597863) | Closed camera binaries were abandoned; a new interface is reported nearly ready |

These are valuable hardware-validation reports, not local proof for this
project. As of the check date, the author has not linked a public source tree
or release containing the working 7.1.5 DTS and drivers. The last page ends
with a request for details about hardware acceleration and the boot route.

## Published references

The code currently available from the thread is the older research by 4PDA
user `-Ila-`:

- [`tb371fc-desktop-linux-6.12`](https://github.com/tb371fc-desktop/linux-android-msm-lenovo-p12/tree/tb371fc-desktop-linux-6.12), a commented base DTS that was not itself successfully booted;
- [recovered vendor base DTS](https://github.com/tb371fc-desktop/devicetree/blob/tb371fc/qcom/lenovo-tb371fc.dts);
- [recovered vendor overlay](https://github.com/tb371fc-desktop/devicetree/blob/tb371fc/qcom/lenovo-tb371fc-overlay.dts);
- [4PDA post #1751](https://4pda.to/forum/index.php?showtopic=1086877&view=findpost&p=144438358), which explains the provenance and warns about the GPIO84 conflict between PCIe1 and the CTN730 pen charger.

The 6.12 branch was audited at commit
[`780c887`](https://github.com/tb371fc-desktop/linux-android-msm-lenovo-p12/commit/780c887b2204838b013a6966b24ebd1d8ac4ccb3)
on 2026-08-10. It is Android Common Kernel 6.12.30 with only three
TB371FC-specific commits: the DTS/defconfig import, a two-value QMP
DisplayPort PHY adjustment and a grammar-only change. Its display path is a
bootloader-preserved `simple-framebuffer` and explicitly notes that no panel
driver exists. QCA6390, TFA98xx and FSA4480 sections remain commented or TODO;
there are no fitted camera sensor nodes or AP500U device description.

The QMP adjustment is still useful evidence: it ports DisplayPort TX drive
level `0x3f` and post-emphasis `0x37` from Lenovo 4.19. The published patch
changes the shared SM8250 table globally, so our port must validate and scope
those values to TB371FC instead of copying the change blindly.

The 6.12 branch is therefore a hardware map and research source, not a ready
distribution, a solution for the recovery-DTBO handoff or the later working
7.1.5 implementation. Our port keeps its own reviewable 7.1.8 patches and
only adopts facts corroborated by the vendor DT, Linux bindings or local
build/runtime tests.
