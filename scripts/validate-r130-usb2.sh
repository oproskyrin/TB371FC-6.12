#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late
stage=$(cat "$pkg/staging-path.txt")
(cd "$pkg"; sha256sum -c SHA256SUMS)
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
test "$(modinfo -F vermagic "$pkg/dwc3-qcom.ko")" = "$(modinfo -F vermagic "$pkg/phy-qcom-snps-femto-v2.ko")"
test ! -e "$stage/r130-config/id_ed25519"
cmp "$stage/r130-config/id_ed25519.pub" "$project/artifacts/tb371fc-development-ssh/id_ed25519.pub"
qa=$(mktemp -d /root/tb371fc/r130-overlay-qa.XXXXXX)
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
mkdir -p "$qa/merged/etc/systemd/system" "$qa/merged/run/r130/config" "$qa/merged/run/sshd"
cp "$stage/bin/busybox" "$qa/merged/run/r130/busybox"
cp "$stage/r130-config/"* "$qa/merged/run/r130/config/"
cp "$stage/r130-config/"*.service "$qa/merged/etc/systemd/system/"
chmod 0644 "$qa/merged/etc/systemd/system/"*.service
test -x "$qa/merged/usr/bin/sshd"
test -x "$qa/merged/usr/bin/ssh-keygen"
qemu-aarch64-static -L "$qa/merged" "$qa/merged/usr/bin/systemd-analyze" --root="$qa/merged" verify r130-usb.service r130-sshd.service
for file in "$stage/r130-config/"*.sh; do sh -n "$file"; done
test "$(sha256sum "$qa/lower/etc/fstab")" = "$before"
printf 'PASS: hashes, preserved R129 loader, module versions, public key, shell syntax and ARM systemd units. QA path: %s\n' "$qa"
