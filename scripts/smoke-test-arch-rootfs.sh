#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 ARCH_ROOTFS" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
rootfs=$(realpath "$1")

[[ $EUID -eq 0 ]] || {
    echo "Run as root so chroot can preserve the target filesystem." >&2
    exit 1
}
[[ -f "$rootfs/etc/os-release" ]] || {
    echo "Not an Arch rootfs: $rootfs" >&2
    exit 1
}
for executable in bin/uname usr/bin/pacman usr/lib/systemd/systemd; do
    [[ -x "$rootfs/$executable" ]] || {
        echo "Missing executable: $rootfs/$executable" >&2
        exit 1
    }
done

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
fi

target_machine=$(chroot "$rootfs" /bin/uname -m)
# The quoted expression is intentionally evaluated by the target shell.
# shellcheck disable=SC2016
target_os=$(chroot "$rootfs" /bin/sh -c '. /etc/os-release; printf "%s" "$PRETTY_NAME"')
pacman_version=$(
    chroot "$rootfs" /usr/bin/pacman --version |
        grep -o 'Pacman v[^[:space:]]* - libalpm v[^[:space:]]*' |
        head -n 1
)
systemd_version=$(chroot "$rootfs" /usr/lib/systemd/systemd --version 2>/dev/null | sed -n '1p')

[[ $target_machine == aarch64 ]] || {
    echo "Unexpected target architecture: $target_machine" >&2
    exit 1
}
[[ $target_os == "Arch Linux ARM" ]] || {
    echo "Unexpected target OS: $target_os" >&2
    exit 1
}

echo "Arch rootfs smoke test passed"
echo "  machine: $target_machine"
echo "  os: $target_os"
echo "  package manager: $pacman_version"
echo "  init: $systemd_version"
