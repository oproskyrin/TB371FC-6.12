#!/usr/bin/env bash
# R194: the read-only register peek module for the first-stage 4.19 console (v56.6 build, signed).
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
o=/root/tb371fc-desktop-v56-6-watchdog-kexec-out; s=/root/tb371fc-desktop-v56-6-watchdog-kexec-src
m=/root/tb371fc/r194-campeek-419; rm -rf "$m"; mkdir -p "$m"; cp "$p/scripts/r194-campeek/tb371fc-campeek.c" "$m/"
echo 'obj-m := tb371fc-campeek.o' > "$m/Makefile"
export PATH=/root/snapdragon-clang-10.0.7/bin:$PATH
make -C "$s" O="$o" ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- M="$m" modules > /tmp/r194-419.log 2>&1 || { grep -E "error" /tmp/r194-419.log | head; exit 1; }
"$o/scripts/sign-file" sha512 "$o/certs/signing_key.pem" "$o/certs/signing_key.x509" "$m/tb371fc-campeek.ko"
modinfo -F vermagic "$m/tb371fc-campeek.ko"
mkdir -p /mnt/d/TB371FC-builds/r194-campeek; cp "$m/tb371fc-campeek.ko" /mnt/d/TB371FC-builds/r194-campeek/tb371fc-campeek-419.ko
