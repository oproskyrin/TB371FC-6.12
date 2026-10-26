# R140: MMCX held by simplefb — visible 6.12 console and KDE Plasma

2026-10-24. Status: HARDWARE SUCCESS. User confirmed the visible console
(photo diagnostics/r140-console-photo-20261024.jpg) and then the visible
KDE Plasma desktop (software QPainter rendering on simpledrm).

## Root cause of the black screen since R131

- R130 showed the login on the panel because RPMh never bound: the votes
  that 4.19 had placed for the display were left untouched.
- R131 let RPMh bind. 6.12 `rpmhpd` clamps every domain to its highest corner
  only until `rpmhpd_sync_state()`; then it votes **0** for every domain with
  no enabled consumer (drivers/pmdomain/qcom/rpmhpd.c:918).
- The cmdline has `fw_devlink=off`, so there are no consumer links and
  sync_state runs right after probe. MMCX dropped to 0 (R131 log:
  `mmcx off-0`), MDSS lost power and the continuous-splash scanout died.
  `pd_ignore_unused` does not help: the 0 vote is sent by rpmhpd itself.
- This explains why R131..R139 were black even with simplefb/simpledrm
  bound (R136): the framebuffer existed, the display controller had no power.

## Change (one variable)

Exact R131 Image/initramfs/DT plus two properties on
`/chosen/framebuffer@9c000000`:

```
power-domains = <&rpmhpd RPMHPD_MMCX>;   /* <0x34 0x06> */
required-opps = <&rpmhpd_opp_nom>;        /* <0x6b>, opp-level 256 */
```

Platform probe attaches the single genpd and applies `required-opps` as the
default performance state (drivers/pmdomain/core.c:2949). The phandles were
checked in the script (rpmhpd compatible, opp6 level 0x100, dispcc uses
MMCX=6). Roundtrip removing both properties gives the exact R131 DT.

| File | SHA256 |
|---|---|
| Image (=R130/R131) | 03b2f15272040962984d70f77356b9686429f0b7024d85ed8fa4150b6129ec61 |
| board.dtb | 8890bca3d2743b0e9348e81cd0b1e77f2efa3307dd05a1d75e0106790aa2b314 |
| initramfs (=R130/R131) | cb68f76732b8c21c6ca8dfec7ca886c006082210fde78ede4da552d2fbcbaa70 |
| r140-payload.tar.gz | bcbed691bdca98040eb898be722ec8ac3ee6f506bdd6e5ebb0fecb077eecda1f |

Build: `scripts/prepare-r140-mmcx-simplefb.sh` (WSL).
Runner: `scripts/test-r121-r140-mmcx-simplefb.sh` (first-stage 4.19).
Serial helper: `scripts/r140-serial-step.ps1 -Step preflight|upload|run`.
Frozen checkpoint: `D:/TB371FC-builds/checkpoints/r140-arch612-mmcx-kde-software-20261024`.

## Hardware run

- How the tablet reached 4.19: an accidental `reboot` (PowerShell stripped
  quotes in a grep pattern; `|reboot` ran on the R130 tablet). A plain
  systemd reboot from 6.12 came back to the first-stage 4.19 console
  (COM9, TB371FC-V56-SSH, boot f480ca66-bcb6-473f-b114-bf6c14fd4fa4).
  It was observed once, not validated as a procedure.
  **Lesson: never pass `|` patterns through PowerShell to ssh; pipe a .sh file.**
- 4.19 boot f480ca66…: payload uploaded over the serial bridge, hashes
  verified on device, kexec executed.
- 6.12 boot **e35b9f45-368b-4aec-aa25-42af3613c1cf**, uname still
  `6.12.30-tb371fc-r130-usb2-late+` (same Image). systemd running, 0 failed.
- Live DT has both properties. `pm_genpd_summary`: `mmcx on 256`, consumer
  `9c000000.framebuffer`. `state_synced=1`, so the vote survives sync_state.
  Other domains (cx, mx, gfx…) are still at 0 from Linux; not needed here.
- simpledrm card0 at 0x9c000000; fbcon 184x57. A marker written to
  /dev/tty1 was read by the user on the panel.
- KDE: service from R132 (`r131-plasma-software.service`, KWIN_COMPOSE=Q,
  QT_QUICK_BACKEND=software) installed under /run as r140-plasma-software.
  Tries 1 and 2 failed: on tty2, the VT was not active (card0 Permission
  denied), then the autovt getty on tty2 hung the session up. The working run
  used **tty7** + `chvt 7`. kwin_wayland (QPainter), ksmserver and plasmashell
  are running; user confirms the KDE desktop is visible.

## Not done / limitations

- No GPU acceleration. Software rendering on 1 CPU (`maxcpus=1 nr_cpus=1`).
- No touch or other input on the tablet yet; the desktop cannot be used.
- msm-mdss still fails -110 (expected: DISPCC/ICC not loaded in R131 base).
- Native DSI/DPU path (R137–R139) is not combined with this DT yet.
  Note: native msm will remove simpledrm, which drops the MMCX vote unless
  MDSS/DPU vote first. The R138/R139 runs had the same MMCX=0 condition
  before display modules loaded; re-evaluate those results with it in mind.
- Changes live in RAM; a reboot loses the Plasma service.

## Next

1. Native DRM path on top of R140: R139 DT + this MMCX fix, GPU node
   `status=disabled` (msm_drv.c add_gpu_components skips unavailable GPU),
   to separate the DPU/DSI hang from Adreno.
2. Adreno: linux-firmware a650_sqe.fw (>=0x95) + a650_gmu.bin, Lenovo-signed
   a650_zap.mbn read from the device vendor partition (read-only).
3. SMP (psci "failed to set PC mode: -3"), touch, Wi-Fi, audio, battery.
