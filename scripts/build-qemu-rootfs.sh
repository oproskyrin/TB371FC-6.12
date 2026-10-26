#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 ARCH_ROOTFS OUTPUT_RAW_IMAGE [SIZE]" >&2
    echo "Example: $0 /root/arch-tb371fc/rootfs /root/arch-tb371fc/qemu-rootfs.raw 6G" >&2
    exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage
[[ $EUID -eq 0 ]] || {
    echo "Run as root; a temporary loop mount is required." >&2
    exit 1
}

source_root=$(realpath "$1")
output_image=$(realpath -m "$2")
image_size=${3:-6G}

[[ -f "$source_root/etc/os-release" ]] || {
    echo "Not an Arch rootfs: $source_root" >&2
    exit 1
}
grep -qx 'ID=archarm' "$source_root/etc/os-release" || {
    echo "The source is not identified as Arch Linux ARM: $source_root" >&2
    exit 1
}
[[ ! -e "$output_image" ]] || {
    echo "Refusing to overwrite existing image: $output_image" >&2
    exit 1
}
[[ $output_image != "$source_root"/* ]] || {
    echo "Output image must be outside the source rootfs." >&2
    exit 1
}
[[ -d $(dirname "$output_image") ]] || {
    echo "Output directory does not exist: $(dirname "$output_image")" >&2
    exit 1
}

for command_name in mkfs.ext4 mountpoint rsync truncate; do
    command -v "$command_name" >/dev/null || {
        echo "Missing host tool: $command_name" >&2
        exit 1
    }
done

mount_dir=$(mktemp -d /tmp/tb371fc-qemu-root.XXXXXX)
complete=0
output_owned=0
cleanup() {
    set +e
    if mountpoint -q "$mount_dir"; then
        umount "$mount_dir"
    fi
    rmdir "$mount_dir"
    if [[ $complete -ne 1 && $output_owned -eq 1 && -f $output_image ]]; then
        rm -f -- "$output_image"
    fi
}
trap cleanup EXIT

if ! (set -o noclobber; : >"$output_image") 2>/dev/null; then
    echo "Output appeared during preparation; refusing to overwrite: $output_image" >&2
    exit 1
fi
output_owned=1
truncate -s "$image_size" "$output_image"
mkfs.ext4 -F -L archroot "$output_image" >/dev/null
mount -o loop "$output_image" "$mount_dir"
rsync -aHAX --numeric-ids "$source_root/" "$mount_dir/"
printf 'LABEL=archroot / ext4 defaults 0 1\n' >"$mount_dir/etc/fstab"
sync
complete=1

echo "QEMU root disk created: $output_image"
df -h "$mount_dir"
