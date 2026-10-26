#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 ARCH_ROOTFS OUTPUT_INITRAMFS" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage
[[ $EUID -eq 0 ]] || {
    echo "Run as root so mkinitcpio can execute in the target rootfs." >&2
    exit 1
}

rootfs=$(realpath "$1")
output_initramfs=$(realpath -m "$2")

[[ -x "$rootfs/usr/bin/mkinitcpio" ]] || {
    echo "mkinitcpio is missing from $rootfs" >&2
    exit 1
}
[[ -f "$rootfs/boot/initramfs-linux.img" ]] || {
    echo "Reference initramfs is missing from $rootfs/boot" >&2
    exit 1
}
[[ ! -e "$output_initramfs" ]] || {
    echo "Refusing to overwrite existing initramfs: $output_initramfs" >&2
    exit 1
}
[[ $output_initramfs != "$rootfs"/* ]] || {
    echo "Output initramfs must be outside the source rootfs." >&2
    exit 1
}
[[ -d $(dirname "$output_initramfs") ]] || {
    echo "Output directory does not exist: $(dirname "$output_initramfs")" >&2
    exit 1
}

kernel_release=$(
    chroot "$rootfs" /usr/bin/lsinitcpio -a /boot/initramfs-linux.img 2>/dev/null |
        sed -n 's/^==> Kernel: //p' |
        head -n 1
)
[[ -n $kernel_release && -d "$rootfs/usr/lib/modules/$kernel_release" ]] || {
    echo "Could not identify the reference initramfs kernel release." >&2
    exit 1
}
[[ -f "$rootfs/usr/lib/modules/$kernel_release/kernel/drivers/virtio/virtio_mmio.ko" ]] || {
    echo "virtio_mmio.ko is missing for $kernel_release" >&2
    exit 1
}

config_path=$(mktemp "$rootfs/tmp/tb371fc-qemu-mkinitcpio.XXXXXX.conf")
target_path=$(mktemp "$rootfs/tmp/tb371fc-qemu-initramfs.XXXXXX.img")
mounted_targets=()
output_owned=0
output_complete=0
cleanup() {
    set +e
    rm -f -- "$config_path" "$target_path"
    for ((index = ${#mounted_targets[@]} - 1; index >= 0; index--)); do
        umount -R "${mounted_targets[$index]}"
    done
    if [[ $output_owned -eq 1 && $output_complete -ne 1 ]]; then
        rm -f -- "$output_initramfs"
    fi
}
trap cleanup EXIT

if ! mountpoint -q "$rootfs/proc"; then
    mount -t proc proc "$rootfs/proc"
    mounted_targets+=("$rootfs/proc")
fi
for virtual_fs in sys dev; do
    target="$rootfs/$virtual_fs"
    if ! mountpoint -q "$target"; then
        mount --rbind "/$virtual_fs" "$target"
        mount --make-rslave "$target"
        mounted_targets+=("$target")
    fi
done

cp "$rootfs/etc/mkinitcpio.conf" "$config_path"
sed -i 's/^MODULES=.*/MODULES=(virtio_mmio)/' "$config_path"
grep -qx 'MODULES=(virtio_mmio)' "$config_path" || {
    echo "Could not set MODULES in the temporary mkinitcpio configuration." >&2
    exit 1
}

config_in_chroot=${config_path#"$rootfs"}
target_in_chroot=${target_path#"$rootfs"}
chroot "$rootfs" /usr/bin/mkinitcpio \
    -c "$config_in_chroot" \
    -k "$kernel_release" \
    -g "$target_in_chroot"
if ! (set -o noclobber; : >"$output_initramfs") 2>/dev/null; then
    echo "Output appeared during preparation; refusing to overwrite: $output_initramfs" >&2
    exit 1
fi
output_owned=1
cp "$target_path" "$output_initramfs"
output_complete=1

echo "QEMU initramfs created: $output_initramfs"
echo "  kernel: $kernel_release"
echo "  added module: virtio_mmio"
