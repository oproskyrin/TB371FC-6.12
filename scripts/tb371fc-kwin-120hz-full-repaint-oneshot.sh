#!/bin/sh
# TB371FC V56.5 one-shot diagnostic. Combine the measured physical 120 Hz
# RenderLoop/commit pacing with a full repaint of every EGL scanout buffer.
# This targets stale rectangular regions seen in IMG_1916.mov. It does not
# change the DRM mode, KScreen, DSI clocks, compositor type, or GL sync mode.

set -u

launcher=/usr/local/bin/kwin_wayland
marker='TB371FC V56.5 120Hz plus full-repaint one-shot'
log=/var/tmp/tb371fc-kwin-120hz-full-repaint-oneshot-cleanup.log

(
	sleep 300
	if [ -f "$launcher" ] && grep -Fq "$marker" "$launcher"; then
		rm -f "$launcher"
		sync
		printf '%s launcher removed; next boot uses stock KWin\n' "$(date -Ins)"
	fi
) </dev/null >>"$log" 2>&1 &

export KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=120000
export KWIN_USE_BUFFER_AGE=0
export LD_LIBRARY_PATH=/opt/tb371fc-kwin-renderloopfix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland "$@"
