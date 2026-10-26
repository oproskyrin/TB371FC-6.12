#!/bin/sh
# R185: GPU (Adreno 650, freedreno) compositing for KWin when the headless GPU is present.
# KWin renders on the msm render node and presents on simpledrm. Without the render node (older
# payloads) or with /var/lib/tb371fc/gpu-disabled the base unit keeps QPainter software rendering.
out=/run/tb371fc-gpu.env
rm -f "$out"
[ -f /var/lib/tb371fc/gpu-disabled ] && { echo "tb371fc-gpu: disabled by marker"; exit 0; }
[ -e /dev/dri/by-path/platform-msm-render ] && [ -e /dev/dri/by-path/platform-msm-card ] || { echo "tb371fc-gpu: no Adreno render node, software rendering"; exit 0; }
cat > "$out" <<ENV
KWIN_COMPOSE=O2
LIBGL_ALWAYS_SOFTWARE=0
QT_QUICK_BACKEND=
KWIN_DRM_DEVICES=/dev/dri/by-path/platform-msm-card:/dev/dri/by-path/platform-9c000000.framebuffer-card
KWIN_DRM_FORCE_GL_FINISH_PRESENT=1
ENV
echo "tb371fc-gpu: Adreno compositing enabled"
