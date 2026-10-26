#!/bin/sh
# TB371FC V56.5 one-shot diagnostic for the QPainter DRM path.
# Combine the two independently stable fixes already present in the
# /opt/tb371fc-kwin-dumbsync build:
#   1. DMA_BUF_IOCTL_SYNC around CPU writes to DRM dumb buffers.
#   2. KWin RenderLoop/commit pacing matched to measured 120 Hz vblank.
#
# This does not alter the KMS mode, KScreen configuration, DSI clocks,
# framebuffer format, renderer, Mesa, or Plasma. The launcher removes itself
# after five minutes so the following boot automatically uses stock KWin.

set -u

launcher=/usr/local/bin/kwin_wayland
marker='TB371FC V56.5 dumb-buffer CPU-sync plus measured-120Hz one-shot'
log=/var/tmp/tb371fc-kwin-dumbsync-120hz-oneshot-cleanup.log

(
	sleep 300
	if [ -f "$launcher" ] && grep -Fq "$marker" "$launcher"; then
		rm -f "$launcher"
		sync
		printf '%s launcher removed; next boot uses stock KWin\n' "$(date -Ins)"
	fi
) </dev/null >>"$log" 2>&1 &

export KWIN_DRM_DUMB_BUFFER_CPU_SYNC=1
export KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=120000
export LD_LIBRARY_PATH=/opt/tb371fc-kwin-dumbsync/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /opt/tb371fc-kwin-dumbsync/bin/kwin_wayland "$@"
