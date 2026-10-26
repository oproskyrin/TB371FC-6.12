#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 ARCH_ROOTFS RAW_IMAGE QEMU_INITRAMFS [LOG_FILE] [TIMEOUT_SECONDS]" >&2
    exit 2
}

[[ $# -ge 3 && $# -le 5 ]] || usage
rootfs=$(realpath "$1")
disk_image=$(realpath "$2")
qemu_initramfs=$(realpath "$3")
log_file=${4:-qemu-arch-boot.log}
timeout_seconds=${5:-90}

command -v qemu-system-aarch64 >/dev/null || {
    echo "qemu-system-aarch64 is not installed." >&2
    exit 1
}
[[ -f "$rootfs/boot/Image" ]] || {
    echo "Missing generic kernel: $rootfs/boot/Image" >&2
    exit 1
}
[[ -f $qemu_initramfs ]] || {
    echo "Missing QEMU initramfs: $qemu_initramfs" >&2
    exit 1
}
[[ -f $disk_image ]] || {
    echo "Missing root disk: $disk_image" >&2
    exit 1
}
[[ $timeout_seconds =~ ^[1-9][0-9]*$ ]] || {
    echo "Timeout must be a positive integer." >&2
    exit 1
}

: >"$log_file"
qemu-system-aarch64 \
    -machine virt,gic-version=3 \
    -cpu cortex-a72 \
    -smp 4 \
    -m 2048 \
    -display none \
    -monitor none \
    -serial "file:$log_file" \
    -no-reboot \
    -kernel "$rootfs/boot/Image" \
    -initrd "$qemu_initramfs" \
    -append 'root=LABEL=archroot rw console=ttyAMA0,115200 earlycon=pl011,0x09000000 systemd.unit=multi-user.target' \
    -drive "if=none,file=$disk_image,format=raw,id=rootfs" \
    -device virtio-blk-device,drive=rootfs \
    -device virtio-rng-device \
    -netdev user,id=net0 \
    -device virtio-net-device,netdev=net0 &
qemu_pid=$!

# Invoked indirectly by the EXIT trap.
# shellcheck disable=SC2317
stop_qemu() {
    if kill -0 "$qemu_pid" 2>/dev/null; then
        kill -TERM "$qemu_pid"
        wait "$qemu_pid" 2>/dev/null || true
    fi
}
trap stop_qemu EXIT

for ((elapsed = 0; elapsed < timeout_seconds; elapsed++)); do
    if grep -Eq 'Reached target .*Multi-User System|^alarm login:' "$log_file"; then
        echo "QEMU Arch boot smoke test passed; serial log: $log_file"
        exit 0
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        set +e
        wait "$qemu_pid"
        qemu_status=$?
        set -e
        echo "QEMU exited before multi-user target with status $qemu_status" >&2
        exit 1
    fi
    sleep 1
done

echo "QEMU did not reach the multi-user target in ${timeout_seconds}s; inspect $log_file" >&2
exit 1
