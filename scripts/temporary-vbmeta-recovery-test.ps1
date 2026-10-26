#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('ValidateOnly', 'Preflight', 'Launch', 'LaunchFastboot', 'Restore')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$PlatformToolsDir,

    [string]$Serial = $env:TB371FC_SERIAL,

    [string]$RecoveryImage,

    [string]$RollbackRecoveryImage,

    [switch]$TwoPartitionWriteApproved,

    [ValidateRange(30, 300)]
    [int]$BootObserveSeconds = 120
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ArtifactDir = Join-Path $ScriptDir '..\artifacts'
$BackupDir = Join-Path $ArtifactDir 'device-backup'
$Paths = @{
    RecoveryTest   = if ($RecoveryImage) { $RecoveryImage } else { Join-Path $ArtifactDir 'tb371fc-touch-test-recovery.img' }
    RecoveryBackup = Join-Path $BackupDir 'lun0-recovery_b.bin'
    VbmetaTest     = Join-Path $ArtifactDir 'tb371fc-vbmeta_b-verification-disabled.img'
    VbmetaBackup   = Join-Path $BackupDir 'lun4-vbmeta_b.bin'
}
if ($RollbackRecoveryImage) {
    $Paths.RecoveryRollback = $RollbackRecoveryImage
}
$Hashes = @{
    RecoveryBackup = '94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668'
    VbmetaTest     = '5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169'
    VbmetaBackup   = '58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05'
}
$AllowedRecoveryHashes = @{
    'c1fdcdf3c438664ceb540f4a6d4c506e879c7e141ad3107dc54e4937b3a70223' = 'R171 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r171: Image 62763187, DTB d341922a (R170 + UART6 Bluetooth, serial aliases), initramfs bb9753ee (R170 + r171-bt service, multi-layer loader r163-apps + r171-apps/bluedevil). Helper as R169. AUDIT_RESULT=PASS. Rollback: R170 14326137.'
    'f1b15988d421bd8688134d79da3ea3900a77867f59263b472ab14ec52c067939' = 'R172 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r172 with cmdline + pci=realloc: Image 62763187, DTB d341922a, initramfs 197e6687 (R171 without the PCIe endpoint-remove fallback; Bluetooth after Wi-Fi with firmware retries). AUDIT_RESULT=PASS. Rollback: R171 c1fdcdf3.'
    'c1be967171fbbfa2d7a9d120663a3950847e01435297ca2a033c34a6edc098b3' = 'R173 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r173 with pci=realloc: Image 62763187, DTB d341922a, initramfs 7051537e (R172 + Russian desktop/us-ru keyboard/125 % scale before KDE, Bluetooth retried as a unit with an SD-serial BD address). AUDIT_RESULT=PASS. Rollback: R172 f1b15988.'
    '8defe90bf4f583452a3ec13d8df70e247364942e46a7cdb41e57464789e2234d' = 'R175 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r175 with pci=realloc: Image 62763187, DTB d341922a, initramfs 841ebcb0 (persistent root on microSD partition 2 ext4 tb371fc-root with the SDHC2 1.8 V pad fix; RAM-only maintenance mode; old image path as fallback). AUDIT_RESULT=PASS. Rollback: R173 c1be9671.'
    '1f3fded29b47922dfbe9c0a852df0b66f5a172a359b293b9bd0232d1f47e3a46' = 'R176 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r176 with pci=realloc: Image 62763187, DTB dbb4494f (R171 DT + microSD ADMA via apps_smmu 0x4a0, no sdhci-caps-mask, 25 MHz), initramfs 841ebcb0 (R175, persistent root on partition 2). AUDIT_RESULT=PASS. Rollback: R175 8defe90b.'
    'de29adf96e22d43574e741c96558c5dc1e024bac6381707924e16abcad276c43' = 'R177 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r177 with pci=realloc: Image 55fcf49e (R159 + sdhci-msm tb371fc,io-pads-1v8), DTB 635df17d (microSD ADMA, 50 MHz, io-pads-1v8), initramfs 841ebcb0 (R175). AUDIT_RESULT=PASS. Rollback: R176 1f3fded2.'
    'e3d34d1d7daf4ab93e22f1fa63ac12406df3b495992b8f89bd2ac83316e97c34' = 'R178 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r178 with pci=realloc: Image 55fcf49e, DTB 635df17d (R177), initramfs 291258e8 (R175 + microSD UHS SDR50 switch before the root mount, loader rescue USB shell). AUDIT_RESULT=PASS. Rollback: R177 de29adf9.'
    '7947f7f8d3ab09851da42f3176e4fa219ca0bdb73f2b30901b0fb9c10e383dfc' = 'R184 2026-10-26: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r184: R178 Image + initramfs, DTB with the MM8013 battery fuel gauge on i2c3 (GPIO 119/120 freed).'
    'be8d3744edc1b9c6ebe862a5d8fa9dd13e32e6f7b9c58a67e8d49312286a5379' = 'R185 2026-10-26: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r185: R179 headless Adreno 650 Image + initramfs, DTB with the MM8013 battery gauge and a global GPU page table (KWin GPU compositing).'
    'c09732a013d1ef680e842f8d1fb4491d8acf3dbefa9a89e56eb1a76a4a1b231b' = 'R187 2026-10-26: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r187: R187 Image (R179 + CONFIG_USER_NS + built-in MM8013), R185 DTB and initramfs.'
    'bc6208e582001862d8c2fa1defb8c0b76475a9c025442d76d899b21bdedfbf64' = 'R188 2026-10-26: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r188: R188 Image (R179 + CONFIG_USER_NS + PID_NS + built-in MM8013), R185 DTB and initramfs.'
    '14326137c657056596f2b89f729743e9a509c2bc46b86e64a3acaa2a98ad5401' = 'R170 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r170: Image 62763187, DTB a99cb124 (R167 + I2C5/I2C11 dual KTZ8866 backlight), initramfs c8b91978 (R169 + backlight.ko/tb371fc-ktz8866.ko at boot). Helper as R169 (60 s PC window, hold file). AUDIT_RESULT=PASS. Rollback: R169 f7ce009a.'
    'f7ce009a1312b9b0305fbf4dad89eff2e3a9a0650b20564601c975fef8e4366d' = 'R169 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r169: Image 62763187, DTB d427da0e, initramfs ddab373c (R167 + timesyncd restart, Chromium --disable-quic, Yandex policy). Helper: 60 s window when the USB gadget is configured (PC attached) and /run/tb371fc-autoboot-hold cancels like a button. AUDIT_RESULT=PASS. Rollback: R167 56212fab.'
    '56212fab7d84c3bcf84aaa84729af4a90df19b1362ca682b5840a306f85105ef' = 'R167 2026-10-25: R121 recovery (byte-identical kernel/DTB/recovery_dtbo/cmdline), autoboot tb371fc-linux/autoboot-6.12-r167: Image 62763187, DTB d427da0e (R165 + no-map 0x1d0000000/64M: RAM that hangs 6.12 after kexec), initramfs 4b0c5d85 (NetworkManager Wi-Fi with PMF off, 75 C passive trips, no screen lock, speakers, apps layer). AUDIT_RESULT=PASS. Rollback: R165 61e5638d.'
    '61e5638d17acc5f1eb4647ada413d3ba312eeb7419ad17dd72e5b679f8f040ce' = 'R165 2026-10-25: as R164 (R121 recovery, byte-identical kernel/DTB/recovery_dtbo/cmdline) but autoboot from tb371fc-linux/autoboot-6.12-r165 with DTB a7058d8e (R164 DTB without CPU operating-points-v2, so cpufreq-hw uses the EPSS LUT), Image 62763187, initramfs d6f308bc. AUDIT_RESULT=PASS. Rollback: R164 553fc648.'
    '553fc6486e123640f08fbade13e7a37f1b819b93908d568d56a951127e2a7718' = 'R164 2026-10-25: R121 recovery with byte-identical kernel/DTB/recovery_dtbo/cmdline; ramdisk adds optional microSD autoboot (tb371fc-linux/autoboot-6.12-r164 + ENABLE) of the hash-pinned Linux 6.12 R164 payload (R159 audio kernel; DTB 49c42b85 = R161 without CPU interconnects so cpufreq-hw probes; initramfs d6f308bc: TSENS thermal, speakers, Wi-Fi cold-boot fix, apps layer, timezone, sleep masked) with a 7 s cancel window. AUDIT_RESULT=PASS. Rollback: R163 b72c08f2.'
    'd9ee6a266ff629d8f516541e4f92eb504c210b0d91129e8f802bdbd545565d30' = 'R163b 2026-10-25: as R163 but initramfs 56264a18 (Wi-Fi cold-boot fix: PCIe endpoint remove+rescan). AUDIT_RESULT=PASS. Rollback: R163 b72c08f2 or R158 d3464681.'
    'b72c08f2817dc123a7e6bc95d0cca10e4f2e238664a657e5e72c8f4b4975d6ef' = 'R163 2026-10-25: R121 recovery with byte-identical kernel/DTB/recovery_dtbo/cmdline; ramdisk adds optional microSD autoboot (tb371fc-linux/autoboot-6.12-r163 + ENABLE) of the hash-pinned Linux 6.12 R163 payload (R159 audio kernel, R161 DTB, initramfs aad07281: speakers, Wi-Fi, timezone, optional apps layer, sleep masked) with a 7 s cancel window. AUDIT_RESULT=PASS. Rollback: R158 d3464681.'
    'd346468151e7ec855d5202ee67539a3dd4208669afbeb57380f342a5b3a831a4' = 'R158 2026-10-24: R121 recovery with byte-identical kernel/DTB/recovery_dtbo/cmdline; ramdisk adds optional microSD autoboot (tb371fc-linux/autoboot-6.12-r158 + ENABLE) of the hash-pinned Linux 6.12 R158 payload (R157 + all sleep targets masked at boot; Image 03b2f152, DTB e336fb1f, initramfs 05111101) with a 7 s cancel window. AUDIT_RESULT=PASS. Rollback: R157 f7cf5491.'
    'f7cf54916cef648e411a76cfececb12e2c729a1981c2e8cea2c250c625661de8' = 'R157 2026-10-24: R121 recovery with byte-identical kernel/DTB/recovery_dtbo/cmdline; ramdisk adds optional microSD autoboot (tb371fc-linux/autoboot-6.12-r157 + ENABLE) of the hash-pinned Linux 6.12 R157 payload (touch, KDE, keyboard; NO Wi-Fi autostart after R153 full hangs: Image 03b2f152, DTB e336fb1f, initramfs c16e279b) with a 7 s cancel window. AUDIT_RESULT=PASS. Rollback: R150 ddf9eb83 or R153 42ea7f50.'
    '42ea7f50172fd8056852d8c14557d6d2e9a53cf46a02f269203543fcaa458445' = 'R153 2026-10-24: R121 recovery with byte-identical kernel/DTB/recovery_dtbo/cmdline; ramdisk adds optional microSD autoboot (tb371fc-linux/autoboot-6.12-r153 + ENABLE) of the hash-pinned Linux 6.12 R153 payload (touch, KDE, Wi-Fi, keyboard: Image 03b2f152, DTB e336fb1f, initramfs 191523a1) with a 7 s on-screen cancel window. AUDIT_RESULT=PASS. Rollback: R150 ddf9eb83.'
    'ddf9eb83737b124b4f208ab0629daefb59c4e337d837667c68d27637017d1633' = 'R150 2026-10-24: R121 recovery with byte-identical kernel/DTB/recovery_dtbo/cmdline; ramdisk adds optional microSD autoboot (tb371fc-linux/autoboot-6.12 + ENABLE) of the hash-pinned Linux 6.12 R149b desktop payload with a 7 s on-screen cancel window (any button or touch keeps the 4.19 console). Audited by verify-diagnostic-recovery.sh, AUDIT_RESULT=PASS. Rollback: R121 976b4820.'
    '976b4820c956f011da6b21ef20884c9d344914afcfb1b7836021ca5c69f047e6' = 'R121 2026-10-23: audited r120 components preserved; first-stage panic=0 and persistent pre-handoff logs. Diagnostic candidate; Linux 6.12 boot not yet verified.'
    '64c6289b870fd91a91c0c569965d2992f99d3c81a2812ae72991343efc073f99' = 'R120 2026-10-01: exact r118 payload, r101 authenticated runtime, handoff markers, panic=0 and initcall_debug. Packaging/AVB/component audit PASS. Hardware boot unverified. Second-stage UFS/USB1 disabled.'
    '67e04f7369eccf1118874c7ec0d7aa4f57c9e020002801783d9008f9bd740b8d' = 'R118: rebuilt 6.12 r68 source with checkpoint NOP, built-in SM8250 pinctrl, native SD pin states and inherited CXO div2. Arch multi-user initramfs. Packaging/static audit passed 2026-09-07; hardware untested at approval. User requested flashing. Controlled V56.6 recovery; UFS/USB1 disabled in second stage.'
    '7b0b9d3fcceae0a0acc5b2a71b17622c23c925c3443cec9ec0a1aebf2c26cd66' = 'Linux 7.1.7 touch diagnostic'
    '7f5d22a3300a585b4f3f4fccff41615f158879f5fec7ed173b704cd8fa529825' = 'Linux 7.1.8 touch and dock diagnostic'
    '9106312de095b6029b7b9efc1345cb9736649406ae4ad2c52b98af5ae9155d56' = 'Lenovo 4.19 kernel with Linux NCM diagnostic userspace'
    'ff6136aa61b371b610a4e568d3438e04dac89692e1b15145822d3b9c8860b370' = 'One-shot Arch development-loader v13 with movable tmpfs-backed /dev'
    '337ed5b4bea68c957b01cf4ba95a803813df43f69591ee2d6dc79ebb67f108ce' = 'V18 v13-safe baseline with bounded dual-DSI and DSC trace'
    'baad93ea48260608a73874d16e4564e04719b9232ee1a6f1912612ab4442a0f5' = 'V19 program 2-2-2 DSC on first video continuous-splash commit'
    '755e2b27a943bfbad2f8a4556cc818882151950e6549f518c2563ac76fd46fa3' = 'V20 combine first-commit DSC programming with normal DSI bridge lifecycle'
    '492397eabc01f0102117ed4be0041925bf9e6f5b6a38f5a8522e53ef8883b999' = 'V21 opt-in full cold panel initialization without continuous-splash handoff'
    '5215220760386c2bf90844b5f77c895f3c9a09576fd78af90f3b3e72f696f698' = 'V22 automatic splash adoption followed by clean DRM disable and full panel re-enable'
    'dd1636136a88e73b725ebafa79b870017c702d4425b7f4c6a6290a4f954cde72' = 'V23 gated handoff commit before automatic full panel disable and re-enable'
    'ba9f185b03d1421a9a06917d83cd3236f90250e9eeaf82b23dd052bbadd8a12f' = 'V24 v23 sequence with bounded dual-DSI DSC PPS broadcast tracing'
    'a4dcdd7ada974f751164e3105e4cd918ccbcb188cac3aa77aac18bbcde3abe9c' = 'V25 synchronized dual-KTZ8866 external backlight after DSI post-enable'
    '65de13773358557abb86902a01fb7220bf34f8bd4a5ce04240214e8b3cee1008' = 'V26 reversible dual-DSI hardware test-pattern generator'
    '801721e309a68f5244741085acc6b342257de86ea6917b2d9a354eac09ea5f6d' = 'V27 idempotent full-width DSC PPS with per-link width restoration'
    '9243cf7cf261fb777a2d4889e1e56cb73f243ac37e009f2b282c0749189e37f4' = 'V28 program full-width dual-DSI DSC PPS before the cold panel ON sequence'
    'dc7bd05ce80312e5733b33867740596c83420ec828e1c03d1b0981fa8fc96089' = 'V30 verified kexec bridge for mainline 7.1.7 long-write v3'
    'e071200b8888d4d32488b6f90223256387d4091953853cb08d7e2d816048bb76' = 'V31 verified kexec bridge for mainline 7.1.7 PHY-config v4'
    '892d4b39d9fe98998e27660d778d9f157391bef688eebb4aed8a4c278ab858a8' = 'Mainline 7.1.7 native display PHY-config v4 direct recovery'
    '3e63740d14de47725722f9b86000e8181491cfab89f75d04d6818bf0be705569' = 'V32 downstream 4.19 NT36532 vendor DSC enable sequence'
    'c5fe930e71e1bc7267527c8723ab04bd1f80f6a7b6343fbbcdd0d042dc5b8c43' = 'V33 downstream 4.19 per-link DSC PPS width diagnostic'
    '205dae2250efbad6088406ce290818463d649540e8d895498fd51b3bea8285af' = 'V34 downstream 4.19 pre-ON-only DSC PPS with kexec bridge'
    '1506f5997880b52c6044eebc45538d98b4066e6ea0361c2a165235787713e39e' = 'V35 downstream 4.19 panel DCS status readback diagnostic'
    '50c56310ddb5f86c9ba523ff6f4e40da18d64d1c89f32be880ee4c28e3d67a36' = 'V36 V13-safe continuous-splash dual-interface flush and regulator retention'
    '245efca9726e69977737eafecd345ac37ae2732e9e5c990a4cfc9b626e6db12e' = 'V37 V36 dual-interface flush with early explicit AVDD hold'
    '329a421fa03e922c056c5b392ff2ed3cbb38c0b6441d673f62c467200e593301' = 'V38 continuous-splash stock-order full-panel DSC PPS before video engines'
    '6642a4142ba52d8fb8b8c0b713ef559fa3302ca0b7907d73534a190efb146e2d' = 'V39 V38 plus parsed stock 120 Hz command immediately after POST_ON'
    '56b08f54d682debaa9aae7acdabd4cf95cabb59b1db83582ba623b8fe56718d3' = 'V40 quiesce inherited dual-DSI video before PPS and hold red framebuffer'
    '31526ea3f58d770f08b5026754db10732661f528dfbd829e7b6dc12106f0d402' = 'V41 import inherited video state before the V40 OFF-PPS-ON frame boundary'
    '52b2ae1947bfaefebe8d66995df651bbd436fd5dc107cfb81948e414ffbfca6e' = 'V42 schedule PPS at a frame boundary while inherited dual-DSI video stays active'
    '816b166165093d558644d552fad2fd5c6841ceeaf508584ed1e4f4469a779d3b' = 'V43 exact Lenovo 4.19.157 kernel control with storage-safe Linux NCM and red KMS frame'
    'd58b484af8bc3592796d40e0d6dd7d46a54adf1a2885ad716fb7e29783b3e51e' = 'V44 exact Lenovo 4.19.157 control with the hardware-proven V4 NCM gadget setup'
    '7e7846b25d45fb6aea69277b6a48aaba156343197a7eafa48544fada43fb07e9' = 'V45 exact Lenovo 4.19.157 autonomous snapshots exposed as a read-only USB FAT log disk'
    '86e2eef5038ff6f82ffbd5786c1b260de21c6939fdac867cb3bf42dfc0c40e81' = 'V46 V45 control with display_panel_avdd regulator-always-on in embedded recovery DTBO entry 2'
    'ffd0377d05f5a1c7fe5fce7d43db52d7381c164f5224152929d460dc11bedfa5' = 'V47 community TB371FC parallel-SSPP source split with DT linewidth 0x758 and AVDD always-on'
    '9fc9920e3075482837ac86e015808764f94451a5234eec6242d3f223f9b217d2' = 'V48 V47 community parallel-SSPP with DRM KMS debug captured by the autonomous log disk'
    '025f98954dd76ffe2a31cdc7a096dde628cba051ef57bcbb189521f91d5b5e4a' = 'V49 community parallel-SSPP simplefb console with MDSS clocks and GDSC held'
    '807f6774e89b7dc8aadadcaf56f6167f19cf13a284af5890b913b2e3b0ed753c' = 'V50 V49 simplefb no-map fix with USB rescue and Arch key-only SSH handoff'
    '4a6ea5991599f589265c0d575fc16959a311bcdf1a62bcf8c02e3f6d280d4e35' = 'V51 physically proven V50 display with deterministic ACM-only serial ash'
    'f2e83276a37f1adb28703c963c08bdb688d9afd4ded9cd33bc4222011a795ccd' = 'V52 physically proven V50 display with NCM-only Arch OpenSSH handoff'
    '346b74f8be69e45a233fb0deaaf968a1e419519ff01f4ca7f8ef1735501be09a' = 'V53 proven simplefb and Arch root with key-only OpenSSH tunneled over ACM'
    '3a5c3f3afd40769f00ff7108a2b4f8ce83f9d420c9c0d4f50a904caa40e441ab' = 'V54 proven simplefb and Arch root with gated OpenSSH over ACM plus read-only inventory'
    'c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5' = 'V55 proven simplefb and Arch root with loopback OpenSSH gated over ACM'
    '943a658b99065d59fd40c56a3f792938aa306669d8963511559d3a07942c8cd5' = 'V56 V55-safe simplefb and Arch root with signed QCA6390 plus guarded KDE'
    '0cdf91ede1f046e2e842e3d6b21162c32b2e8b4562da8f6921c15718b4e3a710' = 'V56.1 V55-safe SDE TEST_ONLY fix, guarded QCA6390 and KDE'
    'b0cd0e66e9bade28c56c8215ed4f39503cf4649e02639cb72e779e6b4699447b' = 'V56.2 V56.1-safe CONFIG_FHANDLE udev/libinput fix'
    'a15c04affb52c67ec5fb3610cef35f0f0e3b1c0fc6b9ff74761bef9f1c967a8f' = 'V56.3 V56.2-safe kexec bridge with KDE, DNS and scale recovery'
    '39a088020bb69a8e44636603b1379160d89a6996aeb9e73605c2f602025ea666' = 'V56.3 r2 complete kexec handoff with corrected version labels'
    '854c70671cc91e588c666fbd970ec625e4ed4549c23f8ea8e14d510cab271df6' = 'V56.4 r2 kexec DRM-shutdown workaround with V56.3 r2 rollback'
    'c08efccc1f94d0c3da9ce0689b668c4640cc27523e64c97e81bde767eef1ab3b' = 'V56.5 r2 kexec CPU-hotplug wakeup-gate workaround with V56.3 r2 rollback'
    'f423a8a302d334b21bbe12dc1b8f1ff77f72a54ec5490bf4dcd415f36efcffcd' = 'V56.5 controlled Linux 6.12 loader r35 with explicit load and execute gates'
    'efb7c09e341be4eabea807f6a937e652a5fd4f314d7fe944de6d1fad3dd5c020' = 'V56.5 controlled Linux 6.12 loader r36 with single-CPU reset-devices handoff and placement log'
    'd7deb2ad6ef56f2f9087affaa76e44dde4e44113f98e7b16b0c7cccbffcb06e5' = 'V56.5 controlled Linux 6.12 loader r37 with corrected kexec flags and safe full-screen head.S stage markers'
    'a1b6df71bb6bc740efd98d33544cc382c379cfecab9b9a4753af81c90e849cac' = 'V56.5 controlled Linux 6.12 loader r37 transport r2 with self-rearming serial SSH gate'
    'bcbadfda9dcba345da4ddc853a3c77f9e76d19840538f3467811813ac13f2dba' = 'V56.6 controlled Linux 6.12 loader r39 transport r2: local watchdog fallback plus shutdown callback first stage, r38 reduced-marker no-post-MMU-write payload; audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass)'
    'd3a777e19a755673d52ba31e8ce0e41f3d4f5550de6b24bed00443f8b4251d00' = 'V56.6 controlled Linux 6.12 loader r40 transport r2 (v2, corrected load helper hash): same V56.6 watchdog-handoff first stage, r40 payload replaces the stage-75 post-MMU framebuffer write with a single PSCI SYSTEM_RESET checkpoint right after SCTLR_EL1 is written in __enable_mmu; audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). v1 hash 2b2c62e2540f149af5649c50cca6253e4564b3b8ab8a685eba66286181c41fff shipped load-linux-6.12-r38 unmodified, which rejected the r40 Image on its pinned r38 hash; do not use it. Hardware evidence from r39: reached stage 74 (TTBR1_EL1 loaded) before hanging with no auto-recovery since watchdog is disabled by design.'
    '85d48bba9e8ee143b57280df3d2c957cc0cd9459b50c317074d602ed9f9eb1d0' = 'V56.6 controlled Linux 6.12 loader r41 transport r2: same V56.6 watchdog-handoff first stage, r41 payload moves the single PSCI SYSTEM_RESET checkpoint from right after SCTLR_EL1 (r40 site) to right after __pi_early_map_kernel returns in __primary_switch; the load helper is generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r40 v2: the SCTLR_EL1 checkpoint fired and the tablet returned to V56.6 unattended within about a minute, proving execution survives the MMU-enable instant.'
    'f6f5a66dfd43dc0ad1279b2927043d55f5913fe5542c67b878c3b37151e5fb19' = 'V56.6 controlled Linux 6.12 loader r42 transport r2: same V56.6 watchdog-handoff first stage, r42 payload moves the single PSCI SYSTEM_RESET checkpoint from right after __pi_early_map_kernel (r41 site) to the very last instruction boundary in head.S, right before "bl start_kernel" in __primary_switched (after set_cpu_boot_mode_flag, kasan_early_init and finalise_el2/EL2-VHE transition). Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r41: the __pi_early_map_kernel checkpoint fired and the tablet returned to V56.6 unattended, proving kernel relocation and final page tables under the enabled MMU complete without faulting.'
    '08d61bc1adf1e77a16a7898e40f5203646e51b2f5cd556a3287ca789fc33a6ea' = 'V56.6 controlled Linux 6.12 loader r43 transport r2: same V56.6 watchdog-handoff first stage, r43 payload removes the PSCI SYSTEM_RESET checkpoint entirely so start_kernel actually runs; head.S is otherwise identical to r42 (TGran bypass, watchdog handoff, reduced pre-MMU markers, no post-MMU framebuffer writes). No automatic recovery exists past the kexec transition on this build; a hang requires a physical power-cycle, same as r39. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r42: the pre-start_kernel checkpoint fired and the tablet returned to V56.6 unattended, proving the entire head.S assembly path completes without faulting.'
    'a3d6f5890e1a9bba64a2619bdc7b468b104a5175a7b320c326e0a968388eb047' = 'V56.6 controlled Linux 6.12 loader r44 transport r2: same V56.6 watchdog-handoff first stage, head.S identical to r43 (no checkpoint there). r44 payload places the single PSCI SYSTEM_RESET checkpoint as the literal first statement inside start_kernel() in init/main.c, before set_task_stack_end_magic and the pre-existing (still disabled) TB371FC_START_MARKER framebuffer chain. Firing proves the "bl start_kernel" jump and the C prologue succeed. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r43: no checkpoint existed, the tablet hung with a genuine Windows-side serial device error (not the usual port-contention race) and required a physical power-cycle; the fault could not be localized further than "somewhere after the r42 checkpoint site."'
    '4a8f61ad2081eb2024fa88b782c917ecca7cbbbd5da0f04e371394d0de9dc40d' = 'V56.6 controlled Linux 6.12 loader r45 transport r2: same V56.6 watchdog-handoff first stage, head.S unchanged since r43 (no checkpoint there). r45 payload moves the single PSCI SYSTEM_RESET checkpoint from the first statement of start_kernel() (r44 site) to right after setup_arch() returns in init/main.c. Firing proves setup_arch() (the first large arch-specific subsystem start_kernel calls) completes without faulting. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r44: the start_kernel()-entry checkpoint fired and the owner observed the tablet reboot itself, confirming the "bl start_kernel" jump and C prologue both succeed.'
    '7cd4f50ea837e3953fa4b2b091221e8a8df3f221ea099b15283a4af96f6a81b7' = 'V56.6 controlled Linux 6.12 loader r46 transport r2: same V56.6 watchdog-handoff first stage. r46 payload moves the single PSCI SYSTEM_RESET checkpoint from right after setup_arch() returns (r45 site) to right after setup_machine_fdt(__fdt_pointer) returns, inside setup_arch() in arch/arm64/kernel/setup.c. Tests whether parsing this board community 6.12 device tree succeeds, isolated from jump_label_init/parse_early_param/cpu_uninstall_idmap which run afterward. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r45: checkpoint after setup_arch() did not fire; the tablet hung with the same error-31 serial signature as r43 and required a physical power-cycle, narrowing the fault to inside setup_arch() itself.'
    'c43d3481fd00ad5dbacfd9c63be9e588768904e9afac1a4a188bc5cf2a8d4864' = 'V56.6 controlled Linux 6.12 loader r47 transport r2: same V56.6 watchdog-handoff first stage. r47 payload moves the single PSCI SYSTEM_RESET checkpoint from right after setup_machine_fdt (r46 site) to right after paging_init() returns in setup_arch(), past jump_label_init/parse_early_param/dynamic_scs_init/local_daif_restore/cpu_uninstall_idmap/xen_early_init/efi_init/arm64_memblock_init. Tests whether building the real kernel page tables (swapper linear map) succeeds under this kexec handoff, isolated from the later separate unflatten_device_tree() call. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r46: the setup_machine_fdt checkpoint fired and the tablet returned to V56.6 unattended, proving this board community 6.12 device tree parses without faulting.'
    '3d43660097fcfc3a10f9274a535217ce682e293b13bb635839b71a0b9625d189' = 'V56.6 controlled Linux 6.12 loader r48 transport r2: same V56.6 watchdog-handoff first stage. r48 payload moves the single PSCI SYSTEM_RESET checkpoint from right after paging_init() returns (r47 site) to right after map_mem(swapper_pg_dir) returns, inside paging_init() in arch/arm64/mm/mmu.c, before memblock_allow_resize/create_idmap/declare_kernel_vmas. Tests whether building the full RAM linear map (from current memblock regions) succeeds under this kexec handoff. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45/r47. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass). Hardware evidence from r47: checkpoint after paging_init() did not fire; the tablet hung with the same error-31 serial signature as r43/r45 and required a physical power-cycle, narrowing the fault to inside paging_init() itself.'
    '77b10e524d0bf7118803f104507590ec0ed5a8840a89a79fb154a584b089a277' = 'Direct-recovery COLD BOOT (no kexec, r33-style ABL-entry shim wrapper) of the exact same r48 Image (checkpoint right after map_mem() in paging_init()). The ABL boots straight into a tiny position-independent assembly shim embedded in the kernel slot; the shim copies the real 6.12 Image to 0xa4000000 and jumps to it directly. V56.5/V56.6 4.19 never executes in this path at all -- no kexec, no warm handoff, no residual cache/TLB state from any prior kernel. Purpose: determine whether the r47/r48 hang (checkpoint after map_mem not firing) is a kexec-transition artifact (stale cache/TLB from the outgoing 4.19 kernel) or a genuine board/memory-map bug independent of kexec. Same TGran-bypass-equivalent head.S as r48 (inherited from the r38-r48 lineage). Built via build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh; all internal checks (unpack, byte-identical embedded Image extraction, AVB verify_image) passed at build time. Size exactly 104857600 bytes.'
    'fee351fee1aa86a7d44384c7d563ea3e71da5f07d6dc3d539facecba706f46ff' = 'V56.6 controlled Linux 6.12 loader r49 transport r2: same V56.6 watchdog-handoff first stage. CANDIDATE FIX, not just a diagnostic: adds a single flush_tlb_all() (broadcast inner-shareable TLB invalidate-all) immediately before map_mem() in paging_init() (arch/arm64/mm/mmu.c), on the hypothesis that stale TLB entries from the outgoing V56.6 4.19 kexec source kernel are why map_mem() hangs only under kexec and not under an identical cold ABL boot (2026-08-28 cold-boot pivot finding). machine_kexec.c flushes D/I-cache for the kexec segments but never invalidates the TLB and never touches ordinary RAM the incoming kernel reuses for its own page tables. Checkpoint moved back to right after paging_init() returns -- the same site r47 tested without the fix and did not reach -- for a direct comparison. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45/r47. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-28 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'ddd6f101e0bd6677c3fc574637f8eacaaf09812099cf23550dafb88b7d9b2127' = 'V56.6 controlled Linux 6.12 loader r50 transport r2: same V56.6 watchdog-handoff first stage. REVISED HYPOTHESIS after r49 TLB fix was refuted: the community 6.12 DTS reserved only cont_splash_mem, unlike stock which reserves many fixed remote-processor firmware/PIL regions (ADSP, QCA6390 WLAN, CDSP, SLPI, SPSS, video, CVP, NPU, GPU, IPA, camera, cdsp secure heap, SMEM, boot log, etc) as no-map. Under kexec from a live V56.6 those subsystems are already running with firmware resident in exactly those addresses; the r48 cold-boot test (nothing running yet) passed the same checkpoint that every kexec attempt failed. r50 adds the same fixed-address no-map reservations (verbatim addresses/sizes from the decompiled stock DTB) to sm8250-lenovo-tb371fc-archsafe.dts, rebuilds only the DTB, and reuses r47 unmodified Image (checkpoint after paging_init() returns, no TLB fix) unchanged, isolating the DTS-only hypothesis. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45/r47/r49. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '602e4d15ca6ea03be82b6e6de66fb2018a0d68e599f8597401d4b1cb16cc7069' = 'V56.6 controlled Linux 6.12 loader r51 transport r2: same V56.6 watchdog-handoff first stage. PLACEMENT-AMBIGUITY DIAGNOSTIC after r49 (TLB fix) and r50 (reserved-memory DTS) were both refuted at the same checkpoint site (right after paging_init() returns): that site cannot distinguish a fault inside paging_init()/map_mem() from a fault in whatever setup_arch() runs immediately after paging_init() returns. r51 moves the SAME single PSCI checkpoint to the very first statement inside paging_init(), before map_mem() runs, built on top of r47 tree (no TLB fix, no extra DTS reservations, isolating the placement question alone). Uses the same diag39 DTB as r47/r49 (no extra reserved-memory nodes). Firing confirms the fault is inside paging_init()/map_mem() itself; not firing means the fault is actually between arm64_memblock_init() and paging_init(), invalidating the r47-r50 narrowing. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '504c0f612b559067ed14e3609c99c4bf4c960bc7320baa0280d36b1fc5e9a3d3' = 'V56.6 controlled Linux 6.12 loader r52 transport r2: same V56.6 watchdog-handoff first stage. r51 proved the fault is inside paging_init()/map_mem() (checkpoint at entry fired, tablet auto-recovered). r52 splits map_mem() in half: moves the SAME single PSCI checkpoint to right after the for_each_mem_range() memory-bank mapping loop inside map_mem() completes, before the kernel-text-specific remap and arm64_kfence_map_pool(). Firing narrows the fault to the kernel-text remap/kfence-pool tail; not firing narrows it to the memory-bank mapping loop itself. Built on r47 tree (no TLB fix, no extra DTS reservations), same diag39 DTB as r47/r49/r51. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'f2ae92cee6b077c2c9eac0165a32cf8fb742aed782a844330e032f7830a4acfd' = 'V56.6 controlled Linux 6.12 loader r53 transport r2: same V56.6 watchdog-handoff first stage. r52 proved the checkpoint right after the for_each_mem_range() membank loop does NOT fire (hung); r51 proved entry to paging_init()/map_mem() is clean. r53 splits the remaining range: moves the SAME single PSCI checkpoint to right before the for_each_mem_range() loop begins, immediately after memblock_mark_nomap(). Firing narrows the fault to inside the loop itself (mapping one of the memory regions); not firing narrows it to arm64_kfence_alloc_pool() or memblock_mark_nomap(). Built on r47 tree (no TLB fix, no extra DTS reservations), same diag39 DTB as r47/r49/r51/r52. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50/r52. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '6b3bdbee9972945582f01590f4c3442c84fc7bf222f868d0ac488153f04a2126' = 'V56.6 controlled Linux 6.12 loader r54 transport r2: same V56.6 watchdog-handoff first stage. r53 proved the fault is inside the for_each_mem_range() loop body itself (checkpoint before the loop fired; r52 after the loop hung). r54 moves the SAME single PSCI checkpoint unconditionally to right after the __map_memblock() call inside the loop body -- fires after the FIRST loop iteration completes, before any second iteration can run. Firing narrows the fault to a LATER memblock region; not firing means the very first memblock region already faults. Built on r47 tree (no TLB fix, no extra DTS reservations), same diag39 DTB as r47/r49/r51-r53. No automatic recovery if it does not fire; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50/r52. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'fd02476ef1f3ea32009edbb4700edd8bf772ca5bff95afa5077aa009aac501d8' = 'V56.6 controlled Linux 6.12 loader r55 transport r2: same V56.6 watchdog-handoff first stage. r53/r54 proved the fault is inside the VERY FIRST __map_memblock() call of the for_each_mem_range() loop in map_mem(). Instead of continuing blind bisection, r55 adds a real Kconfig prompt for the previously-dead TB371FC_LATE_FB_MARKER infrastructure and a new tb371fc_diag_write_region() helper that writes the current loop iteration index and memblock region [start,end) into fixed physical scratch memory (0x9d5ff000+0x40, backup 0xb007f000+0x40 inside stock boot_log_region) before every __map_memblock() call. No PSCI reset added -- execute is expected to hang exactly as r54 did, requiring the same physical power-cycle, but the scratch memory then holds the last-attempted region readable via devmem after recovery. Built on r47 tree. No automatic recovery; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50/r52/r54. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '96930c9e672a1d2be90873fe92a4e297b16b9021b9b5dc46cbda3b44939a2bb4' = 'V56.6 controlled Linux 6.12 loader r56 transport r2: same V56.6 watchdog-handoff first stage. r55 confirmed the same hang, and its physical-scratch diagnostic write cannot be read back: V56.6 4.19 has STRICT_DEVMEM blocking /dev/mem access to ordinary RAM (devmem fails with "No such device or address" despite mknod succeeding). r56 keeps the scratch write (harmless) and adds a second channel that IS readable: paints the current memblock region start address as an RGB colour (0xFFRRGGBB, R/G/B = bits[31:24]/[23:16]/[15:8]) into the same diagnostic framebuffer band the already-proven-working late-stage markers use, called right before every __map_memblock(). No PSCI reset; execute is expected to hang, requiring a physical power-cycle same as r43/r45/r47/r49/r50/r52/r54/r55, but the LAST colour painted (readable via photo) identifies which memblock region was being mapped when it hung. Built on r55 tree. Load helper generated at package time with the hash matching this build actual Image, verified by an in-script grep assertion. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'bf421bb7462c4d38bd99982de4c1ca5471da65bac597c8f73598d435378e3fbd' = 'V56.6 controlled Linux 6.12 loader r57 transport r2: same V56.6 watchdog-handoff first stage. r56 hardware test hung as expected, and a clear close-up photo of the framebuffer colour diagnostic band read back as pure red, decoding to start address 0xb0000000 (R=0xb0,G=0x00,B=0x00 in the 0xFFRRGGBB encoding) -- the stock boot_log_region, actively used by V56.6 own autonomous snapshot-log feature and NOT reserved in the plain community DTS. r57 reverts the shared r47 donor tree DTS back to the plain single-node (cont_splash_mem only) baseline (r50 had permanently modified it in place with 19 regions) and adds ONLY boot_log_region (0xb0000000, 0x80000) as no-map, a narrow targeted test distinct from r50 full 19-region attempt which was also tested at the wrong (post-loop) checkpoint. Reuses r56 Image unchanged (fb-colour diagnostic still active, no PSCI reset) with the new r57 DTB. If the hang moves/clears, boot_log_region is confirmed as (at least one) root cause; if identical, the colour diagnostic will show what memory region is now first in the iteration order. No automatic recovery; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50/r52/r54/r55/r56. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'f914042eacccc3efae5040651976b114b121f58f6a6131265d19d32673697087' = 'V56.6 controlled Linux 6.12 loader r58 transport r2: same V56.6 watchdog-handoff first stage. r57 DTB no-maps boot_log_region and should_skip_region() in mm/memblock.c confirms for_each_mem_range() should skip MEMBLOCK_NOMAP regions, but the r57 hardware photo read back the same ambiguous reddish colour as r56. r58 removes colour ambiguity between boot_log_region (0xb0000000) and visually-similar neighbours (e.g. 0x8be00000/0x8bf00000) with an unmistakable boolean indicator: pure blue (0xFF0000FF) if the region about to be mapped is EXACTLY 0xb0000000, otherwise the same 0xFFRRGGBB address encoding. Reuses r57 DTB unchanged (boot_log_region no-map). No automatic recovery; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50/r52/r54/r55/r56/r57. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '230a53d2617cad7bc392a25ae195d35f72471f134fbd64020bd89fba3febf768' = 'V56.6 controlled Linux 6.12 loader r59 transport r2: same V56.6 watchdog-handoff first stage. r58 confirmed boot_log_region (0xb0000000) no-map reservation worked (colour was NOT the unmistakable pure blue exact-match). r59 replaces the ambiguous 0xFFRRGGBB encoding with an exact-match lookup against all 18 remaining stock PIL/firmware candidate addresses, each assigned a maximally distinct flat colour (white/red/green/blue/yellow/magenta/cyan/orange/pink/chartreuse/spring-green/azure/violet/gray/light-gray/brown/teal/dark-spring-green), falling back to the plain address encoding only for a genuinely unexpected region. Reuses r57 DTB unchanged (boot_log_region no-map). No automatic recovery; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50/r52/r54/r55/r56/r57/r58. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '21d27acbfd69413236b7a2060519e3b5d13bb2191082fffe0552518fdc267d07' = 'V56.6 controlled Linux 6.12 loader r60 transport r2: same V56.6 watchdog-handoff first stage. r56-r59 colour-based diagnostics proved repeatedly too ambiguous to read from a phone photo. r60 replaces colour entirely with an unambiguous 8-column bar graph: one bar per hex nibble of the region start address (MSB first, left to right), each bar filled white from the bottom up to (nibble value + 1) rows out of 16 -- the address is read directly off bar heights, no colour perception needed. Reuses r57 DTB unchanged (boot_log_region no-map). No automatic recovery; a hang requires a physical power-cycle, same as r43/r45/r47/r49/r50/r52/r54/r55/r56/r57/r58/r59. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '516547f4de3d32bee043fd3190c6a9f6df363a9d0d4458a80e8949aaf90c4fc4' = 'V56.6 controlled Linux 6.12 loader r61 transport r2: same V56.6 first stage AS A CANDIDATE ROOT-CAUSE FIX, not just a diagnostic. Live investigation on the booted V56.6 rescue shell found /sys/bus/msm_subsys/devices/subsys9 (name=wlan) is the ONLY PIL subsystem still ONLINE at the point of kexec (every other: adsp/cdsp/venus/spss/cvpss/slpi/a650_zap/npu/ipa_fws/ipa_uc reports OFFLINING). Its platform device b0000000.qcom,cnss-qca6390 is registered at physical 0xb0000000 -- the exact address r56 read back from the framebuffer diagnostic and the project DTB had mislabeled boot_log_region; it is actually QCA6390 WLAN, live because cnss2 never gets a clean shutdown before kexec. Hardware-confirmed live: unbinding cnss2 (echo device name to /sys/bus/platform/drivers/cnss2/unbind) cleanly tears the subsystem down (regulators dropped, subsys9 disappears) with no effect on the USB-ACM control channel. r61 adds this unbind step to the shared initramfs/execute-linux-6.12-r38 script (best-effort, does not fail handoff if already gone), right before the existing watchdog-disable step. No kernel/DTB change: reuses r60 Image (bar-graph diagnostic kept active in case further localization is needed) and r57 DTB unchanged. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'b6dd939e98cdaaa7931640e6337be55457a2dbb6068a59f8dcd52f6aaa805558' = 'V56.6 controlled Linux 6.12 loader r62 transport r2: same V56.6 first stage with confirmed WLAN unbind fix (kept, insufficient alone per r61). r62 replaces r60 unreadable bar graph with a spotlight indicator: 20 equal segments (18 stock PIL candidates + boot_log_region/WLAN + unknown), ONLY the matching segment lit solid white, all others black -- unambiguous single-glance read, no measurement or colour matching needed. Reuses r57 DTB unchanged. No automatic recovery; a hang requires a physical power-cycle, same as prior revisions. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'f2034d513dceba80ff1d0405db0ce8177d483e139d29423c3ff180413d3d6f09' = 'V56.6 controlled Linux 6.12 loader r63 transport r2: same V56.6 first stage with WLAN unbind fix. Reuses r60 Image unchanged (8-bar hex-nibble address diagnostic -- the encoding is sound, r60 own hardware photo was just taken at too shallow an angle to read) + r57 DTB (boot_log_region no-map). /proc/iomem read live from V56.6 confirms the real first System RAM block starts at 0x80600000, not on this investigation prior PIL-region candidate list, explaining r62 spotlight showing "unknown". No automatic recovery; a hang requires a physical power-cycle, same as prior revisions. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    '45d69af926a67582f5f5447c5b063cfeabf07660261efef04003763c5acbe224' = 'V56.6 controlled Linux 6.12 loader r64 transport r2: targeted structural test for the first __map_memblock hang. Live V56.6 showed all 256 pages in the first 0x80600000-0x806fffff System RAM bank are KPF_SLAB immediately before kexec; r64 therefore makes early_pgtable_alloc use a dedicated page-aligned 1 MiB pool inside the incoming Image BSS instead of ordinary post-4.19 slab/DMA memory. A single PSCI SYSTEM_RESET checkpoint immediately after paging_init provides an unambiguous result: automatic reset confirms the early-page-table corruption hypothesis; the old diagnostic hang refutes it and calls for alloc_init_p4d/pud/pmd checkpoints. Keeps the confirmed cnss2/WLAN unbind and r57 DTB. Audited 2026-08-29: boot header, AVB footer, kernel, ramdisk and DTB verified byte-for-byte; AUDIT_RESULT=PASS.'
    '070b7bc94eaf7a5b0acd73dc787fb722eb9af8c715506f7ff89f3ff3275d3aae' = 'V56.6 controlled Linux 6.12 loader r65 transport r2: retains the hardware-proven r64 dedicated 1 MiB early page-table pool unchanged and moves the single PSCI SYSTEM_RESET checkpoint from immediately after paging_init() to immediately after setup_arch() returns in start_kernel(). Automatic reset proves the remainder of arm64 setup_arch() survives the warm kexec handoff; no reset localizes the next fault to the interval after paging_init(). Keeps confirmed cnss2/WLAN unbind, r57 DTB and proven Arch initramfs. Audited 2026-08-29: boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    '7f30fe67edbf633945dccf78df02f680b6a5925d11951fb1f677dd1d5852acb2' = 'V56.6 controlled Linux 6.12 loader r66 transport r2: retains the hardware-proven r64 dedicated 1 MiB early page-table pool and all r65 transport components unchanged. The only kernel diagnostic change moves the single PSCI SYSTEM_RESET checkpoint to immediately after xen_early_init() and before efi_init(). Automatic reset proves xen_early_init() returned and localizes the r65 stall to efi_init() or later; no reset with final stage-26 green marker localizes it to xen_early_init() or entry into that call. Keeps confirmed cnss2/WLAN unbind, r57 DTB and proven Arch initramfs. Audited 2026-08-29: boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    '4214533e6977208ad6d5745c5bdcc6c693fd598574e40459d749e9be4b928e42' = 'V56.6 controlled Linux 6.12 loader r67 transport r2: retains the hardware-proven r64 dedicated 1 MiB early page-table pool and all r66 handoff components unchanged. r66 hardware-fired its PSCI checkpoint and proved xen_early_init() returns. The only r67 kernel diagnostic change moves the single PSCI SYSTEM_RESET checkpoint to immediately after efi_init(). Automatic reset proves EFI initialization returns; no reset with final stage-26 green marker localizes the layout-sensitive stall to efi_init(). Keeps confirmed cnss2/WLAN unbind, r57 DTB and proven Arch initramfs. Audited 2026-08-29: boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    'c92c84c5cd67c80a72c3e43d1fff67e57933f59fbdcc468427b063839ba428c6' = 'V56.6 controlled Linux 6.12 loader r68 transport r2: retains the hardware-proven r64 dedicated 1 MiB early page-table pool and all r67 handoff components unchanged. r67 hardware-fired its PSCI checkpoint and proved efi_init() returns. The only r68 kernel diagnostic change moves the single PSCI SYSTEM_RESET checkpoint to immediately after arm64_memblock_init() and before paging_init(). Automatic reset proves arm64_memblock_init() returns; no reset after the stage-27 marker localizes the layout-sensitive stall to the EFI warning block or arm64_memblock_init(). Keeps confirmed cnss2/WLAN unbind, r57 DTB and proven Arch initramfs. Audited 2026-08-29: boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    '15f65c8b338876abad5d34f995c0cbc0a152f050c85d44a8a48724f1b2491e3c' = 'V56.6 controlled Linux 6.12 loader r69 transport r2: FULL BOOT TEST, no diagnostic checkpoint. Keeps the hardware-proven embedded early page-table pool (r64/r68: 256-page/1MiB static array in the kernel own Image/BSS used by early_pgtable_alloc() instead of memblock_phys_alloc(), confirmed to let checkpoints fire cleanly on both sides of paging_init()/map_mem() plus setup_arch()/xen_early_init()/efi_init()/arm64_memblock_init()) and WLAN cnss2 clean unbind before kexec. r57 DTB (boot_log_region no-map) and proven Arch initramfs unchanged. Tests whether Linux 6.12 now reaches a full, sustained Arch/KDE boot under a live kexec handoff from V56.6. No PSCI reset; if it does not fully boot, a hang requires a physical power-cycle same as prior revisions. Load helper generated at package time with hashes matching this build actual Image and DTB, verified by in-script grep assertions. Audited 2026-08-29 via verify-diagnostic-recovery.sh (magic/header/size/AVB/byte-identical components all pass).'
    'b87db3cb7efac5c68476618964a03191ca63b0387d216b5a5d26f1cc907459fb' = 'V56.6 controlled Linux 6.12 loader r70 transport r2: layout-preserving full-boot test derived directly from the twice hardware-proven r68 Image. No compilation or relinking: exactly four bytes at Image offset 0x019c5238 change the single checkpoint instruction from AArch64 smc #0 to an equal-size nop. Every byte before and after was verified identical. Keeps the r68 embedded 1 MiB early page-table pool, framebuffer markers and complete code layout, plus unchanged r57 DTB and proven Arch initramfs. This isolates the relink/layout difference that made r69 stop near stage 27. Audited 2026-08-29: exact four-byte delta, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '85b62c335c74248a4ebd57326e47569c48b5ce87e1331b1538a960f1e1bca7b9' = 'V56.6 controlled Linux 6.12 loader r71 transport r2: layout-preserving late setup_arch checkpoint derived directly from r70. No compilation or relinking. Three equal-size AArch64 instructions make the normal post-arm64_memblock_init path skip the dormant reset sequence, restore its smc #0, and branch to it only after unflatten_device_tree(), bootmem_init(), request_standard_resources(), and early_ioremap_reset() return, immediately before psci_dt_init(). Automatic reset proves that late interval; no reset with the stage-30 purple stripe localizes the hang inside it. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact 12-byte delta, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    'fe75c85c166e0361d0902b6c7f0464556eea15a9b11c52c45155ceb0a6899f14' = 'V56.6 controlled Linux 6.12 loader r72 transport r2: layout-preserving midpoint checkpoint derived directly from r71. No compilation or relinking. Restores the original psci_dt_init() call and moves the branch into the audited PSCI reset trampoline to immediately after unflatten_device_tree() and bootmem_init() return, before request_standard_resources(). Automatic reset proves both calls; no reset with stage-30 localizes the hang to one of them. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r71, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    'c23d34cdb7d5736067391441b25d088ebed6694e00d2d6ad6760b3b004dc037e' = 'V56.6 controlled Linux 6.12 loader r73 transport r2: final layout-preserving split of the r72 interval. No compilation or relinking. Restores the request_standard_resources() call and moves the branch into the audited PSCI reset trampoline to immediately after unflatten_device_tree() returns, before bootmem_init(). Automatic reset proves unflatten_device_tree() and localizes r72 to bootmem_init(); no reset with stage-30 localizes the hang to unflatten_device_tree(). Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r72, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '8eaa8681df615d4e37764a6f83f7cdc5d8a26ac6b29396c23a3c2cca38ef2f24' = 'V56.6 controlled Linux 6.12 loader r74 transport r2: layout-preserving checkpoint inside unflatten_device_tree(). No compilation or relinking. Restores the setup_arch bootmem_init() call and branches into the audited PSCI reset trampoline immediately after fdt_scan_reserved_mem_reg_nodes() returns. Automatic reset proves the reserved-memory flat-DT scan and localizes r73 to __unflatten_device_tree() or of_alias_scan(); no reset localizes the hang inside fdt_scan_reserved_mem_reg_nodes(). Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r73, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '1034659931abef733e479dc693f065dbacde33e79881fcba4790464d34d9df6a' = 'V56.6 controlled Linux 6.12 loader r75 transport r2: layout-preserving checkpoint inside unflatten_device_tree(). No compilation or relinking. Restores the post-reserved-memory-scan control flow and branches into the audited PSCI reset trampoline immediately after __unflatten_device_tree() returns. Automatic reset proves the core unflatten and localizes r73 to of_alias_scan(); no reset localizes the hang inside __unflatten_device_tree(). Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r74, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '719c9c389bca6275d0e66b8b73f3c9586d4163a4064a950da89701e6c3cd434e' = 'V56.6 controlled Linux 6.12 loader r76 transport r2: layout-preserving checkpoint inside __unflatten_device_tree(). No compilation or relinking. Restores the r75 caller checkpoint and branches into the audited PSCI reset trampoline immediately after the first sizing-only unflatten_dt_nodes(blob, NULL, ...) returns. Automatic reset proves the first sizing pass and localizes the remaining fault to allocation, clearing, or the second population pass; no reset localizes the hang inside the first unflatten_dt_nodes() pass. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r75, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    'df750b64cb1408569e263630f30f814251393b7556540a12ff579acafb3d6d2a' = 'V56.6 controlled Linux 6.12 loader r77 transport r2: layout-preserving checkpoint inside __unflatten_device_tree(). No compilation or relinking. Restores the r76 sizing-pass checkpoint and branches into the audited PSCI reset trampoline immediately after early_init_dt_alloc_memory_arch() returns from allocating the unflattened tree buffer. Automatic reset proves sizing and allocation; no reset localizes the hang to size handling or the allocation callback/memblock_alloc(). Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r76, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '27a139ae3cdc0dec3b5db12ecf95efb127df5dcbe11eab5bc57d0e139207baed' = 'V56.6 controlled Linux 6.12 loader r78 transport r2: layout-preserving checkpoint inside memblock_alloc_try_nid(). No compilation or relinking. Restores the r77 outer allocator checkpoint and branches into the audited PSCI reset trampoline immediately after memblock_alloc_internal() returns, before memblock_alloc_try_nid() clears the allocation. Automatic reset proves memblock allocation search/reservation returned and localizes the fault to clearing or callback epilogue; no reset localizes the hang inside memblock_alloc_internal(). Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r77, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '904b8036c774d2cd1539019bf59c6201860b03b74cd94635890cf43b9d876979' = 'V56.6 controlled Linux 6.12 loader r79 transport r2: layout-preserving checkpoint inside memblock_alloc_try_nid(). No compilation or relinking. Restores the r78 post-memblock_alloc_internal checkpoint and branches into the audited PSCI reset trampoline immediately after the allocation-clearing __memset returns. Automatic reset proves the returned allocation can be zeroed and localizes the fault to callback/outer epilogue; no reset localizes the hang to that __memset and strongly indicates an invalid or unmapped allocated virtual address. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r78, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    'd97cb7e93a34e4d44eaae91dd945e7861e71db8e74a4e88752ec0f3f2fd17a2d' = 'V56.6 controlled Linux 6.12 loader r80 transport r2: layout-preserving checkpoint inside early_init_dt_alloc_memory_arch(). No compilation or relinking. Restores the r79 post-zero-fill checkpoint and branches into the audited PSCI reset trampoline immediately after the complete memblock_alloc_try_nid() call returns. Automatic reset proves its stack-protector and return epilogue; no reset localizes the hang to that epilogue after the already-proven zero-fill. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r79, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '9214499d38ef463d8e0d58cf30550863a7799835b3a105a16f48be31863fec74' = 'V56.6 controlled Linux 6.12 loader r81 transport r2: layout-preserving checkpoint at the successful-path ret of early_init_dt_alloc_memory_arch(). No compilation or relinking. Restores the r80 post-memblock_alloc_try_nid checkpoint and replaces the final ret, after ldp/autiasp, with a branch into the audited PSCI reset trampoline. Automatic reset proves the allocator reaches its final return instruction; combined with r77 failure, it isolates the fault to the authenticated return/control transfer itself. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r80, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '99979c175a3f58be10081b2c68f9190f2c1cad3d6b9c109252f990fc2141d8dc' = 'V56.6 controlled Linux 6.12 loader r82 transport r2: layout-preserving checkpoint immediately before autiasp in the successful epilogue of early_init_dt_alloc_memory_arch(). No compilation or relinking. Restores the r81 final ret and replaces autiasp, after both stack-load instructions, with a branch into the audited PSCI reset trampoline. Automatic reset proves stack restoration completes and localizes r81 to autiasp; no reset localizes the fault to the preceding stack loads. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r81, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '00ad8a32a684712f1c591a95ba652cfa19cd439af3569f29ba2b753388fb29e4' = 'V56.6 controlled Linux 6.12 loader r83 transport r2: corrected layout-preserving DT allocator success checkpoint. No compilation or relinking. Keeps the original cbz x0 failure test intact and replaces the first instruction reached only when memblock_alloc returns a non-NULL pointer with a branch into the audited PSCI reset trampoline. This removes the r78-r80 ambiguity: r80 proved the cbz was reached, while r83 reset proves success and r83 no-reset proves NULL/panic. Keeps exact r70/r68 layout, embedded 1 MiB early page-table pool, unchanged r57 DTB and proven Arch initramfs. Audited 2026-08-29: exact eight-byte delta from r82, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified; AUDIT_RESULT=PASS.'
    '22d957cd297b8779fd8b91a87e794a75c5c705b206078eaf02d55f68cab972f5' = 'V56.6 controlled Linux 6.12 loader r84 transport r2: root-cause verification for the DT allocator failure. Keeps the exact r83 success-only memblock_alloc checkpoint Image and changes only /memory@80000000/reg in the embedded board DTB: the inherited zero-size SM8250 placeholder is replaced with 19 exact usable System RAM ranges reported by the running V56.6 kernel after firmware holes were subtracted (0x1cacf9000 usable bytes). Automatic reset proves the memory description makes early memblock allocation non-NULL; no reset refutes the DT root-cause hypothesis. Audited 2026-08-29: DT semantic diff is exactly one property, 76 cells/19 ordered page-aligned ranges verified, payload Image and DTB hashes pinned in the loader, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    '1a0bc77242367abff3abf29a0ab57af7ff31a8e0b6be778da636c8826ac79460' = 'V56.6 controlled Linux 6.12 loader r86 transport r2: disambiguates r84 no-reset after adding real RAM. Pairs the exact hardware-proven r64 Image (dedicated 1 MiB early page-table pool and PSCI reset immediately after paging_init) with the unchanged r84 DTB containing 19 real System RAM ranges. Automatic reset proves the full real-RAM paging_init/map_mem path completes and moves the remaining issue back after paging_init; no reset proves that the zero-RAM DTB had hidden an earlier real-memory linear-map failure. Audited 2026-08-29: exact r64 Image SHA-256 f94392343bc245c572895628c894a720f924a42a30c10f22ab4983ef8bd531b6, exact r84 DTB SHA-256 c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae, loader hashes pinned, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    '42606d199a8892d79b42a64934cef3e0fbdf04961a26d8c3594cbacbe285fbd0' = 'V56.6 controlled Linux 6.12 loader r87 transport r2: minimal real-memory paging diagnostic after r86 no-reset localized the renewed fault to paging_init/map_mem. Keeps the exact r64 post-paging_init PSCI checkpoint Image and changes the DT memory property to a single known V56.6 System RAM bank, 0x90500000..0x9bffffff (187 MiB), containing every observed kexec segment and ending before cont_splash_mem. Automatic reset proves this payload bank maps and identifies another r84 bank or total map workload as the r86 failure; no reset localizes the fault to mapping the kexec payload bank itself. Audited 2026-08-29: exact r64 Image SHA-256 f94392343bc245c572895628c894a720f924a42a30c10f22ab4983ef8bd531b6, exact minimal DTB SHA-256 cc4f6720a84958038295558cbfa80df6c4fec6ee445cfdfa4afd44717f11a186, loader hashes pinned, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    'c61bc155c64a29f3d97fb8f51482a03f18b609cf14f02e34a1b85872abcfca45' = 'V56.6 controlled Linux 6.12 loader r95 transport r2: full 19-range real-RAM paging checkpoint with rodata=on. Keeps the exact r64 post-paging_init PSCI reset checkpoint Image and exact r84 full real-RAM DTB, while changing only the kexec command line from the default full page-granular linear map to ARM64 block mappings. This directly tests the deterministic exhaustion found in the 256-page embedded early page-table pool: r91 passed with 187 MiB, while r92 failed after adding 2 GiB because rodata=full needs at least 1024 PTE pages. Audited 2026-08-30: exact Image SHA-256 f94392343bc245c572895628c894a720f924a42a30c10f22ab4983ef8bd531b6, exact DTB SHA-256 c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae, exactly one rodata=on and no rodata=full, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    '2d47a53f1b43c3fb2ba7ade23e3ce0a295383e08c7e4cdb5fae520ea503173b7' = 'V56.6 controlled Linux 6.12 loader r96 transport r2: full-boot follow-up to r95. Uses the exact r70 layout-preserving Image where the proven post-paging_init PSCI checkpoint was replaced in-place by one AArch64 nop, the exact r84 full 19-range real-RAM DTB, the embedded 1 MiB early page-table pool and exactly one rodata=on command-line argument. This image is allowlisted for use only after r95 proves the full map reaches its checkpoint. Audited 2026-08-30: exact Image SHA-256 9644d29f837f0d52f7b25dcc19a4ea6b495833782810f2e6a933d74dacfd662f, exact DTB SHA-256 c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae, 76 memory cells, no rodata=full, Android boot header, AVB footer and every embedded component verified byte-for-byte; AUDIT_RESULT=PASS.'
    '2b9304b34501dc6c3f1217daa62a56f37a34521c2a36f971fd4363b2c4dc96c2' = 'V56.6 controlled Linux 6.12 loader r98 transport r2: headless full-boot continuation after r96 reached live platform-driver probing but entered a ufshcd-qcom OPP -EPROBE_DEFER storm. Keeps the exact r70 full-boot Image, full 19-range RAM map, embedded 1 MiB page-table pool and exactly one rodata=on. The DT semantic delta from r84 is exactly two status properties: /soc/ufshc@1d84000 and /soc/phy@1d87000 are disabled, matching the safe stage-0 policy; internal Android UFS is neither needed nor accessed. Audited 2026-08-30: Image SHA-256 9644d29f837f0d52f7b25dcc19a4ea6b495833782810f2e6a933d74dacfd662f, DTB SHA-256 ae49070f0e18925de03eb1933a995d7603c9dabb590ef98a097858cb9127c9a7, 76 RAM cells, exact four-line semantic DT diff, boot header, AVB footer, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    'bc916691480b8f943413a236b3cfade587db0499d91f4a834cd608e14c0a9b18' = 'V56.6 controlled Linux 6.12 loader r99 transport r2: headless continuation after r98 removed the UFS storm and exposed a dwc3 a600000 IOMMU group-8 reprobe storm. Keeps the exact r70 full-boot Image, full 19-range RAM map, embedded 1 MiB page-table pool, rodata=on and r98 UFS safety policy. The only DT semantic delta from r98 is /soc/usb@a6f8800 status okay to disabled, deliberately trading USB diagnostics for progress to initramfs/userspace; USB will be repaired separately. Audited 2026-08-30: recovery, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    'e8c1130f2d934b65c39921e26e632357dbe72d4b68ca4cb2ca5aeada841f2a5f' = 'V56.6 controlled Linux 6.12 loader r100 transport r2: persistent-headless follow-up after r99 completed kernel/initramfs boot but 8804000.mmc stayed deferred because RPMh RSC failed -110. Keeps the exact r99 full-boot kernel, full 19-range RAM map, rodata=on, UFS safety policy and USB1-disabled diagnostic policy. The only DT delta from r99 removes power-domains and operating-points-v2 from SDHCI, retaining 25 MHz, four-bit, 3.3-V-only microSD wiring, supplies, GPIOs and redriver. Audited 2026-08-30: recovery, kernel, ramdisk, DTB and recovery_dtbo verified byte-for-byte; AUDIT_RESULT=PASS.'
    'f21938add6495043e5cfcc9bcc13bdcc385aa2637541e251b1434fd9f0a746c1' = 'V56.6 controlled Linux 6.12 loader r101 transport r2: persistent-headless microSD test after r100 proved that removing only SDHCI power-domain and OPP dependencies was insufficient. Keeps the exact r70 full-boot Image, full 19-range RAM map, rodata=on, UFS disabled and USB1 disabled. Removes the remaining RPMh regulator consumer references vmmc-supply/vqmmc-supply from 8804000.mmc so the card keeps the rails inherited from the first-stage 4.19 kernel, and replaces only the RPMh-provided xo clock with the independent 38.4 MHz xo-board fixed clock. Retains 25 MHz, four-bit, no-1.8-V and card-detect/redriver wiring. Audited 2026-08-30: recovery, kernel, ramdisk, DTB, recovery_dtbo, normalized DT semantics and helper hashes verified byte-for-byte; AUDIT_RESULT=PASS.'
    '6a5db342aca363f7dbba3a38dd62da256b1b12e20397706ce9555e50e7e6e6e9' = 'V56.6 controlled Linux 6.12 loader r102 transport r2: exact r101 kernel and headless DTB with one command-line diagnostic delta, fw_devlink=off. r101 still left 8804000.mmc deferred with reason unknown after all direct RPMh SDHCI links had been removed. Disabling automatic firmware supplier gating allows the SDHCI driver either to probe on inherited resources or to expose the exact reset/iface/core clock error instead of the opaque deferred-list entry. UFS and USB1 remain disabled; microSD remains at 25 MHz, four-bit, no-1.8-V with inherited rails and fixed board XO. Audited 2026-08-30: recovery, kernel, ramdisk, DTB, recovery_dtbo, helper hashes and exact one-token command-line delta verified byte-for-byte; AUDIT_RESULT=PASS.'
    '7abed067fa40f4e1b1d53859bcb7cbadccde275988bdaa9176e67cbc4479b825' = 'V56.6 controlled Linux 6.12 loader r104 transport r2: corrected diagnostic successor to r103. The second-stage helper contains exactly one fw_devlink=off token, no fw_devlink=permissive token, and pins the exact r104 inner-initramfs hash. The failure report uses busybox tail and dynamically discovers the real 8804000.mmc sysfs path before printing supplier and consumer links. Exact r70 Image and exact r101 headless DTB are retained; UFS and USB1 remain disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, Image, DTB, recovery_dtbo, helper hash/command line and diagnostic syntax/content verified byte-for-byte; AUDIT_RESULT=PASS.'
    '6145a1ac9d39b1a6d32d3cec7a2ce405e06d809a73e588d6362b42435987f6b2' = 'V56.6 controlled Linux 6.12 loader r105 transport r2: follows r104 hardware evidence that 8804000.mmc had neither driver nor iommu_group and no supplier/consumer links. Removes iommus only from the external microSD controller and masks SDHCI SDMA+ADMA capability bits (0x00480000), forcing the no-IOMMU diagnostic to use PIO. Exact r70 Image is retained; helper contains exactly one fw_devlink=off. UFS and USB1 remain disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, Image, DTB, recovery_dtbo, exact DT safety delta, helper hash/command line and diagnostics verified byte-for-byte; AUDIT_RESULT=PASS.'
    '3332921d39fc8790f11afbd39d3605eefd24cab7f7cdcbc4c500e4c642d07d0e' = 'V56.6 controlled Linux 6.12 loader r106 transport r2: r105 still deferred before any sdhci-msm reset/clock diagnostic, identifying an earlier mmc_of_parse or pinctrl dependency. Keeps no-IOMMU PIO-only microSD safety and removes cd-gpios, pinctrl references and the redriver GPIO consumer from 8804000.mmc, retaining the known-working pin state inherited from the 4.19 first stage. Adds broken-cd polling for removable-card discovery. Exact r70 Image and one fw_devlink=off are retained; UFS/USB1 stay disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, Image, DTB, recovery_dtbo, exact DT safety properties, helper and diagnostics verified byte-for-byte; AUDIT_RESULT=PASS.'
    '1c0af2aacf3d4a197e262850e5952f7e6933af75d6d7edb74af0f91e4491c01c' = 'V56.6 controlled Linux 6.12 loader r107 transport r2: r106 hardware-proven sdhci_msm binding and mmc0 PIO registration are retained. Card-detect and pinctrl consumers remain removed with broken-cd polling, no IOMMU and DMA capability masking. The only functional DT delta restores redriver-power-gpios <&tlmm 75 0>, allowing the patched sdhci-msm driver to enable the external SD signal redriver when the bus powers on. Exact r70 Image and one fw_devlink=off are retained; UFS/USB1 stay disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, Image, DTB, recovery_dtbo, exact DT delta, helper and diagnostics verified byte-for-byte; AUDIT_RESULT=PASS.'
    '9dd91af87b708b963f6103881323f8361cdc955c6f5387dc75fe5b5af99e582e' = 'V56.6 controlled Linux 6.12 loader r108 transport r2: r107 proved the MMC redriver GPIO consumer itself returns EPROBE_DEFER and prevents the r106-proven sdhci_msm bind. Restores the exact dependency-free r106 MMC node, no IOMMU and PIO-only safety, then asserts TLMM GPIO 75 high with a provider-local gpio-hog. This powers the external SD redriver without creating an MMC supplier dependency. Exact r70 Image and one fw_devlink=off are retained; UFS/USB1 stay disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, Image, DTB, recovery_dtbo, exact gpio-hog semantics, helper and diagnostics verified byte-for-byte; AUDIT_RESULT=PASS.'
    'f4b4c9d656079c2e545be73c829d746f1b70d03182029bc6549dd804191d25a3' = 'R119 diagnostic USB-NCM: r118 transport-r2 structure with the Linux 6.12 board DTB replaced by the r119 diagnostic profile. USB1 wrapper stays enabled in peripheral high-speed mode so USB NCM comes up and exposes a remote diagnostic/log channel; DWC3 iommus removed to avoid the r108 IOMMU group-8 storm. UFS disabled, microSD 3.3V/25MHz with native pin states, inherited CXO div2, GPIO75 redriver hog retained. Android partitions never mounted. Built and independently audited 2026-09-19 on the tb371fc-build VM: 39/39 checks passed, AVB NONE footer verified, header geometry byte-identical to stock recovery; AUDIT_RESULT=PASS. Hardware untested.'
    '3335cafcda78a544d765b074b8e8e9ffb051429c49762d083a6b7faa35d7be1e' = 'V56.6 controlled Linux 6.12 loader r109 transport r2: adds a live PC log channel to the hardware-proven r108 MMC PIO and provider-local GPIO 75 redriver-hog baseline. USB1 is restored only in peripheral mode; the DWC3 IOMMU consumer that caused the r98 group-8 reprobe loop is removed, as are role-switch graph dependencies. Existing initramfs NCM rescue is expected at 169.254.77.2:2323 for live dmesg/GPIO/MMC collection. Exact r70 Image and one fw_devlink=off are retained; UFS remains disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, Image, DTB, recovery_dtbo, exact USB/MMC safety semantics, helper and diagnostics verified byte-for-byte; AUDIT_RESULT=PASS.'
    '2e8f098def6659c9fe4d44de55ec4cf61ffa4ff2b545ac2849fab46c82ffae3e' = 'V56.6 controlled Linux 6.12 loader r110 transport r2: exact r109 Image and DTB with diagnostics-only initramfs delta. Since r109 did not enumerate USB on Windows, the final visible block now includes filtered USB/DWC3/PHY/UDC dmesg, UDC/gadget sysfs, DWC3 platform paths and GPIO 75 redriver state; console loglevel is reduced immediately before this block so recurrent SPMI warnings do not erase it. UFS remains disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, Image, exact r109 DTB, recovery_dtbo, helper and diagnostic syntax/markers verified byte-for-byte; AUDIT_RESULT=PASS.'
    'c4d45bb18f0386fcad7601bae338d3ef733effb78331acfbe8edb4004743d490' = 'V56.6 controlled Linux 6.12 loader r111 transport r2: exact r109 Image/DTB with bounded USB diagnostics. r110 never reached its rescue block, identifying a likely stall inside setup-usb-console. The inner init now runs that helper through BusyBox timeout for at most 12 seconds, then continues to the final USB/DWC3/UDC, GPIO 75 and MMC diagnostic block with console noise reduced. UFS remains disabled and Android partitions are never mounted. Audited 2026-08-30: recovery, both ramdisks, exact Image/DTB, recovery_dtbo, bounded init syntax, helper and diagnostic markers verified byte-for-byte; AUDIT_RESULT=PASS.'
    '1fa54ce31d9d9f2c6601be344340c31a6be30ca8cb888a85532e589684b1fb47' = 'V56.6 controlled Linux 6.12 loader r112 transport r2: stable USB1-disabled r108 baseline with one electrical-consistency fix. Live first-stage 4.19 measured ED2S5 microSD, pm8150a_l9=2.950 V and pm8150a_l6 SD-I/O=1.808 V immediately before kexec. Removes only no-1-8-v so 6.12 no longer contradicts the inherited 1.8-V state. PIO-only, 25 MHz, broken-CD, GPIO75 hog, UFS/USB1 disabled and no Android mounts remain. Audited 2026-08-30; AUDIT_RESULT=PASS.'
    '509d77fb54927f3326478d697dce257d4978444a6a7814a552b48913ade7d6ba' = 'V56.6 controlled Linux 6.12 loader r113 transport r2: exact stable r108 second-stage payload with an outgoing-first-stage electrical alignment test. Every real Lenovo 4.19 base-DTB entry limits /soc/sdhci@8804000 qcom,bus-speed-mode to SDR12 and SDR25, preventing the working first stage from leaving the ED2S5 card and SD-I/O rail in SDR104/1.8-V state before kexec. The incoming r108 Linux 6.12 consumer remains PIO-only, 25 MHz and no-1-8-v, with GPIO75 hog, UFS/USB1 disabled and no Android mounts. Recovery DTBO unchanged and contains no SDHCI speed override. Audited 2026-08-30; AUDIT_RESULT=PASS.'
    '00cd7b4f5ca51f5bc9e3bbe1d7584ea92d15d42977bde2133c272a56cca2c64b' = 'V56.6 controlled Linux 6.12 loader r114 transport r2: exact stable r108 Image/DTB hardware baseline with diagnostics-only initramfs delta. Enables runtime MMC/SDHCI dynamic debug when available, records mmc0 ios and actual SDCC2 clock rates, then safely unbinds and rebinds the unused PIO host to expose the first card-command failure. UFS/USB1 remain disabled and Android partitions are never mounted. Audited 2026-08-30; AUDIT_RESULT=PASS.'
    '0a9f7dcf8bb5d5e9d4ec59071e94b90828adb5b6a70960f936590e3c91312368' = 'V56.6 controlled Linux 6.12 loader r115 transport r2: exact stable r108 baseline with a standard mmc-pwrseq-simple provider replacing the always-high GPIO75 hog. Active-low reset pulses the external SD redriver physically low/high before the first identification command, directly addressing r114 CMD8/CMD55 -ETIMEDOUT evidence. PIO, 400-kHz identification, 25-MHz cap, UFS/USB1 disabled and no Android mounts remain. Audited 2026-08-30; AUDIT_RESULT=PASS.'
    '963c7b8e422d20f82b40f47812f8b9419fdcce32390f759d7b68964d89227942' = 'V56.6 controlled Linux 6.12 loader r116 transport r2: exact r108 Image/DTB with diagnostics-only rescue delta. After initial enumeration failure it safely unbinds the empty PIO SDHCI host, pulses only GPIO75 TLMM output bit through verified addresses 0xF14B000/0xF14B004, then rebinds and reports mmcblk enumeration. This bypasses the gpiolib supplier defer proven by r115 while preserving GPIO mux, drive strength, adjacent pins, UFS/USB1 safety and no Android mounts. Audited 2026-08-30; AUDIT_RESULT=PASS.'
    '4c5883aab4c348978ce33615a4803332d1669474176a5652740dbfbdb0addc35' = 'V56.6 controlled Linux 6.12 loader r117 transport r2: exact stable r108 Image/DTB with diagnostics-only rescue delta. It restores the dedicated SDC2 pad-control register at 0xF9B7000 to Lenovo 4.19 active values: CLK no-pull/16 mA and CMD/DATA pull-up/16 mA, preserving all unrelated bits, then rebinds the empty PIO SDHCI host and reports enumeration. This directly tests whether the outgoing 4.19 shutdown leaves SD pins electrically asleep before kexec. UFS/USB1 remain disabled and Android partitions are never mounted. Audited 2026-08-30; AUDIT_RESULT=PASS.'
    '97906e7559918ed31d77765969706b881fb0bea6c31a169d4aab88a1da1060c2' = 'Superseded U-Boot stage-0 v1 with invalid ARM64 text offset'
    '84bb3d7f8ae768e1550539b5b1489495f80ac375f55379cf4ac8c41b5321aa01' = 'Read-only U-Boot stage-0 v3 uncompressed ARM64 Image with 0x80000 text offset'
    'c2620fa4405b4200d5ae6a6767c472dfe4c27d9845b44931668d03691ddc8177' = 'Minimal ABL entry probe with direct inherited-framebuffer checkerboard'
    'c85b6a623fe644ace8eef32aa8826c0510b74bb353b0a29a6b411bcfb0c1bbc1' = 'U-Boot v4 early-boundary probe: red at reset, green at first Qualcomm board callback'
}
$Adb = Join-Path $PlatformToolsDir 'adb.exe'
$Fastboot = Join-Path $PlatformToolsDir 'fastboot.exe'

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$Program,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )

    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

function Get-FastbootVariable {
    param([Parameter(Mandatory = $true)][string]$Name)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Fastboot
    $startInfo.Arguments = "-s $Serial getvar $Name"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Failed to start fastboot getvar $Name"
        }
        $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } finally {
        $process.Dispose()
    }
    if ($exitCode -ne 0) {
        throw "fastboot getvar $Name failed: $output"
    }
    $match = [regex]::Match($output, "(?m)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if (-not $match.Success) {
        throw "Could not parse fastboot variable $Name from: $output"
    }
    return $match.Groups[1].Value.Trim()
}

function Wait-FastbootDevice {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        $lines = @(& $Fastboot devices 2>$null)
        if ($lines | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+fastboot$" }) {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Tablet $Serial did not appear in fastboot within 45 seconds"
}

function Stabilize-FastbootDevice {
    Wait-FastbootDevice
    Invoke-NativeChecked $Fastboot -s $Serial reboot bootloader
    Start-Sleep -Seconds 2
    Wait-FastbootDevice
}

function Get-AdbProperty {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = & $Adb -s $Serial shell getprop $Name
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read Android property $Name"
    }
    return ($value | Out-String).Trim()
}

function Assert-FastbootSafety {
    $slot = Get-FastbootVariable 'current-slot'
    $unlocked = Get-FastbootVariable 'unlocked'
    $recoverySize = Get-FastbootVariable 'partition-size:recovery_b'
    $vbmetaSize = Get-FastbootVariable 'partition-size:vbmeta_b'
    if ($slot -ne 'b' -or $unlocked -ne 'yes') {
        throw "Unsafe fastboot state: current-slot=$slot unlocked=$unlocked"
    }
    if ([Convert]::ToUInt64(($recoverySize -replace '^0x', ''), 16) -ne 100MB) {
        throw "Unexpected recovery_b size: $recoverySize"
    }
    if ([Convert]::ToUInt64(($vbmetaSize -replace '^0x', ''), 16) -ne 64KB) {
        throw "Unexpected vbmeta_b size: $vbmetaSize"
    }
}

function Restore-BootMetadata {
    if ($Paths.ContainsKey('RecoveryRollback')) {
        Write-Host 'Restoring allowlisted development recovery and test vbmeta...'
        Invoke-NativeChecked $Fastboot -s $Serial flash recovery_b $Paths.RecoveryRollback
        Invoke-NativeChecked $Fastboot -s $Serial flash vbmeta_b $Paths.VbmetaTest
        Write-Host 'Development rollback recovery and verification-disabled vbmeta restored.'
        return
    }
    Write-Host 'Restoring recovery_b before re-enabling signed vbmeta_b...'
    Invoke-NativeChecked $Fastboot -s $Serial flash recovery_b $Paths.RecoveryBackup
    Invoke-NativeChecked $Fastboot -s $Serial flash vbmeta_b $Paths.VbmetaBackup
    Write-Host 'Both exact EDL backups were restored.'
}

function Get-DiagnosticUsbDevice {
    # 0104 is ACM, 0105 is NCM, 0106 is the ACM+NCM composite used by the
    # development loader, and 0107 is the autonomous read-only log disk.
    # Match our serial prefix as well as the Linux Foundation VID/PID so an
    # unrelated gadget cannot satisfy the launch observer.
    return @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
        $_.PNPDeviceID -match '^USB\\VID_1D6B&PID_010[4-7].*\\TB371FC-'
    })
}

function Restore-FromFastboot {
    Assert-FastbootSafety
    Restore-BootMetadata
    if ($Paths.ContainsKey('RecoveryRollback')) {
        Invoke-NativeChecked $Fastboot -s $Serial reboot recovery
        Write-Host 'Automatic rollback completed; development recovery boot requested.'
    } else {
        Invoke-NativeChecked $Fastboot -s $Serial reboot
        Write-Host 'Automatic rollback completed; normal Android boot requested.'
    }
}

function Wait-DiagnosticOutcome {
    $deadline = [DateTime]::UtcNow.AddSeconds($BootObserveSeconds)
    Write-Host "Watching USB state for up to $BootObserveSeconds seconds..."
    do {
        $fastbootLine = @(& $Fastboot devices 2>$null) | Where-Object {
            $_ -match "^$([regex]::Escape($Serial))\s+fastboot$"
        }
        if (@($fastbootLine).Count -eq 1) {
            Write-Warning 'Tablet returned to fastboot before Linux USB enumeration.'
            Restore-FromFastboot
            return 'FastbootRollback'
        }

        $diagnosticUsb = @(Get-DiagnosticUsbDevice)
        if ($diagnosticUsb.Count -gt 0) {
            $serialPort = @(Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue | Where-Object {
                $_.PNPDeviceID -match '^USB\\VID_1D6B&PID_010[46]'
            } | Select-Object -First 1)
            Write-Host 'Linux diagnostic USB gadget detected.'
            if ($serialPort.Count -eq 1) {
                Write-Host "  serial console: $($serialPort[0].DeviceID) ($($serialPort[0].Name))"
            } else {
                Write-Warning 'The gadget is present but Windows has not assigned a COM port yet.'
            }
            return 'LinuxUsb'
        }

        $androidLine = @(& $Adb devices 2>$null) | Where-Object {
            $_ -match "^$([regex]::Escape($Serial))\s+device$"
        }
        if (@($androidLine).Count -eq 1) {
            Write-Warning 'Tablet returned to Android without exposing the Linux USB gadget.'
            if ((Get-AdbProperty 'ro.boot.slot_suffix') -ne '_b') {
                throw 'Android returned on an unexpected slot; refusing automatic rollback'
            }
            Invoke-NativeChecked $Adb -s $Serial reboot bootloader
            Wait-FastbootDevice
            Restore-FromFastboot
            return 'AndroidRollback'
        }

        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)

    Write-Warning 'No fastboot, Android, or Linux diagnostic USB device appeared before timeout.'
    Write-Warning 'Do not start another launch. Force the tablet to fastboot, then run -Action Restore.'
    return 'Timeout'
}

foreach ($tool in @($Adb, $Fastboot)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        throw "Required platform tool not found: $tool"
    }
}

foreach ($name in @($Paths.Keys)) {
    $Paths[$name] = (Resolve-Path -LiteralPath $Paths[$name]).Path
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Paths[$name]).Hash.ToLowerInvariant()
    if ($name -in @('RecoveryTest', 'RecoveryRollback')) {
        if (-not $AllowedRecoveryHashes.ContainsKey($actualHash)) {
            throw "$name SHA-256 is not allowlisted: $actualHash"
        }
        $Hashes[$name] = $actualHash
    } elseif ($actualHash -ne $Hashes[$name]) {
        throw "$name SHA-256 mismatch: expected $($Hashes[$name]), got $actualHash"
    }
}
if ((Get-Item $Paths.RecoveryTest).Length -ne 100MB -or
    (Get-Item $Paths.RecoveryBackup).Length -ne 100MB -or
    (Get-Item $Paths.VbmetaTest).Length -ne 64KB -or
    (Get-Item $Paths.VbmetaBackup).Length -ne 64KB) {
    throw 'Pinned artifact size mismatch'
}
if ($Paths.ContainsKey('RecoveryRollback') -and
    (Get-Item $Paths.RecoveryRollback).Length -ne 100MB) {
    throw 'Rollback recovery size mismatch'
}

$sourceVbmeta = [IO.File]::ReadAllBytes($Paths.VbmetaBackup)
$testVbmeta = [IO.File]::ReadAllBytes($Paths.VbmetaTest)
$changedOffsets = @()
for ($i = 0; $i -lt $sourceVbmeta.Length; $i++) {
    if ($sourceVbmeta[$i] -ne $testVbmeta[$i]) {
        $changedOffsets += $i
    }
}
if ($changedOffsets.Count -ne 1 -or $changedOffsets[0] -ne 123 -or $testVbmeta[123] -ne 3) {
    throw "vbmeta patch changes unexpected bytes: $($changedOffsets -join ',')"
}

Write-Host 'Pinned two-partition test artifacts verified.'
Write-Host "  recovery test:   $($Hashes.RecoveryTest)"
Write-Host "  recovery profile: $($AllowedRecoveryHashes[$Hashes.RecoveryTest])"
if ($Hashes.ContainsKey('RecoveryRollback')) {
    Write-Host "  rollback profile: $($AllowedRecoveryHashes[$Hashes.RecoveryRollback])"
}
Write-Host "  recovery backup: $($Hashes.RecoveryBackup)"
Write-Host "  vbmeta test:     $($Hashes.VbmetaTest)"
Write-Host "  vbmeta backup:   $($Hashes.VbmetaBackup)"
Write-Host '  vbmeta diff:     only byte 123, AVB flags 0x0 -> 0x3'

if ($Action -eq 'ValidateOnly') {
    Write-Host 'Validation-only mode: no device query, reboot or write was performed.'
    exit 0
}

if ($Action -in @('Preflight', 'Launch')) {
    $deviceLine = @(& $Adb devices -l) | Where-Object {
        $_ -match "^$([regex]::Escape($Serial))\s+device\s+.*\bdevice:TB371FC\b"
    }
    if (@($deviceLine).Count -ne 1) {
        throw "Expected one authorized TB371FC $Serial in Android"
    }
    $slot = Get-AdbProperty 'ro.boot.slot_suffix'
    $locked = Get-AdbProperty 'ro.boot.flash.locked'
    $bootCompleted = Get-AdbProperty 'sys.boot_completed'
    $batteryText = (& $Adb -s $Serial shell dumpsys battery) | Out-String
    $batteryMatch = [regex]::Match($batteryText, '(?m)^\s*level:\s*(\d+)\s*$')
    if ($slot -ne '_b' -or $locked -ne '0' -or $bootCompleted -ne '1') {
        throw "Unsafe Android state: slot=$slot locked=$locked boot_completed=$bootCompleted"
    }
    if (-not $batteryMatch.Success -or [int]$batteryMatch.Groups[1].Value -lt 50) {
        throw 'Battery level is unavailable or below 50%'
    }
    Write-Host "Android preflight passed: slot B, unlocked, battery $($batteryMatch.Groups[1].Value)%"
    if ($Action -eq 'Preflight') {
        Write-Host 'Preflight-only mode: no reboot and no write were performed.'
        exit 0
    }
}

if ($Action -in @('Launch', 'LaunchFastboot')) {
    if (-not $TwoPartitionWriteApproved) {
        throw 'Launch is gated: separate approval for recovery_b + vbmeta_b is required.'
    }
    if (-not $PSCmdlet.ShouldProcess('TB371FC recovery_b and vbmeta_b', 'Temporarily disable AVB verification and boot diagnostic recovery')) {
        exit 0
    }

    if ($Action -eq 'Launch') {
        Invoke-NativeChecked $Adb -s $Serial reboot bootloader
        Wait-FastbootDevice
    } else {
        Write-Host 'Using the already-running fastboot session; Android preflight was intentionally skipped.'
        Wait-FastbootDevice
    }
    Assert-FastbootSafety
    Invoke-NativeChecked $Fastboot -s $Serial flash recovery_b $Paths.RecoveryTest
    try {
        Invoke-NativeChecked $Fastboot -s $Serial flash vbmeta_b $Paths.VbmetaTest
    } catch {
        Write-Warning 'vbmeta_b write failed; restoring the selected recovery before leaving fastboot.'
        Restore-BootMetadata
        throw
    }
    try {
        Invoke-NativeChecked $Fastboot -s $Serial reboot recovery
    } catch {
        Write-Warning 'Recovery reboot failed; restoring both partitions while fastboot is available.'
        Restore-BootMetadata
        throw
    }
    Write-Host 'Two-partition diagnostic boot requested.'
    $outcome = Wait-DiagnosticOutcome
    if ($outcome -eq 'LinuxUsb') {
        Write-Host 'After collecting logs, return to fastboot and run -Action Restore immediately.'
    } elseif ($outcome -eq 'Timeout') {
        exit 2
    }
    exit 0
}

if (-not $PSCmdlet.ShouldProcess('TB371FC recovery_b and vbmeta_b', 'Restore exact EDL backups')) {
    exit 0
}

$adbLine = @(& $Adb devices) | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+device$" }
if (@($adbLine).Count -eq 1) {
    if ((Get-AdbProperty 'ro.boot.slot_suffix') -ne '_b') {
        throw 'Android did not return on slot B; refusing automatic restore'
    }
    Invoke-NativeChecked $Adb -s $Serial reboot bootloader
}
Stabilize-FastbootDevice
Assert-FastbootSafety
Restore-BootMetadata
if ($Paths.ContainsKey('RecoveryRollback')) {
    Invoke-NativeChecked $Fastboot -s $Serial reboot recovery
    Write-Host 'Development recovery boot requested after rollback.'
} else {
    Invoke-NativeChecked $Fastboot -s $Serial reboot
    Write-Host 'Normal Android boot requested after complete rollback.'
}
