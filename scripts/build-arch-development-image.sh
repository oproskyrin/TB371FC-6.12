#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 7 )); then
	cat >&2 <<'EOF'
Usage: build-arch-development-image.sh SOURCE_IMAGE OUTPUT_IMAGE CLIENT_PUBLIC_KEY FIRMWARE_INITRAMFS QRTR_NS QRTR_LOOKUP REBOOT_MODULE

Builds a persistent Arch Linux ARM ext4 development image offline. The
default remains 6 GiB; set DEV_IMAGE_SIZE_GIB=12 for the Plasma development
root and optionally set EXTRA_PACKAGES_FILE to another package manifest.
Set KERNEL_MODULES_ARCHIVE to a trusted modules-*.tar.gz release archive to
stage a future kernel without loading any module automatically.
No tablet or removable storage is accessed.
EOF
	exit 2
fi
[[ $EUID -eq 0 ]] || {
	echo 'Run as root to preserve ownership and mount the ext4 image.' >&2
	exit 1
}

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_image=$(realpath "$1")
output_image=$(realpath -m "$2")
client_key=$(realpath "$3")
firmware_initramfs=$(realpath "$4")
qrtr_ns=$(realpath "$5")
qrtr_lookup=$(realpath "$6")
reboot_module=$(realpath "$7")
packages="$repo_dir/rootfs/packages-development.txt"
overlay="$repo_dir/rootfs/development-overlay"
target_size_gib=${DEV_IMAGE_SIZE_GIB:-6}
extra_packages=${EXTRA_PACKAGES_FILE:-}
kernel_modules_archive=${KERNEL_MODULES_ARCHIVE:-}

case "$target_size_gib" in
	''|*[!0-9]*) echo 'DEV_IMAGE_SIZE_GIB must be an integer.' >&2; exit 1 ;;
esac
(( target_size_gib >= 6 && target_size_gib <= 64 )) || {
	echo 'DEV_IMAGE_SIZE_GIB must be between 6 and 64.' >&2
	exit 1
}
target_size_bytes=$((target_size_gib * 1024 * 1024 * 1024))
source_size_bytes=$(stat -c %s "$source_image")
(( target_size_bytes >= source_size_bytes )) || {
	echo 'The target image cannot be smaller than SOURCE_IMAGE.' >&2
	exit 1
}
if [[ -n $extra_packages ]]; then
	extra_packages=$(realpath "$extra_packages")
	[[ -s $extra_packages ]] || { echo 'EXTRA_PACKAGES_FILE is empty.' >&2; exit 1; }
fi
if [[ -n $kernel_modules_archive ]]; then
	kernel_modules_archive=$(realpath "$kernel_modules_archive")
	[[ -s $kernel_modules_archive ]] || {
		echo 'KERNEL_MODULES_ARCHIVE is empty.' >&2
		exit 1
	}
	mapfile -t module_archive_entries < <(tar -tzf "$kernel_modules_archive")
	((${#module_archive_entries[@]} > 1000)) || {
		echo 'KERNEL_MODULES_ARCHIVE has too few entries.' >&2
		exit 1
	}
	for entry in "${module_archive_entries[@]}"; do
		[[ $entry == lib/modules/* && $entry != *'../'* ]] || {
			echo "Unsafe module archive entry: $entry" >&2
			exit 1
		}
	done
	mapfile -t staged_kernel_releases < <(printf '%s\n' \
		"${module_archive_entries[@]}" | sed -n 's#^lib/modules/\([^/]*\)/.*#\1#p' | sort -u)
	((${#staged_kernel_releases[@]} == 1)) || {
		echo 'KERNEL_MODULES_ARCHIVE must contain exactly one kernel release.' >&2
		exit 1
	}
fi

resume_existing=${RESUME_EXISTING:-0}
if [[ -e $output_image ]]; then
	[[ $resume_existing == 1 ]] || {
		echo "Refusing to overwrite existing output: $output_image" >&2
		exit 1
	}
	[[ $(stat -c %s "$output_image") == "$target_size_bytes" ]] || {
		echo "Existing resume image is not exactly $target_size_gib GiB." >&2
		exit 1
	}
else
	[[ $resume_existing == 0 ]] || {
		echo 'RESUME_EXISTING=1 was set but the output image does not exist.' >&2
		exit 1
	}
fi
[[ $source_size_bytes == 6442450944 ]] || {
	echo 'SOURCE_IMAGE must be the verified 6 GiB development baseline.' >&2
	exit 1
}
grep -Eq '^ssh-ed25519 [A-Za-z0-9+/]+={0,3}( |$)' "$client_key" || {
	echo 'CLIENT_PUBLIC_KEY must contain an Ed25519 OpenSSH public key.' >&2
	exit 1
}
for binary in "$qrtr_ns" "$qrtr_lookup"; do
	file "$binary" | grep -q 'ELF 64-bit.*ARM aarch64.*statically linked' || {
		echo "Not a static AArch64 executable: $binary" >&2
		exit 1
	}
done
[[ -s $reboot_module ]] || { echo 'Missing reboot module.' >&2; exit 1; }
gzip -t "$firmware_initramfs"

mkdir -p "$(dirname "$output_image")"
if [[ $resume_existing == 0 ]]; then
	cp --reflink=auto --sparse=always "$source_image" "$output_image"
	if (( target_size_bytes > source_size_bytes )); then
		truncate -s "$target_size_bytes" "$output_image"
		e2fsck -fy "$output_image" >/dev/null
		resize2fs "$output_image" >/dev/null
	fi
	tune2fs -L TB371FC_ARCH_DEV "$output_image" >/dev/null
	# This is a dedicated removable-media development root rather than
	# a multi-user server filesystem.  One percent still leaves an emergency
	# reserve while recovering roughly 240 MiB for Plasma and build tools.
	tune2fs -m 1 "$output_image" >/dev/null
fi

mount_dir=$(mktemp -d)
firmware_stage=$(mktemp -d)
mounted=0
virtual_mounts=()
detach_output_loops() {
	local loop_device
	while IFS=: read -r loop_device _; do
		[[ -n $loop_device ]] || continue
		if ! findmnt -rn -S "$loop_device" | grep -q .; then
			losetup -d "$loop_device" 2>/dev/null || true
		fi
	done < <(losetup -j "$output_image")
}
cleanup() {
	set +e
	for ((index = ${#virtual_mounts[@]} - 1; index >= 0; index--)); do
		if mountpoint -q "${virtual_mounts[$index]}"; then
			umount -R "${virtual_mounts[$index]}" 2>/dev/null || \
				umount -R -l "${virtual_mounts[$index]}"
		fi
	done
	if (( mounted == 1 )); then
		umount "$mount_dir" 2>/dev/null || umount -l "$mount_dir"
	fi
	detach_output_loops
	if findmnt -R "$mount_dir" 2>/dev/null | grep -q .; then
		echo "Refusing to remove a still-mounted staging tree: $mount_dir" >&2
	else
		rm -rf -- "$mount_dir"
	fi
	rm -rf -- "$firmware_stage"
}
trap cleanup EXIT

mount -o loop,rw "$output_image" "$mount_dir"
mounted=1
grep -qx 'ID=archarm' "$mount_dir/etc/os-release"
# The development image is mounted as the live root by a minimal PID 1.  Keep
# the three top-level package trees at their normal, non-world-writable modes;
# an early prototype image accidentally retained 0777 here and pacman reported
# the mismatch on every transaction.
chmod 0755 "$mount_dir" "$mount_dir/etc" "$mount_dir/usr"
for normal_dir in "$mount_dir/etc/ssh" "$mount_dir/etc/ssh/sshd_config.d" \
	"$mount_dir/usr/lib/firmware"; do
	[[ ! -d $normal_dir ]] || chmod 0755 "$normal_dir"
done

mount -t proc proc "$mount_dir/proc"
virtual_mounts+=("$mount_dir/proc")
for virtual_fs in sys dev run; do
	mount --rbind "/$virtual_fs" "$mount_dir/$virtual_fs"
	mount --make-rslave "$mount_dir/$virtual_fs"
	virtual_mounts+=("$mount_dir/$virtual_fs")
done

pacman_config=/tmp/tb371fc-development-pacman.conf
cp "$mount_dir/etc/pacman.conf" "$mount_dir$pacman_config"
sed -i 's/^[[:space:]]*CheckSpace/# CheckSpace disabled for qemu-user host build/' \
	"$mount_dir$pacman_config"
package_sources=("$packages")
[[ -z $extra_packages ]] || package_sources+=("$extra_packages")
mapfile -t package_list < <(cat "${package_sources[@]}" | \
	sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' | sort -u)
if [[ ! -s "$mount_dir/etc/pacman.d/gnupg/pubring.gpg" ]]; then
	echo 'Initializing the Arch Linux ARM package signing keyring...'
	chroot "$mount_dir" /usr/bin/pacman-key --init
	chroot "$mount_dir" /usr/bin/pacman-key --populate archlinux archlinuxarm
fi
chroot "$mount_dir" /usr/bin/pacman --config "$pacman_config" \
	-Syu --needed --noconfirm --disable-sandbox -- "${package_list[@]}"
rm -f "$mount_dir$pacman_config"

# Linux 4.19 predates Landlock.  Pacman 7 otherwise refuses all future live
# downloads from this intentionally old bridge kernel, so persist its documented
# compatibility switches in the Arch container.  The account drop still comes
# from DownloadUser=alpm; only Landlock/seccomp sandboxing is disabled.
sed -i \
	-e 's/^#DisableSandboxFilesystem/DisableSandboxFilesystem/' \
	-e 's/^#DisableSandboxSyscalls/DisableSandboxSyscalls/' \
	"$mount_dir/etc/pacman.conf"

(
	cd "$firmware_stage"
	gzip -dc "$firmware_initramfs" | cpio -idmu 2>/dev/null
)
rsync -aH "$firmware_stage/usr/lib/firmware/" "$mount_dir/usr/lib/firmware/"
rsync -aH "$overlay/" "$mount_dir/"
if [[ -n $kernel_modules_archive ]]; then
	tar -xzf "$kernel_modules_archive" -C "$mount_dir"
	printf '%s\n' \
		"kernel_release=${staged_kernel_releases[0]}" \
		"archive_sha256=$(sha256sum "$kernel_modules_archive" | awk '{print $1}')" \
		"module_files=$(find "$mount_dir/lib/modules/${staged_kernel_releases[0]}" -type f -name '*.ko*' | wc -l)" \
		>"$mount_dir/usr/share/tb371fc-development-kernel-modules.txt"
fi
# The overlay lives on drvfs, where directory modes are synthesized as 0777.
# rsync can therefore reapply that mode to the ext4 root after the initial
# normalization.  Restore normal Unix traversal permissions once all overlay
# metadata has landed.
chmod 0755 "$mount_dir" "$mount_dir/etc" "$mount_dir/usr"
for normal_dir in "$mount_dir/etc/ssh" \
	"$mount_dir/etc/ssh/sshd_config.d" "$mount_dir/usr/lib/firmware"; do
	[[ ! -d $normal_dir ]] || chmod 0755 "$normal_dir"
done
find "$mount_dir/usr/local/sbin" -maxdepth 1 -type f -exec chmod 0755 {} +
install -m0755 "$repo_dir/initramfs/start-qrtr-diagnostics" \
	"$mount_dir/usr/local/sbin/start-qrtr-diagnostics"
install -m0755 "$qrtr_ns" "$mount_dir/usr/local/bin/qrtr-ns"
install -m0755 "$qrtr_lookup" "$mount_dir/usr/local/bin/qrtr-lookup"
install -Dm0644 "$reboot_module" \
	"$mount_dir/usr/lib/modules/4.19.325-cip134-st18-perf+/extra/reboot-bootloader.ko"
install -d -m0700 "$mount_dir/root/.ssh"
install -m0600 "$client_key" "$mount_dir/root/.ssh/authorized_keys"
rm -f "$mount_dir/etc/ssh/ssh_host_"* "$mount_dir/etc/machine-id"
: >"$mount_dir/etc/machine-id"
# This image uses a deliberately small custom PID 1 rather than systemd.  Make
# the per-image host identity now so the first remote login cannot block on
# early-boot entropy or fail before the rescue channel is available.
chroot "$mount_dir" /usr/bin/ssh-keygen -A

random_password=$(openssl rand -hex 32)
password_hash=$(openssl passwd -6 "$random_password")
chroot "$mount_dir" /usr/bin/usermod -p "$password_hash" root
unset random_password password_hash

printf '%s\n' \
	'schema=2' \
	'platform=Lenovo TB371FC' \
	'kernel_release=external-loader' \
	"image_size_bytes=$target_size_bytes" \
	'root_transport=microSD-exFAT-loop-ext4' \
	'ssh=127.0.0.1:2222-over-usb-acm' \
	>"$mount_dir/etc/tb371fc-development-image"
chroot "$mount_dir" /usr/bin/pacman -Q \
	>"$mount_dir/usr/share/tb371fc-development-packages.txt"
sync

# Keep /dev, /proc, /sys and /run available until every AArch64 chroot helper
# has completed.  In particular, ssh-keygen opens /dev/null while generating
# per-image host keys.  Unmounting the virtual filesystems immediately after
# pacman made an otherwise complete resumed build stop before writing its
# final metadata and package manifest.
for ((index = ${#virtual_mounts[@]} - 1; index >= 0; index--)); do
	if mountpoint -q "${virtual_mounts[$index]}"; then
		umount -R "${virtual_mounts[$index]}" 2>/dev/null || \
			umount -R -l "${virtual_mounts[$index]}"
	fi
done
virtual_mounts=()

umount "$mount_dir" 2>/dev/null || umount -l "$mount_dir"
mounted=0
detach_output_loops
e2fsck -fy "$output_image" >/dev/null

echo "TB371FC Arch development image: $output_image"
du -h "$output_image"
sha256sum "$output_image"
