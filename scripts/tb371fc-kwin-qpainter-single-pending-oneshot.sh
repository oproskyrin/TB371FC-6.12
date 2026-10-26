#!/bin/sh
# One-shot TB371FC V56.5 diagnostic: use the low-overhead QPainter backend,
# but allow only one pending DRM frame. This isolates stale/out-of-order
# presentation without changing the fragile DSI mode or refresh metadata.

set -u

launcher=/usr/local/bin/kwin_wayland
log=/var/tmp/tb371fc-kwin-qpainter-single-pending-cleanup.log

(
	sleep 600
	if [ -f "$launcher" ] && grep -Fq 'TB371FC V56.5 single-pending diagnostic' "$launcher"; then
		rm -f "$launcher"
		sync
		printf '%s launcher removed; next boot uses stock KWin\n' "$(date -Ins)"
	fi
) </dev/null >>"$log" 2>&1 &

unset KWIN_USE_BUFFER_AGE
export KWIN_COMPOSE=Q
export KWIN_DRM_DISABLE_TRIPLE_BUFFERING=1
exec /usr/bin/kwin_wayland "$@"
