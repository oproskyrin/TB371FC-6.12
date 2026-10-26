# R154–R157: persistent root attempt (failed), SD write problems, stable autoboot R157

2026-10-24. Installed now: recovery_b = R157 (f7cf5491…), vbmeta_b = test; SD folder
`tb371fc-linux/autoboot-6.12-r157`. Power-on → 6.12 with 8 CPUs, touchscreen, keyboard
cover/touchpad, KDE; **no Wi-Fi autostart**. R157 ran 14 min stable before install and
autobooted after flashing (boot 844d4219-8e65-4531-a369-8cf1ec50c176).

## Persistent overlay attempt (R154, not done)

Plan: an ext4 `tb371fc-linux/persist/upper.img` on the microSD as the overlay upper.
Creating it from 6.12 failed every time:
1. R153 (broken-cd, PIO): during the 16 GB exFAT zero-fill "mmc0: card 59b4 removed",
   then I/O errors on the root loop device (the root FS disappeared). The microSD block
   device is also set read-only by the R129 loader (blockdev --setro), lifted only for this.
2. R154t: `non-removable` instead of `broken-cd` → full hang under the same write.
3. R155t: SD DMA restored (iommus <&apps_smmu 0x4a0 0>, no sdhci-caps-mask; "using ADMA
   64-bit" works fine for reads) → full hang under the write.
4. R156t: external qcom-rpmh-regulator.ko + DT keeping only PM8150L LDO9 (card VDD) /
   LDO6 (I/O) at 2.96 V HPM, always-on (vendor sets up to 800 mA load) → regulators came
   up "2960 mV normal", but the 16 GB write still hung the system.
Lead for later: the 4.19 vendor SD driver applies a BayHub (BHT) redriver sequence
("apply bht power off/on patch", power GPIO, "Load BHT patch DS=3"). 6.12 has none of this.
Leftovers: an empty persist/upper.img.partial was removed from 4.19; exFAT now reports
~25 GB used by leaked clusters (38 GB used vs 13 GB) — needs fsck.exfat (exfatprogs),
not yet run. The Arch image itself is intact (4.19 still uses it as root).
Scripts: r154-create-persist.sh, prepare-r154-sd-nonremovable-dt.sh,
prepare-r155-sd-dma-dt.sh, build-r156-rpmh-regulator.sh, package-r15{4,5,6}-test.sh.

## R153 instability → R157

After these tests R153 (installed) hung twice by itself: once idle in KDE, once right
after boot (display on, no input, no ping). R153 is the first build that autostarts
Wi-Fi (PCIe + ath11k); a PCIe/ASPM-related full hang is the main suspect, not proven.
R157 = R140 Image + R153 DTB (touch, keyboard) + R149b initramfs (no Wi-Fi). Stable for
the 14 min test. Wi-Fi can still be started manually with the R151 modules/scripts.
Package `D:/TB371FC-builds/r157-stable`, recovery `…/linux-6.12.30-tb371fc-r157-autoboot-20261024`.
Rollbacks allowlisted: R153 42ea7f50, R150 ddf9eb83, R121 976b4820, stock backups.

## Not verified

Root cause of the R153 hangs; long-run stability of R157 with 8 CPUs and no cpufreq/thermal
(PMIC temps ~34-39 °C at idle); persistent storage on 6.12.
