# R183: GPU acceleration while preserving the working R178 desktop

User requests acceleration without breaking the current features. Baseline
survey: boot b9d901d9-7e06-4545-abe3-0398f7a28578, kernel r159-audio built
2026-10-25 19:38, persistent ext4 root /dev/mmcblk0p2 RW. KDE/QPainter on
simpledrm card0; touch/audio/Wi-Fi/BT/SD and 8 CPUs provided by Claude's R178.
Do not apply the old handoff's RO-only/R130 assumptions to this system.

Baseline has no render node. Installed packages: kwin6.7.4-5, Mesa26.1.7-1,
libdrm2.4.134-1. Existing upgraded A650 firmware hashes:
SQE c863ceac3a823af215205d7803776bfdc68098c2c2a5d2fd05b4aa77cd336b4b,
GMU df79fa8482fcc7587bb239b9c9e2b24bce4729893b990fe3f82b30da8175b01c.

Saved baseline service/config/DT/packages/logs on host:
D:/TB371FC-builds/r183-acceleration/r183-baseline.tar.gz
SHA256 e04b8d798db64b40e075751dd7da4278168f88454bc4708cff09276217a19d12.
No secrets/network profiles included in that snapshot. Frozen R178 payload
and installed recovery/autoboot remain the fallback.

Read Claude's R179 and R180-R182 reports: GPU enumeration reported FD650, but
KWin on headless GPU + simpledrm produced black/stale images/pageflip timeout.
Native DPU/DSC currently correct only on left half. R139 firmware warning
is not the current GPU blocker: new firmware already installed.

Investigation uses official KWin v6.7.4 source, commit
8438567a741826da8b7536a8b10eb3af8fc8820d, isolated at
D:/TB371FC-builds/r183-acceleration/kwin-6.7.4.
drm_egl_layer_surface.cpp includes GPU->CPU dumb-buffer fallback. Therefore
native DSI completion may not be required for useful GPU compositing; this
remains a hypothesis to test. No KWin source/binary change yet.

Test plan: clean reboot to first-stage, hold autoboot, RAM boot existing
R179 payload with headless GPU and software desktop; test rendering separately,
then inspect/correct presentation with a timed software-desktop rollback.
Do not replace installed recovery or persistent boot payload with experiments.

2026-10-25: clean systemctl reboot issued, first-stage4.19 held remotely.
R179 payload transferred to RAM. Hardware acceleration outcome still pending.

## Actual rendering failure (not merely presentation)

RAM R179 boot 4078634b-0b85-4c96-9c6e-bf645ec38ad2 kept the software
desktop working. EGL enumeration reported FD650, but this is NOT proof of
correct rendering. Timed KWin GPU test with KWIN_DRM_FORCE_GL_FINISH_PRESENT=1
triggered CP opcode errors, GPU resets, GL_CONTEXT_LOST. Immediately restored
QPainter using scripts/r183-software-rollback.sh and cancelled rollback timer.
No persistent GPU desktop override or installed boot payload was changed.

Logs saved to D:/TB371FC-builds/r183-acceleration/r183-test-logs.tar.gz.
An independent Python ctypes EGL/GLES offscreen test (scripts/r183-egl-smoke.py)
also fails: expected red pixel (255,0,0,255), got (0,0,0,0). Kernel reports
SMMU READ TRANSLATION faults at userspace IB address 0x10040a000, CP opcode0,
status00800005. Investigate page-table translation/coherency before KWin.

Next RAM-only diagnostic removes dma-coherent ONLY from GPU SMMU DT node
/soc@0/iommu@3da0000; all other payload bytes preserved from R179.
Hypothesis, not a proven fix. scripts/build-r183-noncoherent.sh + r183-test.sh.
DT SHA256 304d273c4af29468b6b1f62efc71bf2e39142663fbf3935ce2abf0b33ddd4073.
Autoboot/recovery remain R178. Clean reboot and serial hold succeeded.
