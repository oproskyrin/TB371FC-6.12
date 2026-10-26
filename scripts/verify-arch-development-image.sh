#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 2 )); then
	echo "Usage: $0 DEVELOPMENT_IMAGE CLIENT_PUBLIC_KEY" >&2
	exit 2
fi
[[ $EUID == 0 ]]

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image=$(realpath "$1")
client_key=$(realpath "$2")
image_size=$(stat -c %s "$image")
gib=$((1024 * 1024 * 1024))
(( image_size % gib == 0 ))
(( image_size >= 6 * gib && image_size <= 64 * gib ))
e2fsck -fn "$image" >/dev/null

mount_dir=$(mktemp -d)
virtual_mounts=()
cleanup() {
	for ((i = ${#virtual_mounts[@]} - 1; i >= 0; i--)); do
		mountpoint -q "${virtual_mounts[$i]}" && \
			umount -R "${virtual_mounts[$i]}" 2>/dev/null || true
	done
	mountpoint -q "$mount_dir" && umount "$mount_dir" || true
	rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT

mount -o ro,noload,loop "$image" "$mount_dir"
grep -qx 'schema=2' "$mount_dir/etc/tb371fc-development-image"
grep -qx 'platform=Lenovo TB371FC' "$mount_dir/etc/tb371fc-development-image"
if grep -q '^image_size_bytes=' "$mount_dir/etc/tb371fc-development-image"; then
	grep -qx "image_size_bytes=$image_size" \
		"$mount_dir/etc/tb371fc-development-image"
else
	[[ $image_size == 6442450944 ]]
fi
cmp "$client_key" "$mount_dir/root/.ssh/authorized_keys"
for key in rsa ecdsa ed25519 mldsa44_ed25519; do
	[[ -s $mount_dir/etc/ssh/ssh_host_${key}_key ]]
done
for path in "$mount_dir" "$mount_dir/etc" "$mount_dir/usr"; do
	[[ $(stat -c %a "$path") == 755 ]]
done

if (( image_size >= 12 * gib )); then
	for package in plasma-workspace plasma-desktop kwin konsole qt6-wayland \
		xorg-xwayland networkmanager bluez bluez-utils plasma-nm kscreen \
		plasma-pa xdg-desktop-portal-kde dolphin mesa-utils vulkan-freedreno \
		vulkan-tools pipewire pipewire-pulse wireplumber alsa-utils \
		brightnessctl upower power-profiles-daemon; do
		grep -q "^$package " \
			"$mount_dir/usr/share/tb371fc-development-packages.txt"
	done
	test -x "$mount_dir/usr/local/sbin/start-tb371fc-plasma"
	grep -q 'I_UNDERSTAND_DRM_MODESET' \
		"$mount_dir/usr/local/sbin/start-tb371fc-plasma"
	grep -q '7\.\*-tb371fc\*' \
		"$mount_dir/usr/local/sbin/start-tb371fc-plasma"
	grep -Fq "pgrep -f '/run/tb371fc-rescue/drm-kms-smoketest'" \
		"$mount_dir/usr/local/sbin/start-tb371fc-plasma"
	grep -Fq '/run/tb371fc-enable-legacy-kms-smoke' \
		"$mount_dir/usr/local/sbin/tb371fc-development-init"
	grep -qx 'kernel_release=7.1.8-tb371fc' \
		"$mount_dir/usr/share/tb371fc-development-kernel-modules.txt"
	grep -qx 'archive_sha256=49424881276b661c40cc781ab9ea856e50b018677f8f6e8fd08d90a30c05efcd' \
		"$mount_dir/usr/share/tb371fc-development-kernel-modules.txt"
	grep -qx 'module_files=1510' \
		"$mount_dir/usr/share/tb371fc-development-kernel-modules.txt"
	test -s "$mount_dir/lib/modules/7.1.8-tb371fc/modules.dep"
	for module in \
		kernel/drivers/net/wireless/ath/ath11k/ath11k_pci.ko \
		kernel/drivers/input/touchscreen/nt36523/nt36523_ts.ko \
		kernel/drivers/media/platform/qcom/camss/qcom-camss.ko \
		kernel/drivers/media/i2c/s5k4h7.ko \
		kernel/drivers/net/usb/r8152.ko; do
		test -s "$mount_dir/lib/modules/7.1.8-tb371fc/$module"
	done
fi

mount --rbind /dev "$mount_dir/dev"
mount --make-rslave "$mount_dir/dev"
virtual_mounts+=("$mount_dir/dev")
mount -t proc proc "$mount_dir/proc"
virtual_mounts+=("$mount_dir/proc")

"$repo_dir/scripts/smoke-test-arch-rootfs.sh" "$mount_dir"
chroot "$mount_dir" /usr/bin/sshd -t
chroot "$mount_dir" /usr/bin/ssh-keygen -lf \
	/etc/ssh/ssh_host_ed25519_key.pub

echo "Verified schema-2 ${image_size}-byte development image, SSH identity and ARM64 userspace."
sha256sum "$image"
