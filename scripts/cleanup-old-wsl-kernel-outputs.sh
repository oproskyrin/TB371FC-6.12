#!/usr/bin/env bash
# Remove only superseded, reproducible kernel object trees from /root.
set -euo pipefail

[[ ${1:-} == I_UNDERSTAND_REPRODUCIBLE_OUTPUTS_ARE_REMOVED ]] || {
	echo 'Explicit cleanup confirmation is required.' >&2
	exit 2
}

keep=/root/tb371fc-linux-7.1.8-clean-out
targets=(
	linux-mainline-out
	linux-stable-7.1-out
	tb371fc-desktop-working-out
	tb371fc-lenovo-4.19-out
	tb371fc-lenovo-4.19-v18-trace-out
	tb371fc-lenovo-4.19-v24-pps-trace-out
	tb371fc-lenovo-4.19-v25-dual-ktz8866-out
	tb371fc-lenovo-4.19-v26-dual-dsi-tpg-out
	tb371fc-lenovo-4.19-v27-idempotent-dsc-pps-out
	tb371fc-lenovo-4.19-v28-pre-on-dsc-pps-out
	tb371fc-lenovo-4.19-v29-kexec-bridge-out
	tb371fc-lenovo-4.19-v32-nt36532-vendor-dsc-out
	tb371fc-lenovo-4.19-v33-per-link-dsc-pps-out
	tb371fc-lenovo-4.19-v34-pre-on-pps-only-out
	tb371fc-lenovo-4.19-v35-panel-status-read-out
	tb371fc-lenovo-4.19-v36-cont-splash-dual-flush-out
	tb371fc-lenovo-4.19-v38-splash-stock-pps-out
	tb371fc-lenovo-4.19-v39-stock-post-on-out
	tb371fc-lenovo-4.19-v40-frame-boundary-out
	tb371fc-lenovo-4.19-v41-splash-state-out
	tb371fc-linux-7.1-out
	tb371fc-linux-7.1.7-display-test-out
	tb371fc-linux-7.1.7-full-panel-verify-out
	tb371fc-linux-7.1.7-longwrite-repro-out
	tb371fc-linux-7.1.8-out
	tb371fc-out
)

before=$(df -B1 --output=avail / | tail -1)
for name in "${targets[@]}"; do
	case "$name" in *-out) ;; *) echo "Unsafe name: $name" >&2; exit 3;; esac
	path=/root/$name
	[[ $path != "$keep" ]] || { echo "Refusing to remove current output" >&2; exit 4; }
	[[ ! -L $path ]] || { echo "Refusing symlink target: $path" >&2; exit 5; }
	if [[ -d $path ]]; then
		du -sh "$path"
		rm -rf -- "$path"
	fi
done
sync
after=$(df -B1 --output=avail / | tail -1)
echo "Reclaimed inside WSL: $((after - before)) bytes"
echo "Preserved current output: $keep"
