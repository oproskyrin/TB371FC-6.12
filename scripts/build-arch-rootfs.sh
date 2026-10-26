#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: build-arch-rootfs.sh ARCHIVE OUTPUT_DIR MODULES_INSTALL_ROOT FIRMWARE_DIR KERNEL_IMAGE SAFE_DTB TOUCH_DTB [PACKAGE_MANIFEST]

Build a console-first TB371FC Arch Linux ARM directory. The source archive,
output directory and all hardware artifacts remain host-side; no tablet is
accessed by this script.
EOF
    exit 2
}

[[ $# -ge 7 && $# -le 8 ]] || usage
[[ $EUID -eq 0 ]] || {
    echo "Run as root to preserve rootfs ownership and use a chroot." >&2
    exit 1
}

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
archive=$(realpath "$1")
output_dir=$(realpath -m "$2")
modules_root=$(realpath "$3")
firmware_dir=$(realpath "$4")
kernel_image=$(realpath "$5")
safe_dtb=$(realpath "$6")
touch_dtb=$(realpath "$7")
package_manifest=$(realpath "${8:-$project_dir/rootfs/packages-base.txt}")
overlay_dir="$project_dir/rootfs/overlay"
output_parent=$(dirname "$output_dir")

for required_file in "$archive" "$kernel_image" "$safe_dtb" "$touch_dtb" "$package_manifest"; do
    [[ -f $required_file ]] || {
        echo "Missing required file: $required_file" >&2
        exit 1
    }
done
for required_dir in "$modules_root/lib/modules" "$firmware_dir" "$overlay_dir" "$output_parent"; do
    [[ -d $required_dir ]] || {
        echo "Missing required directory: $required_dir" >&2
        exit 1
    }
done
[[ ! -e $output_dir ]] || {
    echo "Refusing to overwrite existing rootfs: $output_dir" >&2
    exit 1
}
if tar -tf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    echo "Archive contains an unsafe path: $archive" >&2
    exit 1
fi
if [[ -n ${ARCHIVE_SHA256:-} ]]; then
    actual_archive_sha256=$(sha256sum "$archive" | cut -d' ' -f1)
    [[ $actual_archive_sha256 == "$ARCHIVE_SHA256" ]] || {
        echo "Archive SHA-256 mismatch." >&2
        echo "Expected: $ARCHIVE_SHA256" >&2
        echo "Actual:   $actual_archive_sha256" >&2
        exit 1
    }
fi

mapfile -t releases < <(find "$modules_root/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
[[ ${#releases[@]} -eq 1 ]] || {
    echo "Expected exactly one module release in $modules_root, found ${#releases[@]}." >&2
    exit 1
}
kernel_release=${releases[0]}
[[ -s "$modules_root/lib/modules/$kernel_release/modules.dep" ]] || {
    echo "modules.dep is missing for $kernel_release" >&2
    exit 1
}

for firmware_path in \
    ath11k/QCA6390/hw2.0/amss.bin \
    ath11k/QCA6390/hw2.0/board-2.bin \
    ath11k/QCA6390/hw2.0/m3.bin \
    qca/htbtfw20.tlv \
    qcom/a650_sqe.fw \
    qcom/sm8250/lenovo/tb371fc/adsp.mbn; do
    [[ -s "$firmware_dir/$firmware_path" ]] || {
        echo "Required TB371FC firmware is missing: $firmware_path" >&2
        exit 1
    }
done

pacman_host_args=()
use_emulated_pacman_config=false
if [[ $(uname -m) != aarch64 ]]; then
    command -v qemu-aarch64-static >/dev/null || {
        echo "qemu-aarch64-static is required on a non-AArch64 host." >&2
        exit 1
    }
    [[ -r /proc/sys/fs/binfmt_misc/qemu-aarch64 ]] || {
        echo "The qemu-aarch64 binfmt handler is not registered." >&2
        exit 1
    }
    grep -qx enabled /proc/sys/fs/binfmt_misc/qemu-aarch64 || {
        echo "The qemu-aarch64 binfmt handler is disabled." >&2
        exit 1
    }
    # Pacman's Landlock/seccomp downloader sandbox cannot initialize through
    # qemu-user on WSL. Its CheckSpace mount-point probe is unsupported there
    # as well. Package signature verification remains enabled.
    pacman_host_args+=(--disable-sandbox)
    use_emulated_pacman_config=true
fi

mapfile -t packages < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$package_manifest")
[[ ${#packages[@]} -gt 0 ]] || {
    echo "Package manifest is empty: $package_manifest" >&2
    exit 1
}

staging_dir=$(mktemp -d "$output_parent/.tb371fc-rootfs.XXXXXX")
mounted_targets=()
complete=0
unmount_virtual_filesystems() {
    local index target

    for ((index = ${#mounted_targets[@]} - 1; index >= 0; index--)); do
        target=${mounted_targets[$index]}
        if mountpoint -q "$target"; then
            umount -R "$target" 2>/dev/null || umount -R -l "$target"
        fi
    done
    mounted_targets=()
}
cleanup() {
    set +e
    unmount_virtual_filesystems
    if [[ $complete -ne 1 && -d $staging_dir ]]; then
        rm -rf -- "$staging_dir"
    fi
}
trap cleanup EXIT

echo "Extracting Arch Linux ARM rootfs..."
tar --numeric-owner -xpf "$archive" -C "$staging_dir"
grep -qx 'ID=archarm' "$staging_dir/etc/os-release" || {
    echo "The archive is not identified as Arch Linux ARM." >&2
    exit 1
}

mount -t proc proc "$staging_dir/proc"
mounted_targets+=("$staging_dir/proc")
for virtual_fs in sys dev run; do
    mount --rbind "/$virtual_fs" "$staging_dir/$virtual_fs"
    mount --make-rslave "$staging_dir/$virtual_fs"
    mounted_targets+=("$staging_dir/$virtual_fs")
done

echo "Updating signed packages and installing the console profile..."
pacman_config=/etc/pacman.conf
if [[ $use_emulated_pacman_config == true ]]; then
    cp "$staging_dir/etc/pacman.conf" "$staging_dir/tmp/tb371fc-pacman.conf"
    sed -i 's/^[[:space:]]*CheckSpace/# CheckSpace disabled for qemu-user host build/' \
        "$staging_dir/tmp/tb371fc-pacman.conf"
    pacman_config=/tmp/tb371fc-pacman.conf
fi
if [[ ! -s "$staging_dir/etc/pacman.d/gnupg/pubring.gpg" ]]; then
    echo "Initializing the Arch Linux ARM package signing keyring..."
    chroot "$staging_dir" /usr/bin/pacman-key --init
    chroot "$staging_dir" /usr/bin/pacman-key --populate archlinux archlinuxarm
fi
chroot "$staging_dir" /usr/bin/pacman --config "$pacman_config" \
    -Syu --needed --noconfirm \
    "${pacman_host_args[@]}" -- "${packages[@]}"
rm -f "$staging_dir/tmp/tb371fc-pacman.conf"

unmount_virtual_filesystems

echo "Installing TB371FC kernel modules and firmware..."
install -d "$staging_dir/usr/lib/modules/$kernel_release" "$staging_dir/usr/lib/firmware"
rsync -aH "$modules_root/lib/modules/$kernel_release/" "$staging_dir/usr/lib/modules/$kernel_release/"
rsync -aH "$firmware_dir/" "$staging_dir/usr/lib/firmware/"
depmod -b "$staging_dir" "$kernel_release"

install -Dm0644 "$kernel_image" "$staging_dir/boot/tb371fc/Image"
install -Dm0644 "$safe_dtb" "$staging_dir/boot/tb371fc/sm8250-lenovo-tb371fc.dtb"
install -Dm0644 "$touch_dtb" "$staging_dir/boot/tb371fc/sm8250-lenovo-tb371fc-touch-test.dtb"
install -Dm0644 "$package_manifest" "$staging_dir/usr/share/tb371fc-port/packages-base.txt"
rsync -aH "$overlay_dir/" "$staging_dir/"

systemctl --root="$staging_dir" set-default multi-user.target >/dev/null
systemctl --root="$staging_dir" enable NetworkManager.service bluetooth.service >/dev/null

manifest_dir="$staging_dir/usr/share/tb371fc-port"
chroot "$staging_dir" /usr/bin/pacman -Q >"$manifest_dir/packages-installed.txt"
(
    cd "$firmware_dir"
    find . -type f -print0 | sort -z | xargs -0 sha256sum
) >"$manifest_dir/firmware-SHA256SUMS"
(
    cd "$staging_dir/usr/lib/modules/$kernel_release"
    find . -type f -print0 | sort -z | xargs -0 sha256sum
) >"$manifest_dir/modules-SHA256SUMS"

archive_sha256=$(sha256sum "$archive" | cut -d' ' -f1)
kernel_sha256=$(sha256sum "$kernel_image" | cut -d' ' -f1)
safe_dtb_sha256=$(sha256sum "$safe_dtb" | cut -d' ' -f1)
touch_dtb_sha256=$(sha256sum "$touch_dtb" | cut -d' ' -f1)
cat >"$manifest_dir/BUILD-MANIFEST" <<EOF
schema=1
built_at=$(date -u --iso-8601=seconds)
source_archive_sha256=$archive_sha256
kernel_release=$kernel_release
kernel_image_sha256=$kernel_sha256
safe_dtb_sha256=$safe_dtb_sha256
touch_test_dtb_sha256=$touch_dtb_sha256
default_target=multi-user.target
networkmanager_enabled=true
bluetooth_enabled=true
sshd_enabled=false
EOF

[[ ! -e $output_dir ]] || {
    echo "Output appeared during the build; refusing to replace it: $output_dir" >&2
    exit 1
}
mv -T "$staging_dir" "$output_dir"
complete=1

echo "TB371FC Arch rootfs created: $output_dir"
echo "  kernel release: $kernel_release"
echo "  default target: multi-user.target"
echo "  SSH remains disabled until the default passwords are changed"
