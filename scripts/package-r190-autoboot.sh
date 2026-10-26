#!/usr/bin/env bash
# R190 payload (test): R188 Image + R190 DTB (microphones: WCD938x, SoundWire, TX macro) + R179 initramfs.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r190-autoboot; rm -rf "$pkg"; mkdir -p "$pkg"
cp /mnt/d/TB371FC-builds/r188-autoboot/Image /mnt/d/TB371FC-builds/r188-autoboot/initramfs.cpio.gz "$pkg/"; cp /mnt/d/TB371FC-builds/r190-mic/board.dtb "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz | tee SHA256SUMS
tar -czf r190-payload.tar.gz Image board.dtb initramfs.cpio.gz
