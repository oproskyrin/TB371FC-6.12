#!/bin/sh
# TB371FC V56.5 one-shot diagnostic for the QPainter DRM path.
# Synchronize CPU writes to DRM dumb-buffer dma-bufs before they are scanned
# out. This targets stale rectangular regions during panel/keyboard animation.
# It does not change the display mode, refresh rate, KScreen, or renderer.

set -u

launcher=/usr/local/bin/kwin_wayland
marker='TB371FC V56.5 DRM dumb-buffer CPU-sync one-shot'
log=/var/tmp/tb371fc-kwin-dumbsync-oneshot-cleanup.log

(
	sleep 300
	if [ -f "$launcher" ] && grep -Fq "$marker" "$launcher"; then
		rm -f "$launcher"
		sync
		printf '%s launcher removed; next boot uses stock KWin\n' "$(date -Ins)"
	fi
) </dev/null >>"$log" 2>&1 &

export KWIN_DRM_DUMB_BUFFER_CPU_SYNC=1
export LD_LIBRARY_PATH=/opt/tb371fc-kwin-dumbsync/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /opt/tb371fc-kwin-dumbsync/bin/kwin_wayland "$@"
