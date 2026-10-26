#!/bin/sh
# One-shot TB371FC V56.5 diagnostic: compare KWin's QPainter compositor with
# the stable llvmpipe OpenGL baseline without changing the DRM output mode.
# The launcher removes itself after five minutes so the next complete boot
# automatically returns to /usr/bin/kwin_wayland.

set -u

launcher=/usr/local/bin/kwin_wayland
log=/var/tmp/tb371fc-kwin-qpainter-oneshot-cleanup.log

(
	sleep 300
	if [ -f "$launcher" ] && grep -Fq 'TB371FC V56.5 diagnostic' "$launcher"; then
		rm -f "$launcher"
		sync
		printf '%s launcher removed; next boot uses stock KWin\n' "$(date -Ins)"
	fi
) </dev/null >>"$log" 2>&1 &

export KWIN_COMPOSE=Q
exec /usr/bin/kwin_wayland "$@"
