#!/bin/sh
# TB371FC V56.5 one-shot diagnostic. The physical panel vblank was measured at
# 120 Hz, while the vendor mode transport clock makes KWin report 52.539 Hz.
# Override only KWin RenderLoop and DRM commit pacing. Do not alter the KMS
# mode, KScreen output selection, DSI clocks, or the framebuffer format.

set -u

launcher=/usr/local/bin/kwin_wayland
marker='TB371FC V56.5 measured-120Hz RenderLoop one-shot'
log=/var/tmp/tb371fc-kwin-renderloop-120hz-oneshot-cleanup.log

(
	sleep 300
	if [ -f "$launcher" ] && grep -Fq "$marker" "$launcher"; then
		rm -f "$launcher"
		sync
		printf '%s launcher removed; next boot uses stock KWin\n' "$(date -Ins)"
	fi
) </dev/null >>"$log" 2>&1 &

export KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=120000
export LD_LIBRARY_PATH=/opt/tb371fc-kwin-renderloopfix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland "$@"
