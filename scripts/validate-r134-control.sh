#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
pkg=/mnt/d/TB371FC-builds/linux-6.12-r134-panel
stage=$(cat "$pkg/staging-path.txt")
(cd "$pkg"; sha256sum -c SHA256SUMS)
python3 "$project/scripts/verify-r134-panel-source.py"
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
for file in "$pkg/modules/"*.ko; do
    modinfo -F vermagic "$file" | grep -q '^6.12.30-tb371fc-r134-panel+'
done
test "$(find "$pkg/modules" -maxdepth 1 -name '*.ko' | wc -l)" -eq 9
qa=$(mktemp -d /root/tb371fc/r134-overlay-qa.XXXXXX)
mkdir "$qa/lower" "$qa/ram" "$qa/merged"
cleanup() {
    mountpoint -q "$qa/merged" && umount "$qa/merged" || true
    mountpoint -q "$qa/ram" && umount "$qa/ram" || true
    mountpoint -q "$qa/lower" && umount "$qa/lower" || true
}
trap cleanup EXIT
mount -o loop,ro,noload /root/arch-tb371fc/tb371fc-arch-development-v2-12g.raw "$qa/lower"
mount -t tmpfs -o size=32M tmpfs "$qa/ram"
mkdir "$qa/ram/upper" "$qa/ram/work"
mount -t overlay overlay -o "lowerdir=$qa/lower,upperdir=$qa/ram/upper,workdir=$qa/ram/work" "$qa/merged"
mkdir -p "$qa/merged/etc/systemd/system" "$qa/merged/run/r130" "$qa/merged/run/r134/config"
cp "$stage/bin/busybox" "$qa/merged/run/r130/busybox"
cp "$stage/r130-config/"*.service "$stage/r134-config/"*.service "$qa/merged/etc/systemd/system/"
cp "$stage/r134-config/"*.sh "$qa/merged/run/r134/config/"
chmod 0644 "$qa/merged/etc/systemd/system/"*.service
qemu-aarch64-static -L "$qa/merged" "$qa/merged/usr/bin/systemd-analyze" --root="$qa/merged" verify r130-usb.service r130-sshd.service r134-display-deps.service
printf 'PASS: R134 package, nine matching modules, stock-source verifier, unchanged R129 loader and ARM systemd dependency units\n'
