#!/bin/sh
# One-shot TB371FC V56.5 diagnostic: force KWin's OpenGL compositor to
# repaint the complete output instead of relying on EGL buffer age.
# The launcher removes itself after ten minutes, so a later reboot returns
# to the stock KWin executable automatically.

set -u

launcher=/usr/local/bin/kwin_wayland
log=/var/tmp/tb371fc-kwin-full-repaint-oneshot-cleanup.log

(
	sleep 600
	if [ -f "$launcher" ] && grep -Fq 'TB371FC V56.5 full-repaint diagnostic' "$launcher"; then
		rm -f "$launcher"
		sync
		printf '%s launcher removed; next boot uses stock KWin\n' "$(date -Ins)"
	fi
) </dev/null >>"$log" 2>&1 &

export KWIN_COMPOSE=O2
export KWIN_USE_BUFFER_AGE=0
exec /usr/bin/kwin_wayland "$@"
