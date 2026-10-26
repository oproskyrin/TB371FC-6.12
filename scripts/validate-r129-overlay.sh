#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
qa=$(mktemp -d /root/tb371fc/r129-overlay-qa.XXXXXX)
mkdir "$qa/lower" "$qa/ram" "$qa/merged"
cleanup() {
    mountpoint -q "$qa/merged" && umount "$qa/merged" || true
    mountpoint -q "$qa/ram" && umount "$qa/ram" || true
    mountpoint -q "$qa/lower" && umount "$qa/lower" || true
}
trap cleanup EXIT
mount -o loop,ro,noload /root/arch-tb371fc/tb371fc-arch-development-v2-12g.raw "$qa/lower"
before=$(sha256sum "$qa/lower/etc/fstab")
mount -t tmpfs -o size=32M tmpfs "$qa/ram"
mkdir "$qa/ram/upper" "$qa/ram/work"
mount -t overlay overlay -o "lowerdir=$qa/lower,upperdir=$qa/ram/upper,workdir=$qa/ram/work" "$qa/merged"
cp "$project/scripts/r129/fstab" "$qa/merged/etc/fstab"
cmp "$project/scripts/r129/fstab" "$qa/merged/etc/fstab"
test "$(sha256sum "$qa/lower/etc/fstab")" = "$before"
test -f "$qa/ram/upper/etc/fstab"
mkdir -p "$qa/merged/etc/systemd/system" "$qa/merged/usr/local/sbin"
cp "$project/scripts/r129/r129-evidence.service" "$project/scripts/r129/r129-evidence.timer" "$qa/merged/etc/systemd/system/"
chmod 0644 "$qa/merged/etc/systemd/system/r129-evidence.service" "$qa/merged/etc/systemd/system/r129-evidence.timer"
cp "$project/scripts/r129/r129-evidence.sh" "$qa/merged/usr/local/sbin/tb371fc-r129-evidence"
chmod 0755 "$qa/merged/usr/local/sbin/tb371fc-r129-evidence"
qemu-aarch64-static -L "$qa/merged" "$qa/merged/usr/lib/systemd/systemd" --version
qemu-aarch64-static -L "$qa/merged" "$qa/merged/usr/bin/systemd-analyze" --root="$qa/merged" verify r129-evidence.service r129-evidence.timer
printf 'PASS: overlay writes land in RAM; lower fstab unchanged; systemd ELF and units checked. QA path: %s\n' "$qa"
