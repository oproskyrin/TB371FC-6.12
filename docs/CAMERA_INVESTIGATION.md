# R192–R194: camera bring-up attempts, hardware watchdog (2026-10-26)

## R193: hardware watchdog (persistent root, no payload change)

* `CONFIG_WATCHDOG` was off. Watchdog core + `qcom-wdt` built as modules for the R191 kernel
  (Module.symvers unchanged), loaded by `tb371fc-watchdog.service` (before sysinit), systemd
  `RuntimeWatchdogSec=30s`, `RebootWatchdogSec=2min` (`system.conf.d/tb371fc-watchdog.conf`).
* Verified: `echo c > /proc/sysrq-trigger` → automatic reset → bootloader → recovery_b console →
  autoboot of the flashed release, back on SSH after ~2.5 min. Every hang since then recovered alone.
* Persistent journal (`journald.conf.d/tb371fc-journal.conf`, 200 MB) to read hung boots.

## R192: rear camera test DT + modules

* Modules for R191 (no CRC change): camcc-sm8250, i2c-qcom-cci, qcom-camss, qcom-rpmh-regulator,
  v4l2-cci, s5k4h7 (project driver; `devm_v4l2_sensor_clk_get` → `devm_clk_get` for 6.12).
* DT (531e8267): camcc, CAMSS CSIPHY0, CCI0 bus 0 @0x10 S5K4H7, reset GPIO93, MCLK0 GPIO94; sensor rails
  = real RPMh LDOs (L13A 2.8 V, L3C 1.2 V, L5C 1.8 V); CAMSS PHY rails fixed stand-ins.
* `qcom-rpmh-regulator` loads fine (Wi-Fi/USB/display unaffected).
* `camcc-sm8250` hangs the system at probe (first CAM_CC register access).

## R194: why CAM_CC is unreachable

* Read-only peek module (`scripts/r194-campeek/`): reads of CAM_CC (0x0ad00000) and DISP_CC
  (0x0af00000) give `synchronous external abort` (ESR 0x96000010) without the Qualcomm interconnect
  driver (`CONFIG_INTERCONNECT_QCOM` is off in this kernel).
* With interconnect modules (interconnect_qcom, icc-bcm-voter, icc-rpmh, qnoc-sm8250; `build-r194-icc.sh`)
  DISP_CC becomes readable (0xd9000005) — CN0 needs the bcm voter. CAM_CC reads then stall instead.
* GCC camera branches: AHB (0xb008) and camera XO (0xb040) on; `gcc_camera_hf_axi_clk` /
  `gcc_camera_sf_axi_clk` fail to enable (-EBUSY, stuck off) → the camera power island is off.
* Same in the stock 4.19 recovery console: GCC 0xb000-0xb05c identical, CAM_CC read aborts
  (`r194-peek-419.sh`). The recovery kernel never powers the camera subsystem.
* Open question: what powers the camera island on SM8250 before CAM_CC is accessible (candidates:
  MMNOC TBU GDSCs `hlos1_vote_mmnoc_mmu_tbu_*` off in pm_genpd, MX level 48, an AOP/QMP request).
  Upstream RB5 boots with the camera island already up via its bootloader.

## R195–R196: what does NOT make CAM_CC reachable

All with the interconnect modules loaded (DISP_CC readable):

| Attempt | Result |
|---|---|
| GCC_MMSS_BCR (0xb000) | 0 = not in reset |
| GCC camera AHB 0xb008 / XO 0xb040 | already on |
| `tb371fc,camvote` DT consumer: RPMh MX and MMCX at 256 (nom) | CAM_CC read still stalls |
| + GCC hlos1_vote_mmnoc_mmu_tbu_hf0/hf1/sf0/sf1 GDSCs on | system hangs ~2 s later (SMMU TBUs) |
| icc test_client qnm_camnoc_hf → ebi (MMNOC BCMs on) | camera hf/sf AXI branches still "stuck at off" |
| GCC QMIP camera nrt/rt + video cvp/vcodec AHB on | CAM_CC read still stalls |

* VIDEO_CC (0x0abf0000) stalls exactly like CAM_CC; only DISP_CC (display kept alive by the
  bootloader splash) answers. Camera and video islands are both unreachable after the
  ABL → recovery_b (4.19) → kexec path, already in the stock 4.19 console.
* Next ideas: the state Android's normal boot leaves (needs root in Android), XPU/TZ protection of
  the CAMSS/VENUS config spaces in recovery mode, an AOP/QMP request, or a different boot path.
| CX + MX + MMCX all at 256 (R197 camvote) | CAM_CC read still stalls |
