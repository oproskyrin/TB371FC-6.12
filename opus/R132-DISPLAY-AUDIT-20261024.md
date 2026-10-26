# R131 live graphics test / R132 DISPCC module, 2026-10-24

Current kernel/DT remains confirmed R131 (uname still R130), boot ID
418a77c4-0c50-4fe8-bc10-01de00e63295. No reboot or Android flash this turn.

## Software graphics test: rendered, physical screen BLACK

Current Arch has KWin/Plasma 6.7.4, Mesa 26.1.7 and simpledrm card0 exposing
2944x1840@60, XR24. Created a volatile system service for alarm on tty2, using
PAM/logind and KWIN_COMPOSE=Q, QT_QUICK_BACKEND=software and
LIBGL_ALWAYS_SOFTWARE=1. KWin logs explicitly confirm successful QPainter
initialization. Wayland socket, KWin, plasmashell, ksmserver all appeared.

DRM GETFB2/MAP_DUMB read of the active KWin GEM framebuffer captured KDE
wallpaper and panel: diagnostics/r131-active-scanout-20261024.png.
This is the COMPOSITOR FRAMEBUFFER, NOT proof of physical panel output.
User twice reported black screen, including after VT switch. Raw /dev/fb0
capture instead showed the fbcon shadow buffer, so that earlier PNG is not a
valid capture of current KMS output. No /dev/mem exposed; no raw register or
physical-memory writes attempted to bypass this.

Stopped test service, terminated ONLY the alarm user session created by this
test, switched to tty1 and verified DRM framebuffer returned to [fbcon].
User still reported black after the initial console return; no later physical
confirmation available. All GUI processes are now gone. SSH remains usable.
Do not claim a visible KDE desktop or recovered physical console.

GUI activation also triggered two failed services: upower and
power-profiles-daemon. Journal reports user namespace setup EINVAL / 217 USER.
These failures were NOT reset or hidden. Previously zero-failed boot evidence
remains historically accurate, but current system has these GUI-triggered
failures. A private dbus-run-session bus also caused KDE user-systemd/portal
activation warnings; future session setup should use the normal user bus.

## Missing native display dependencies

Exact R130 config has SM_DISPCC_8250 disabled, INTERCONNECT_QCOM disabled,
BACKLIGHT_CLASS_DEVICE disabled. Panel drivers are gated out. DT already has
lenovo,tb371fc-boe-nt36532 + novatek,nt36523 panel. Its actual initialization
sequence/reset/backlight needs separate validation; fallback compatible alone
does not prove the stock driver matches this panel. GPIO restrictions remain.

Built dispcc-sm8250 as an external module against the existing R130 build,
without changing Image, .config or source. Source/config/Image integrity and
exact vermagic checked; module depends on built-in exported clock helpers.
Package D:/TB371FC-builds/r132-dispcc-module.
SHA256 b23024bbcd7c9a39ac567620fd97450f87a3485bdbb4f90f29fd0ab1334c85fe.

Loaded into running R131 ONLY AFTER stopping GUI. insmod rc=0;
disp_cc-sm8250 bound to af00000.clock-controller, probe returned0 at1032.706s.
USB SSH remained working, same boot ID. This validates controller registration,
not full panel operation or clock transitions under display load.

Manual bounded bind attempt for msm-mdss returned -EPROBE_DEFER at1057.132s.
Clock controller now exists; missing ICC provider is the next strong candidate,
given INTERCONNECT=y but INTERCONNECT_QCOM not set and MDSS requesting mdp0-mem.
Need trace/dev_err_probe instrumentation or provider build to confirm the exact
remaining return path. No interconnect removal/bandwidth bypass performed.
Module left loaded for further diagnostics; it is NOT in boot initramfs.

## Evidence and next steps

diagnostics/r131-display-audit-20261024.log,
r131-gui-preflight-20261024.log, r131-plasma-start-20261024.log,
r131-plasma-status-20261024.log, r131-compositor-state-20261024.log,
r131-gui-cleanup-20261024.log, r132-dispcc-live-test-20261024.log,
r132-mdss-reprobe-20261024.log, r132-logs-only-20261024.tar.gz.

Next: prepare Qualcomm ICC/RPMh provider dependencies against exact kernel,
then validate native MDSS and panel reset/backlight with GPIO safeguards.
Do not enable all GPIOs or replace working R130/R131 checkpoints blindly.
For GUI retry, correct user-bus integration and namespace compatibility too.

Primary sources checked:
- https://raw.githubusercontent.com/KDE/kwin/v6.7.4/src/backends/drm/drm_backend.cpp
  (supports QPainter backend)
- https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux.git/+/9621c81fd2eb7db4b647814b7b6e537744831e60/drivers/clk/qcom/dispcc-sm8250.c
- local exact R118 kernel drivers/gpu/drm/msm/msm_mdss.c,
  drivers/gpu/drm/tiny/simpledrm.c, drivers/gpu/drm/drm_format_helper.c.
