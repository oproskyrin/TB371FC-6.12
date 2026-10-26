#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 1 )); then
	echo "Usage: $0 DEVELOPMENT_INITRAMFS" >&2
	exit 2
fi

image=$(realpath "$1")
stage=$(mktemp -d)
new_root=$(mktemp -d)
listener_pid=
cleanup() {
	[[ -z $listener_pid ]] || kill "$listener_pid" 2>/dev/null || true
	rm -rf -- "$stage" "$new_root"
}
trap cleanup EXIT

(
	cd "$stage"
	gzip -dc "$image" | cpio -idmu 2>/dev/null
)
mkdir -p "$new_root/run/tb371fc-rescue"
cp "$stage/bin/busybox" "$new_root/run/tb371fc-rescue/busybox"
ln -s busybox "$new_root/run/tb371fc-rescue/sh"

port=32471
if ss -ltn "sport = :$port" | grep -q LISTEN; then
	echo "Refusing occupied test port: $port" >&2
	exit 1
fi

qemu-aarch64-static "$stage/bin/busybox" chroot "$new_root" \
	/run/tb371fc-rescue/busybox nc -l -p "$port" \
	-e /run/tb371fc-rescue/sh >"$stage/listener.out" \
	2>"$stage/listener.err" &
listener_pid=$!

response=
for _ in $(seq 1 20); do
	response=$(printf 'echo TB371FC_CHROOT_RESCUE_OK; exit\n' | \
		timeout 2 nc 127.0.0.1 "$port" 2>/dev/null || true)
	[[ $response == *TB371FC_CHROOT_RESCUE_OK* ]] && break
	kill -0 "$listener_pid" 2>/dev/null || {
		cat "$stage/listener.err" >&2
		exit 1
	}
	sleep 0.2
done
[[ $response == *TB371FC_CHROOT_RESCUE_OK* ]]
wait "$listener_pid"
listener_pid=

echo 'Verified a real ARM64 BusyBox rescue command through chroot and TCP.'
