#!/usr/bin/env bash
# R174 maintenance payload: R173 Image/DTB + R173 initramfs with a RAM-only maintenance stop.
# With "tb371fc.maint" on the kernel cmdline the loader stops before touching the microSD and keeps
# the USB rescue shell (169.254.77.2:2323); static disk tools are in /usr/maint.
set -euo pipefail
src=/mnt/d/TB371FC-builds/r173-autoboot; pkg=/mnt/d/TB371FC-builds/r174-maint; t=/mnt/d/TB371FC-builds/r174-bh201/maint
rm -rf "$pkg"; mkdir -p "$pkg"
(cd "$src"; grep -E " (Image|board.dtb|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
stage=$(mktemp -d /root/tb371fc/r174-maint.XXXXXX)
(cd "$stage"; gzip -dc "$src/initramfs.cpio.gz" | cpio -idmu --quiet)
mkdir -p "$stage/usr/maint"; cp "$t"/* "$stage/usr/maint/"; chmod 0755 "$stage"/usr/maint/*; chmod 0644 "$stage/usr/maint/tb371fc-bh201.ko"
python3 - "$stage/init" "$(dirname "$0")/r175-loader/maint-hook.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read(); hook = open(sys.argv[2]).read()
old = "echo 'TB371FC Arch development loader started.'\n"
assert s.count(old) == 1
s = s.replace(old, hook + old)
open(p, "w").write(s)
PY
sh -n "$stage/init"; grep -n "MAINTENANCE" "$stage/init"
cp "$src/Image" "$src/board.dtb" "$pkg/"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r174-maint-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r174-maint-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
