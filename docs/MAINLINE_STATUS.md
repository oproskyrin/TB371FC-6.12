# TB371FC modern Linux port

Current target: native Arch Linux ARM userspace with stable Linux 7.1.y
(currently 7.1.8).

## Confirmed

- Tablet: Lenovo TB371FC, Qualcomm SM8250 / Snapdragon 870.
- Display: 2944x1840; the Android device currently exposes 30/60/120/144 Hz modes.
- V56.2 on the downstream `4.19.157` kernel is accepted as the working KDE
  hardware-reference baseline and is the primary Linux rollback target for a
  failed mainline test. V55 remains unchanged as the secondary immutable
  rescue fallback.
- Adreno 650 KGSL plus a KGSL-aware Mesa/Turnip build successfully completed
  Vulkan enumeration, Wayland `vkcube` and a Qt Quick Vulkan smoke test.
  Full Plasma acceleration was unstable on the split KGSL/downstream-SDE
  stack and is now a DRM_MSM/mainline acceptance requirement.
- The V56.2 Lenovo keyboard/touchpad result has been migrated into the 7.1.8
  source: I2C13 address `0x60`, IRQ GPIO110 and sequenced reset/wake GPIOs
  114/108 compile successfully with built-in I2C-HID support.  See
  [MAINLINE_V56_MIGRATION.md](MAINLINE_V56_MIGRATION.md).
- Bootloader: unlocked. A non-writing `fastboot boot` probe was attempted;
  ABL rejected the boot command, no partition was written, and Android
  recovered on slot B.
- The old 4.19 vendor kernel is retained as the known-good hardware reference,
  not as the final distribution kernel.

## Mainline work completed

- Current Linux mainline source was prepared in WSL2 Ubuntu 24.04.
- An initial `sm8250-lenovo-tb371fc.dts` was derived from the upstream-style Lenovo J716F SM8250 DTS.
- The framebuffer dimensions were adapted to TB371FC (2944x1840).
- The DTS compiles successfully with the current DTC.
- The arm64 kernel `Image` compiles successfully.

The first successful build was made from a 7.2-rc snapshot. The release target has since moved to stable 7.1.y, matching the kernel generation used by the current independent 4PDA port.

The stable 7.1.8 rebuild is now complete:

- `Image`, TB371FC DTB and the complete module set compile successfully;
- targeted `CHECK_DTBS=y` validation passes for the new hardware nodes;
- the only remaining schema warning is the expected missing `lenovo,tb371fc` entry in the upstream Qualcomm board-compatible list;
- 1,565 modules were installed under
  `usr/lib/modules/7.1.8-tb371fc-dirty` in the generated Arch rootfs;
- ath11k PCI, Bluetooth HCI UART, MSM DRM, QMP combo PHY and SM8250 ASoC modules are present;
- MM8013, FSA4480 and NB7VPQ904M support is built directly into the kernel.

The 7.1.8 `Image` SHA-256 is
`73b7d1ba910370faed78e44a5c5969ed3007f2cb0a171ada8d84a3715e3c75e5`.
The safe and touch-test DTB hashes are respectively
`2d09f3618854a668957c667a7fb23c576aa8664d548a7fdef31e415a762a4853`
and `771052e80ca598c8a30bc2a5a3a89110f69bd31dfc3e7b37b90b7e0029061704`.

Confirmed TB371FC corrections now staged in the DTS:

- Mitsumi MM8013 fuel gauge instead of the J716F BQ27541 assumption;
- QCA6390 PMU/power sequencing, PCIe wake on GPIO 81 and Bluetooth on UART6;
- Adreno 650 GMU/GPU and the TB371FC-specific zap firmware path;
- DPU core clock target of 460 MHz;
- dual-role PM8150B USB-C/PD graph;
- MSM DisplayPort/QMP combo-PHY graph;
- ONNN 0x1c Type-C redriver and FSA4480 at 0x42.
- Lenovo keyboard cover at I2C13 address `0x60`, including its proven
  GPIO114 reset, GPIO108 wake and GPIO110 level interrupt sequence.

Native display development has also started:

- the exact dual-DSI NT36532 geometry, DSC configuration, reset/TE GPIOs and
  BOE/Tianma command tables were recovered from the stock DT;
- a kernel patch extends the upstream NT36523 panel driver with TB371FC BOE
  and Tianma variants plus 30/60/120/144 Hz modes;
- the patched panel and KTZ8866 modules compile against Linux 7.1.8;
- a schema-valid dual-DSI graph is staged but deliberately disabled until the
  fitted panel vendor and dual-backlight power sequence are verified.

See [PANEL_PORT.md](PANEL_PORT.md) for the electrical and safety details.

Touch and AP500U groundwork is also staged:

- live Android confirms 18400x29440 touch and pen ranges, 4095 pressure
  levels, hover, +/-60 degree tilt and two barrel buttons;
- Lenovo's 108-byte, 10x NT36532 report format and single/cascade maps were
  added to a cleaned Novatek SPI driver;
- the driver module compiles against Linux 7.1.8;
- GPIO82 now safely selects the BOE/Tianma `_6` firmware filename;
- the NT36532-specific firmware end-marker, three-byte CRC length and `0x56`
  auto-copy completion path are ported from Lenovo's source;
- SPI14 and the touch child remain disabled until the loader and electrical
  assumptions are verified during a temporary boot.

See [TOUCH_PORT.md](TOUCH_PORT.md) for the AP500U test contract and firmware
safety gate.

TFA9894 audio transport groundwork is now staged:

- four exact N1A1 amplifier nodes at I2C addresses `0x34`-`0x37` use the stock
  reset GPIOs 115/117/118/116;
- the current sdm845-mainline downstream-derived TFA98xx patch applies and
  builds `snd-soc-tfa98xx.ko` against Linux 7.1.8 with a `nxp,tfa9894` alias;
- static analysis of the stock module proves that legacy GPIO 1171 selects YC
  when low and QS when high;
- every amplifier node remains disabled until that legacy GPIO is mapped and
  the stock TDM slot configuration is captured.

See [AUDIO_PORT.md](AUDIO_PORT.md) for hashes and the no-MTP activation gate.
The future, separate Windows 11 on ARM direction is scoped in
[WINDOWS_PORT.md](WINDOWS_PORT.md).

Camera electrical topology is now recovered without enabling it. The rear
pipeline is CCI0/CSIPHY0 with 24 MHz MCLK on GPIO94 and reset GPIO93; the front
pipeline is CCI1/CSIPHY1 with MCLK on GPIO95 and reset GPIO92. Their exact
1.8/2.8/1.2 V and 1.8/2.8/1.1 V rail sets are documented in
[CAMERA_PORT.md](CAMERA_PORT.md). Available vendor source contains several
possible module IDs and conflicts with earlier property notes, so no guessed
sensor node has been added. A read-only Android capture script now closes that
identity gap when ADB is authorized.

The planned userspace is full Plasma 6 on Wayland, introduced only after the
minimal console image and manual KWin test pass. Package manifests and the
three-level rollback design are in [ARCH_PROFILE.md](ARCH_PROFILE.md).

A console-first Arch rootfs was reproducibly generated from the official
aarch64 archive and 47 requested packages. It contains 336 installed packages,
the complete 7.1.8 module tree and the locally packaged firmware. Package,
module and firmware manifests verify, and a generic AArch64 QEMU boot reached
the multi-user login target. This proves the userspace image, not TB371FC
hardware support; see [ROOTFS.md](ROOTFS.md).

Artifacts:

- `artifacts/Image-7.1.7-tb371fc-touch-test` — SHA-256 `bf455a78230ce1932820e64c4eb6e2186fc17a98e3917a8c957064fd8167aa5a`
- `artifacts/sm8250-lenovo-tb371fc-safe.dtb` — SHA-256 `eb07f868907e01a7618d27ce2619c7ef1c3f2c6e2da8d6203c19f2d5bd926824`
- `artifacts/sm8250-lenovo-tb371fc-touch-test.dtb` — SHA-256 `dcf09db2f83d8aac0034d4e6c5538db118cc7ffafa115972a0a9434c820ad329`
- `artifacts/nt36523_ts.ko` — SHA-256 `08d4f1bde80f477f7862651ff207dad9347150956e8e780df84a0a6dc0001002`
- `artifacts/tb371fc-touch-test-initramfs.cpio.gz` — SHA-256
  `505da709203ee320d061e667a88ccb506639fc64881b87642b1b337ea18a7502`;
- `artifacts/tb371fc-touch-test-boot.img` — 77,361,152 bytes, SHA-256
  `e31ffbe084e0610e3467a98bf5708ee5ef1f665779aa7d0de5864a2739e80e79`.
- `artifacts/tb371fc-touch-test-recovery.img` — 104,857,600 bytes,
  SHA-256 `7b0b9d3fcceae0a0acc5b2a71b17622c23c925c3443cec9ec0a1aebf2c26cd66`;
  its AVB hash-footer follows the stock recovery layout and verifies locally.
- `artifacts/tb371fc-vbmeta_b-verification-disabled.img` — 65,536 bytes,
  SHA-256 `5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169`;
  compared with the exact backup, only AVB flags byte 123 changes from 0 to 3.

Generated binaries are deliberately excluded from Git; the tracked build script recreates them.

The original 7.1.8 dock-and-touch diagnostic set was generated outside Git at
`D:\TB371FC-builds\diagnostic-7.1.8`:

- initramfs: 23 MiB, SHA-256
  `9f3938b36655e621cb61b174e6f7d18d366dd389909bff0bf686447e50966207`;
- Android boot v2 image: 77,713,408 bytes, SHA-256
  `b8443567ea33e5d9df91fbb205ac642637f4b9b8172d454f07ecff66a7e78ad4`;
- AVB recovery image: 104,857,600 bytes, SHA-256
  `7f5d22a3300a585b4f3f4fccff41615f158879f5fec7ed173b704cd8fa529825`.

The boot-image verifier confirms the kernel, initramfs and touch-test DTB
byte-for-byte and requires the four USB-Ethernet modules. That recovery reused
the stock recovery DTBO and was rejected before Linux USB enumeration.

A corrected recovery was subsequently built at
`D:\TB371FC-builds\diagnostic-7.1.8-v2\tb371fc-mainline-dtbo-test-recovery-7.1.8.img`:

- size: 104,857,600 bytes;
- SHA-256: `625e5d115e5e002668858adfc6f45a8bf93d58b115eb192f7310d213f772d099`;
- recovery DTBO: one matching empty board-`0xb` overlay, verified to leave the
  complete mainline DTB byte-identical.

The corrected image passed offline component and AVB checks. Its separately
approved hardware launch nevertheless returned to fastboot before Linux USB
enumeration. Automatic rollback restored exact stock recovery and signed
vbmeta backups with successful fastboot writes. The image was then removed
from the launch allowlist.

Post-test comparison found that the rejected kernel had an EFI-stub `MZ/PE`
entry while Lenovo's stock kernel starts with a normal ARM64 branch. The port
configuration now disables EFI for Android-boot compatibility. A separate
Linux 7.1.7 proof build produced a 52,099,080-byte direct-entry `Image`,
SHA-256 `d68cfffde43c58d18ae1ab03feb0df58677c3a4977c4da5e77c0d9543b0a060c`.

A clean 7.1.8 rebuild subsequently produced the same direct-entry size, 1,556
stripped modules and a new verified diagnostic recovery at
`D:\TB371FC-builds\diagnostic-7.1.8-noefi\tb371fc-noefi-dtbo-test-recovery-7.1.8.img`,
SHA-256 `d30579790cf8aaaf34bc1b44cfc62855ff1d4198c18aca7b865561e54b406512`.
Its four unpacked components and complete AVB hash descriptor verify. The user
authorized a reversible hardware test after those checks. The test again
returned to fastboot before Linux USB enumeration, and automatic rollback
restored both exact stock backups with successful writes. The image was removed
from the allowlist. No permanent Linux installation is authorized.

A control image was then built with the exact Lenovo 4.19 recovery kernel,
stock concatenated DTBs and stock recovery DTBO while retaining our Linux NCM
diagnostic initramfs. It booted Linux and enumerated `UsbNcm Host Device` on
the Windows host. Its recovery image SHA-256 is
`9106312de095b6029b7b9efc1345cb9736649406ae4ad2c52b98af5ae9155d56`.
This proves the rebuilt recovery container and initramfs path; it does not
prove mainline hardware support. Exact stock recovery/vbmeta rollback and the
subsequent Android boot were successful.

The next stage now has an independently verified minimal mainline image. It
corrects the early console from the downstream-only
`msm_geni_serial,0xa90000` form to upstream `qcom_geni,0x988000`, matching the
stock `serial0` hardware, and uses a separate stage-0 DTB with only UART and
primary peripheral-mode USB enabled. EFI and KASLR are disabled for a
deterministic entry path. The complete recovery SHA-256 is
`340ba80c245dbe3f1c7cfe12ba2ed7f481dc69a1a0b805a856589fceb1ed4e0a`.
All components, empty overlay application and AVB verify offline. A read-only
live preflight also passed on slot B with the exact rollback artifacts. The
separately authorized launch returned to fastboot before Linux USB, just like
the full DTS images. Automatic rollback restored exact stock recovery and
signed vbmeta with all writes reported `OKAY`. The stage-0 image was removed
from the launch allowlist.

This rules out the enabled GPU, UFS, display, secondary USB and Type-C policy
nodes as the sole cause. The remaining boundary is earlier: mainline ARM64
entry/relocation, firmware-to-kernel register state, or an ABL-visible kernel
property not reproduced by the current Image.

An exact 64-byte ARM64 header comparison exposed one concrete ABL-facing
difference: Lenovo's working 4.19 Image advertises `text_offset=0x80000`, while
the rejected mainline 7.1.8 Image advertises `0x0`. The isolated helper
`scripts/make-arm64-text-offset-image.py` produced a copy in which only byte
`0x0a` changes, setting the 64-bit field to `0x80000`. The resulting stage-0
recovery is 104,857,600 bytes with SHA-256
`95bfe39f9ee6c37e9c6c09ed19ea8d25947d6081e796f8032128f344458d1db7`.
Independent unpacking matched all four inputs byte-for-byte and AVB verification
passed. Its separately authorized launch returned to fastboot before Linux USB
enumeration, disproving `text_offset` as the sole blocker. Automatic rollback
restored the exact stock recovery and signed vbmeta with every fastboot write
reported `OKAY`; Android then completed boot on slot `_b`. The failed image was
removed from the launch allowlist and must not be repeated.

The return interval was consistently about 15 seconds, while the stage-0 config
had `CONFIG_QCOM_WDT=m`. A clean build changed it to `CONFIG_QCOM_WDT=y`;
`qcom_wdt_probe` and `qcom_wdt_start` are present in `System.map`. Its Image
SHA-256 is
`c668995b81cbb63eaa29d9ba127b66fc233b38443ce2e0f5e8a5052f388385a6`,
and its verified 100 MiB recovery SHA-256 is
`6a86facc8f1447e22e6a0f2e0c5c9aa5e8d8141c816a671c75583afa6764110c`.
The authorized test nevertheless returned to fastboot after roughly the same
15 seconds and before Linux USB. Exact stock rollback and subsequent Android
boot on slot `_b` succeeded. This excludes a modular Qualcomm watchdog driver
as the sole cause. The image was removed from the allowlist.

Patch `0005-arm64-add-tb371fc-early-framebuffer-marker.patch` adds an opt-in
pre-MMU marker at `primary_entry`. With the diagnostic option enabled, the
disassembly shows stores of `0xffff00ff` to physical `0x9c000000` for exactly
8 MiB, a `dsb sy`, and then the unchanged calls to `record_mmu_state` and
`preserve_boot_args`. The Image SHA-256 is
`ce896b90a363ce9d34d6224bdd1548c8f2a56948148f81f004c167f6a9f74ca9`;
the independently verified recovery SHA-256 is
`abdbfe804ee991ff58f47a3842a025907614309310c67f28a2315856c79a8a2e`.
Its authorized launch again returned to fastboot after about 15 seconds and
automatic rollback restored Android on slot `_b`. The image was removed from
the allowlist. Host USB cannot determine whether the marker executed; the
screen-color observation remains pending.

The following build isolated kernel size and entry position. The minimal
stage-0 config retains the early framebuffer marker, built-in Qualcomm WDT,
debug UART and DWC3 gadget path while removing unrelated platform families and
subsystems. It produced a 24,422,408-byte `Image` with SHA-256
`737ad7ed1d5466f983cc9977caff6a555260a721d05660af46737263a118a83f`;
`primary_entry` is at file offset `0x00f0e0f0`, well below 32 MiB and below the
working Lenovo kernel's approximately 29.5 MiB entry. The minimal initramfs
SHA-256 is
`82df9a4b4610498668afa9790884dda31f11c6ac4abd7bb3a6e079dda72cf558`.
Its recovery SHA-256
`2c18b21de60dfe7363ca961976fc71ce3b0c3b6ef35775c56f7c2e7804f653bf`
passed independent component and AVB verification, but returned to fastboot
before Linux USB. Automatic rollback succeeded. Kernel size and a 32 MiB
entry boundary are not sufficient explanations.

`scripts/make-arm64-direct-entry-image.py` then changed only the first two
ARM64 instructions: the branch was moved from `code1` to `code0`, `code1` was
zeroed, and the target remained `0x00f0e0f0`, matching Lenovo's header layout.
The modified Image SHA-256 is
`ea431c1a6f13b0774f75db144a5487b9b1c32d2669777fb2fef9f786413bffd5`;
the verified recovery SHA-256 is
`27feff143b528ddf00f87d9bdf7296958f37cb85062771c5ab463e0a6b4e5041`.
Its authorized launch returned to fastboot after about 16 seconds. The monitor
restored exact stock recovery and signed vbmeta with all writes `OKAY`, and
ADB confirmed Android boot completion, slot `_b`, ZUI 16.0.474, AVB `orange`
and unlocked state. The recovery hash was removed from the allowlist. Lenovo's
`code0`/`code1` branch placement is not the sole blocker.

A final combined header test started from that minimal direct-entry Image and
changed only byte `0x0a`, setting `text_offset=0x80000`. The resulting Image
SHA-256 is
`e8247fc08547cc29098f58c3058b6f3757aa97ed0575e5c2f0ae9e685c7b33aa`;
the recovery with the verified empty DTBO has SHA-256
`8dbb06d28dc97d736510393782511fd914212044e9044e5e23451d212a044d47`.
It returned to fastboot before Linux USB after about 8.6 seconds of host
observation. Exact automatic rollback succeeded and ADB again confirmed the
expected Android state. The hash was removed from the allowlist. Thus neither
the direct branch, `text_offset=0x80000`, nor their combination explains the
mainline failure.

## Rebuilt downstream bridge boot

The public TB371FC source at
`https://github.com/tem423/android_kernel_lenovo_tb371fc` was checked out at
lineage commit `9d8abebf4ac4d45cf4cc11b5b6bc5e4483d10fd1`. Its published workflow was
reproduced with Snapdragon LLVM ARM Compiler 10.0.7 for Android NDK and the
Android 11 AArch64/ARM GCC 4.9 toolchains. `vendor/tb371fc_defconfig` produced
a 48,416,784-byte direct-entry ARM64 `Image` reporting
`4.19.325-cip134-st18-perf+`, SHA-256
`3ab314e2fd99cb68fad5f3d77a8cf18adbed625a463c35295c119034b99cb86e`.
Its header uses `text_offset=0x80000`, image size `0x37de000`, flags `0xa` and
the `ARMd` magic. NCM configfs and function support are built in.

The kernel was combined with the already proven diagnostic initramfs and the
exact stock concatenated DTB/recovery-DTBO inputs. The resulting 100 MiB AVB
recovery is stored outside Git at
`D:\TB371FC-builds\diagnostic-published-vendor-4.19.325\tb371fc-published-4.19.325-ncm-diag-recovery.img`,
SHA-256 `1bd81ac7e53d13c44e64c500fee730a65b8edbd1dbb656b8a858b31430399f33`.
Independent unpacking matched all four payloads byte-for-byte and verified the
AVB footer/hash descriptor before launch.

The first authorized hardware test stayed in Linux and Windows enumerated an
up `UsbNcm Host Device` as `1d6b:0105`. A follow-up initramfs corrected the
link-local address, replaced the one-shot console with a persistent raw shell
and included the exact vendor firmware. This yielded a full dmesg and live
subsystem inspection. The 4.19 bridge confirmed UFS, microSD, DSI/DP DRM
objects, Type-C device/sink, USB NCM, charging and 2944x1840 panel modes at
30/60/120 Hz. It selected the Tianma cascade NT36532 firmware successfully and
registered touch plus AP500U pen input devices.

QCA6390 enumerated as PCI `17cb:1101`, but the exact vendor state-control
write `ON\n` restarted the kernel after approximately 21 seconds. The external
fuel gauge did not bind (`exfg not found`), Bluetooth produced no HCI and ALSA
produced no sound card. These are now concrete bridge-kernel blockers; the
camera, USB host, dock and DP Alt Mode still need dedicated tests. Logs are in
`diagnostics/vendor-4.19.325-*-20260810.txt`.

After the test, an embedded one-shot module requested bootloader restart.
Exact stock `recovery_b` and signed `vbmeta_b` were restored with all writes
`OKAY`; Android completed boot on slot `_b`, ZUI 16.0.474, AVB `orange`. The
firmware-test recovery SHA-256
`12439d92fd29c34a1456df0ba433dddaa411e352eb815f4254ed39c3c32d1660`
was removed from the launch allowlist.

A second downstream diagnostic build included the complete stock QCA6390 BDF
set and a narrowly scoped `CONFIG_CNSS2_DIAGNOSTIC_NO_SSR` failure path. One
WLAN power request reached MHI MISSION_MODE and bound LOOPBACK, DIAG and IPCR,
then timed out waiting for CNSS `FW_READY`. The new failure path worked as
intended: it powered WLAN down and kept the Linux NCM shell alive instead of
restarting the SoC. Because board data is requested after `FW_READY`, BDF is
not the immediate blocker. The minimal initramfs lacked a running QRTR name
service and exposed no QRTR socket/node, making a small static `qrtr-ns` plus
transport verification the next downstream experiment. Logs are in
`diagnostics/vendor-4.19.325-wlan-safe-*-20260811.txt`.

Fastboot accepted restoration of the exact stock `recovery_b` and signed
`vbmeta_b` after this test. After physical `Reboot system now`, authorized ADB
confirmed completed Android boot on slot `_b`, ZUI 16.0.474, AVB `orange`,
unlocked state and 100% battery. The temporary recovery hash was removed from
the launch allowlist.

This downstream build is now the observable working bridge and bisect
reference. The next kernel work is to isolate the WLAN restart and external
fuel-gauge binding, exercise AP500U events interactively, then forward-port
known-good subsystems incrementally toward stable 7.1. It is not the final Arch
kernel and does not authorize installation or dual boot.

## Arch userspace

- Official Arch Linux ARM aarch64 rootfs downloaded and verified with MD5.
- Rootfs extracted in WSL2 at `/root/arch-tb371fc/rootfs`.
- A non-writing diagnostic initramfs was built with static AArch64 BusyBox,
  `input-monitor`, selected module dependencies and locally packaged stock
  firmware.
- An Android boot header v2 image was generated and independently unpacked to
  verify its parameters. It is 77,361,152 bytes, below the stock 96 MiB limit.

## Important limitation

The DTS is an initial bring-up base, not yet a complete hardware port. The
firmware tree, diagnostic initramfs and boot image are now reproducible. The
intended non-flashing hardware boot was approved and attempted, but this ABL
reports `fastboot boot` as an unknown command. Slot A is marked unbootable, so
it cannot serve as a safe inactive test slot. The exact recovery and signed
vbmeta backups and rollback path are now tested. Mainline recovery probes
returned to fastboot before Linux USB enumeration, but the stock-kernel
control booted the same diagnostic Linux userspace and enumerated USB NCM.
Consequently ABL recovery-image acceptance and initramfs execution are no
longer the leading blocker. Investigation is now focused on the mainline
kernel's earliest execution and the TB371FC DT/DTBO handoff.
Native panel, touch and audio have compile-tested driver groundwork;
audio hardware validation and camera support remain later bring-up work. Dual boot or installation
will not be considered before repeatable test boots and recovery validation.

## Final QRTR bridge result

The final unattended bridge test added upstream QRTR v1.1 userspace. It
advanced WLAN beyond the previous barrier: remote QRTR node 7 announced WLFW,
CNSS connected to QMI at port 1, registered indications and sent host
capabilities. `FW_READY` still timed out after 20 seconds, so the remaining
blocker is after QMI service discovery but before firmware-ready completion.
The no-SSR worker safely powered WLAN down and Linux remained reachable for
the rest of the 285+ second session. No `wlan0` appeared. Exact logs and a
SHA-256 report are under
`D:\TB371FC-diagnostics\remote-final-20260811`.

The remaining downstream WLAN blocker is now attributed to the Android
two-client WLFW protocol, not missing QRTR discovery or board data. Stock DT
sets `cnss-daemon-support`, the tested Linux kernel advertised two clients,
and stock Android runs a second proprietary `cnss-daemon`; the minimal Linux
image does not. Firmware therefore stopped before REQUEST_MEM. A new
bring-up-only downstream option suppresses that quirk so the already-present
kernel QMI client can perform the memory/BDF/M3 handshake alone. The compiled
but untested Image SHA-256 is
`d7919c2f5a3706f220dea926eaf7c1d3d41c9f774cb4c2bef9523fb6571a5a77`.
The same diagnostic build adds MSM DRM fbdev/fbcon for visible `tty0` output
instead of the retained Lenovo splash. This work improves the observable
4.19 bridge only; it does not change the stable-7.1 target or constitute a
production driver result.

## Single-client WLFW result

Hardware testing confirmed the two-client diagnosis. With the diagnostic
single-client override, CNSS2 received REQUEST_MEM and FW_MEM_READY, queried
target capability, transferred the exact stock regulatory/BDF and M3 files,
and received FW_INIT_DONE/FW_READY. This closes QRTR discovery, client-count,
firmware-memory and board-file transfer as immediate bridge blockers.

The next failure was later and narrower: built-in QCACLD requested
`wlan/qca_cld/WCNSS_qcom_cfg.ini` through the firmware loader. The file was
absent, its fallback timed out, and CNSS powered WLAN down without SSR. The
next one-shot recovery therefore changes only the initramfs by adding the
exact stock INI; the tested kernel remains unchanged. Success is defined as
QCACLD registration and creation of `wlan0`, not Wi-Fi association. This is
still diagnostic downstream evidence to guide the stable-7.1 port.

The stock-INI follow-up succeeded on hardware. QCACLD completed its WMI/data
path initialization and created `wlan0`, `p2p0` and `wifi-aware0`, with an
unblocked WLAN rfkill and advertised 802.11ax capability. The remaining
firmware request was optional `wlan_mac.bin`; after its fallback timeout the
driver used a default MAC. Because no userspace client opened an interface,
the normal idle timer subsequently powered WLAN down cleanly. This proves the
downstream radio host stack can register, but not yet that scanning,
association, traffic or suspend/resume works. The next bridge test needs
standard wireless userspace and an administratively active interface; stable
7.1 still requires the equivalent result with upstream `ath11k`.

## Linux 7.1.8 clean release baseline (2026-08-14)

A fresh worktree at stable commit
`25c76bea853d0db65b51fb4697a47cbfd9e35e76` was patched and rebuilt from a
clean object directory. This avoids the corrupted `drivers/media/i2c/Kconfig`
left in an older disk-full worktree. The complete `Image`, all board/test DTBs
and 1,510 loadable modules built successfully as `7.1.8-tb371fc`.

The immutable offline release set is stored at:

```text
D:\TB371FC-builds\linux-7.1.8-tb371fc-offline
Image SHA-256 808faa9ff2829a44a523d5aa496644e641d417b309bcce5507e26785948634ba
board DTB SHA-256 2d09f3618854a668957c667a7fb23c576aa8664d548a7fdef31e415a762a4853
stage0 DTB SHA-256 56a1af1b5466b380d2382cac947171bca5f90629f16151d18040fee6c1184d1d
hardware status: OFFLINE VERIFIED; NOT BOOTED
```

The release verifier checks every file hash and the required DRM/MSM,
NT36523 SPI touch, ath11k PCI, Type-C DP Alt Mode and camera configuration.
Independent panel checks also pass:

- all 88 Tianma init commands match the active stock table;
- the 128-byte Linux DSC PPS exactly matches Lenovo's captured PPS;
- the dual-DSI 2944x1840@120 derived link clock is within 2,067 ppm of stock;
- host timing/DSC population precedes panel prepare, followed by vendor LP
  long writes, dual PPS, sleep-out and display-on in the required order.

These are compile/static results, not a claim that native DRM is working on
hardware. `scripts/package-mainline-7.1.8-release.sh` and
`scripts/verify-mainline-7.1.8-release.sh` reproduce and audit the set.

Two U-Boot RAM-boot payloads are separately stored under
`D:\TB371FC-builds\u-boot-linux-7.1.8-payloads`: a conservative stage0 DTB
and an attended native-display DTB. They are 33,775,616 and 33,783,808 bytes,
respectively, below U-Boot's 112 MiB download buffer. Both use a deterministic
gzip kernel so U-Boot decompresses the Image to its LMB-allocated,
2-MiB-aligned kernel address. Neither has been sent to the tablet.

## Linux 7.1.8 r4 Arch/microSD gate (2026-08-14)

The persistent-root payload now has a dedicated DTB instead of reusing a
stage-0/display DTB with SDHCI2 disabled. Stock DT and vendor-driver evidence
identified GPIO 14 card detect, GPIO 75 BayHub BH201 redriver power, PM8150L
L9 card power and PM8150L L6 I/O power. The new DTB enables SDHCI2 at only
25 MHz with 1.8-V switching and UHS disabled; UFS, GPU and display remain off.
GPIO 75 is now an optional SDHCI-managed output following BUS_ON/BUS_OFF,
instead of the schema-invalid r3 GPIO hog.

The compiled DTB passed the upstream SDHCI, SM8250 pinctrl and RPMh regulator
schemas plus explicit decoded-property checks. Release r4 contains the clean
rebuilt 7.1.8 Image and all 1,510 modules:

```text
D:\TB371FC-builds\linux-7.1.8-tb371fc-r4-arch-microsd-offline
Image SHA-256 60e1575202911074c03c4381aa764d96588db2b8dac1da04aeea4ff18307a31b
arch-test DTB SHA-256 5e7785ebbb7de0f79f7ce4f625da98aa63a8a6cb77451972497adc8dee67ce03
hardware status: OFFLINE VERIFIED; NOT BOOTED
```

The sole replacement Arch RAM payload is 34,086,912 bytes with SHA-256
`6dd8f7542564ecdd60b4c28d912c2a097d38ea0a3121feb813bc86ba81d76d5c`.
The old r2/r3 Arch payloads are blocked. The r4 first run remains an attended U-Boot RAM test; it must prove
microSD, loop-root, rescue USB and SSH before native DRM or KDE is attempted.
Full evidence is recorded in
`diagnostics/mainline-7.1.8-r4-arch-microsd-build-20260814.md`.

## Linux 7.1.8 r6 native-display wide-plane candidate (2026-08-14)

The modern MSM DPU path now has the missing TB371FC parallel-pipe trigger.
Generic SM8250 advertised a 4096-pixel SSPP linewidth, so a 2944-wide primary
plane never entered Linux 7.1's existing `dpu_plane_split()` path. Stock and
the physically useful community port both use `0x758` (1880). Patch 0016 adds
`lenovo,tb371fc-dpu`, reuses the complete SM8250 catalog and changes only this
limit; only the attended display-test DTB selects it.

The full Image, all DTBs and 1,510 modules rebuilt successfully:

```text
D:\TB371FC-builds\linux-7.1.8-tb371fc-r6-display-wideplane-offline
Image SHA-256 09245e6aafad68a77789388462e16b79813146aafb996e60b60d95281ba25a74
display-test DTB SHA-256 fe6b51f191faa2421699d28ba4fd5abfc9ebb6e4bc2c8bd128102a80e5bb7e05
hardware status: OFFLINE VERIFIED; NOT BOOTED
```

Targeted DPU/MDSS/PHY/panel/backlight bindings pass. The only remaining DTB
warnings are the separately tracked missing schemas for Novatek touch and the
four TFA9894 amplifiers. The linked kernel contains `dpu_tb371fc_cfg`, and the
compiled DTB selects it. This is the current native-display candidate, but it
is not yet a hardware result. Full hashes and verification are in
`diagnostics/mainline-7.1.8-r6-display-wideplane-build-20260814.md`.

The preferred first display execution is now the gated r6 payload, SHA-256
`1bb58f5dbcd393dacfa63ed892f62b40ec9f63a889b497286c4f9cea7cf5aa93`.
It disables automatic fbdev modesetting, establishes USB control first and
requires an explicit `run-mainline-display-test` command. This preserves a
second diagnostic shell and before/after snapshots if the first atomic commit
stalls. It uses the same r6 Image and DTB and is also offline-only.

## Linux 7.1.8 r7 V56.2 migration release (2026-08-14)

The exact V56.2 Lenovo keyboard-cover sequence has now been carried into the
modern source through generic I2C-HID: I2C13 address `0x60`, level-low IRQ
GPIO110, active-low reset GPIO114, active-high wake GPIO108 and a 120 ms
post-reset delay. Generic HID, HID multitouch and I2C-HID OF are built in.

The full clean build and release verifier completed successfully:

```text
D:\TB371FC-builds\linux-7.1.8-tb371fc-r7-v56-migration-offline
Image SHA-256 fbf98ceb6839344be9e601149473ce55178dd0330228b2c176bdba77fabbd483
board DTB SHA-256 a4bee3abd7afd2578dab6091fb370c9d5857c13abe4c56ecfac47e055a6e9caa
module count 1507
hardware status: OFFLINE VERIFIED; NOT BOOTED
```

This proves reproducible integration, not tablet behavior. V56.2 is the
primary Linux rollback target for a later attended test; V55 remains the
secondary immutable rescue baseline. Neither known-good image was modified.

## Linux 7.1.8 r10 earliest-entry localization (2026-08-15)

The kexec transport is now separated from the Linux 7 failure. A standalone
ARM64 landing payload reached its entry point and performed PSCI reset, while
r10 enabled seven staged physical framebuffer markers in `primary_entry`.
The linked r10 Image contains every marker and was executed through V56.5 r2
with a 45-second failsafe. Linux 7 again reset independently and V56.5
reappeared on USB; V56.3 r2 was then restored and verified.

```text
D:\TB371FC-builds\linux-7.1.8-tb371fc-r10-staged-head-markers
Image SHA-256 f09780a2509e00c2c478d0c29ec3e2ecaa66276b9a5ec1aca29ded94b0928824
hardware status: ENTERED VIA KEXEC; ALL SEVEN PRE-MMU STAGES VISIBLE; EARLY RESET
```

The current downstream desktop still uses llvmpipe for KWin. Native Adreno
acceleration remains a Linux 7 DRM_MSM/Freedreno goal, not a completed driver
result. The white stage-7 band proves execution returned from `__cpu_setup`
and reached `__primary_switch`; r11 therefore targets the MMU/virtual-address
transition. Full r10 evidence and the band-to-code map are in
`diagnostics/mainline-7.1.8-r10-staged-head-markers-20260815.md`.
