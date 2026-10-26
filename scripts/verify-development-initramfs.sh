#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
	echo "Usage: $0 DEVELOPMENT_INITRAMFS [BASELINE_INITRAMFS]" >&2
	exit 2
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image=$(realpath "$1")
stage=$(mktemp -d)
baseline_stage=
cleanup() {
	rm -rf -- "$stage"
	[[ -z $baseline_stage ]] || rm -rf -- "$baseline_stage"
}
trap cleanup EXIT

extract() {
	local archive=$1 destination=$2
	(
		cd "$destination"
		gzip -dc "$archive" | cpio -idmu 2>/dev/null
	)
}

extract "$image" "$stage"
cmp "$repo_dir/initramfs/init-development" "$stage/init"
cmp "$repo_dir/initramfs/setup-usb-console" "$stage/bin/setup-usb-console"
cmp "$repo_dir/initramfs/boot-arch-development-rootfs" \
	"$stage/bin/boot-arch-development-rootfs"
cmp "$repo_dir/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$stage/bin/tb371fc-development-init-runtime"

for link in chroot ip nc ln switch_root; do
	[[ $(readlink "$stage/bin/$link") == busybox ]]
done
for file in init bin/busybox bin/setup-usb-console \
	bin/boot-arch-development-rootfs bin/tb371fc-development-init-runtime \
	bin/return-to-bootloader; do
	[[ -x $stage/$file ]]
done

qemu-aarch64-static "$stage/bin/busybox" sh -n "$stage/init"
qemu-aarch64-static "$stage/bin/busybox" sh -n \
	"$stage/bin/boot-arch-development-rootfs"
qemu-aarch64-static "$stage/bin/busybox" sh -n \
	"$stage/bin/tb371fc-development-init-runtime"
grep -Fq 'ip addr add 169.254.77.2/16 dev usb0' "$stage/init"
grep -Fq "grep -q 'inet 169.254.77.2/'" "$stage/init"
grep -Fq 'frame\ buffer*) echo 1 >"$vtconsole/bind"' "$stage/init"
grep -Fq 'echo 0 >/sys/class/graphics/fb0/blank' "$stage/init"
grep -Fq "echo '===== framebuffer-fingerprint ====='" "$stage/init"
grep -Fq 'dd if=/dev/fb0 bs=4096 count=5290' "$stage/init"
grep -Fq "echo '===== display-memory-map ====='" "$stage/init"
grep -Fq '/sys/kernel/debug/dri/*/state' "$stage/init"
grep -Fq 'nc -lk -p 2323' "$stage/init"
grep -Fq 'seq 1 60' "$stage/init"
grep -Fq "show_status 'kernel started; preparing USB rescue and Arch root'" \
	"$stage/init"
grep -Fq "mknod -m 620 /dev/tty0 c 4 0" "$stage/init"
grep -Fq "mknod -m 600 /dev/fb0 c 29 0" "$stage/init"
grep -Fq "mount -t tmpfs -o mode=0755,nosuid tmpfs /dev" "$stage/init"
grep -Fq "mknod -m 600 /dev/console c 5 1" "$stage/init"
if [[ -e $stage/bin/drm-kms-smoketest ]]; then
	file "$stage/bin/drm-kms-smoketest" | \
		grep -q 'ARM aarch64.*statically linked'
	grep -Fq 'cp /bin/drm-kms-smoketest /run/tb371fc-rescue/drm-kms-smoketest' \
		"$stage/bin/boot-arch-development-rootfs"
	grep -Fq 'mknod -m 660 /dev/dri/card0 c 226 0' \
		"$stage/bin/tb371fc-development-init-runtime"
	grep -Fq '/run/tb371fc-rescue/drm-kms-smoketest' \
		"$stage/bin/tb371fc-development-init-runtime"
	grep -Fq 'drm-kms-smoketest 120 red 86400' \
		"$stage/bin/tb371fc-development-init-runtime"
fi
grep -Fq '02:37:1f:c0:00:02' "$stage/bin/setup-usb-console"
grep -Fq '02:37:1f:c0:00:01' "$stage/bin/setup-usb-console"
grep -Fq 'echo usb0 >/run/tb371fc-usb-netdev' \
	"$stage/bin/setup-usb-console"
grep -Fq '/run/tb371fc-rescue/busybox sh' \
	"$stage/bin/boot-arch-development-rootfs"
grep -Fq 'chroot "$new_root" /run/tb371fc-rescue/busybox nc' \
	"$stage/bin/boot-arch-development-rootfs"
grep -Fq 'nc -lk -p 2324' "$stage/bin/boot-arch-development-rootfs"
grep -Fq 'tb371fc-transition-shell.pid' \
	"$stage/bin/tb371fc-development-init-runtime"
grep -Fq '"$bb" ip addr add 169.254.77.2/16 dev "$netdev"' \
	"$stage/bin/tb371fc-development-init-runtime"
grep -Fq 'TB371FC Arch Linux development laboratory' \
	"$stage/bin/tb371fc-development-init-runtime"
grep -Fq '/run/tb371fc-enable-legacy-kms-smoke' \
	"$stage/bin/tb371fc-development-init-runtime"

run_move_line=$(grep -nF 'mount --move /run "$new_root/run"' \
	"$stage/bin/boot-arch-development-rootfs" | cut -d: -f1)
chroot_listener_line=$(grep -nF 'chroot "$new_root" /run/tb371fc-rescue/busybox nc' \
	"$stage/bin/boot-arch-development-rootfs" | cut -d: -f1)
dev_move_line=$(grep -nF 'mount --move /dev "$new_root/dev"' \
	"$stage/bin/boot-arch-development-rootfs" | cut -d: -f1)
switch_root_line=$(grep -nF 'exec switch_root "$new_root"' \
	"$stage/bin/boot-arch-development-rootfs" | cut -d: -f1)
(( run_move_line < chroot_listener_line ))
(( chroot_listener_line < dev_move_line ))
(( dev_move_line < switch_root_line ))

qemu-aarch64-static "$stage/bin/busybox" --list >"$stage/busybox.applets"
for applet in chroot ifconfig ip nc sh switch_root; do
	grep -Fxq "$applet" "$stage/busybox.applets"
done
rm -f "$stage/busybox.applets"

if (( $# == 2 )); then
	baseline=$(realpath "$2")
	baseline_stage=$(mktemp -d)
	extract "$baseline" "$baseline_stage"
	echo 'Changed paths relative to baseline:'
	diff -qr "$baseline_stage" "$stage" || true
fi

echo 'Verified development initramfs entrypoint, applets and shell syntax.'
sha256sum "$image"
