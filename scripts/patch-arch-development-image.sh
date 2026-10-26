#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 1 )); then
	echo "Usage: $0 DEVELOPMENT_IMAGE" >&2
	exit 2
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image=$(realpath "$1")
expected_size=6442450944
[[ $(stat -c %s "$image") == "$expected_size" ]] || {
	echo "Refusing unexpected image size: $image" >&2
	exit 1
}

mount_dir=$(mktemp -d)
mounted=0
virtual_mounts=()
cleanup() {
	for ((i = ${#virtual_mounts[@]} - 1; i >= 0; i--)); do
		mountpoint -q "${virtual_mounts[$i]}" && \
			umount -R "${virtual_mounts[$i]}" 2>/dev/null || true
	done
	if (( mounted )) && mountpoint -q "$mount_dir"; then
		sync
		umount "$mount_dir"
	fi
	rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT

mount -o loop,rw "$image" "$mount_dir"
mounted=1
grep -qx 'ID=archarm' "$mount_dir/etc/os-release"
grep -q '^platform=Lenovo TB371FC$' \
	"$mount_dir/etc/tb371fc-development-image"
tune2fs -m 1 "$image" >/dev/null
chmod 0755 "$mount_dir" "$mount_dir/etc" "$mount_dir/usr"
sed -i \
	-e 's/^#DisableSandboxFilesystem/DisableSandboxFilesystem/' \
	-e 's/^#DisableSandboxSyscalls/DisableSandboxSyscalls/' \
	"$mount_dir/etc/pacman.conf"

install -m0755 \
	"$repo_dir/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$mount_dir/usr/local/sbin/tb371fc-development-init"
sed -i 's/^schema=.*/schema=2/' \
	"$mount_dir/etc/tb371fc-development-image"

for virtual_fs in dev proc; do
	if [[ $virtual_fs == proc ]]; then
		mount -t proc proc "$mount_dir/proc"
	else
		mount --rbind /dev "$mount_dir/dev"
		mount --make-rslave "$mount_dir/dev"
	fi
	virtual_mounts+=("$mount_dir/$virtual_fs")
done

rm -f "$mount_dir/etc/ssh/ssh_host_"*
chroot "$mount_dir" /usr/bin/ssh-keygen -A
chroot "$mount_dir" /usr/bin/sshd -t
ls "$mount_dir"/etc/ssh/ssh_host_*_key >/dev/null

for ((i = ${#virtual_mounts[@]} - 1; i >= 0; i--)); do
	umount -R "${virtual_mounts[$i]}"
done
virtual_mounts=()
sync
umount "$mount_dir"
mounted=0
e2fsck -fy "$image" >/dev/null
sha256sum "$image"
