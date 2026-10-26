#!/usr/bin/env bash
# R188 payload: R188 Image (R179 + USER_NS + PID_NS + built-in MM8013) + R185 DTB + R179 initramfs (modules unchanged:
# Module.symvers CRCs identical to R179).
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r188-autoboot; rm -rf "$pkg"; mkdir -p "$pkg"
cp /mnt/d/TB371FC-builds/r188-kernel/Image "$pkg/"; cp /mnt/d/TB371FC-builds/r185-autoboot/board.dtb /mnt/d/TB371FC-builds/r185-autoboot/initramfs.cpio.gz "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz | tee SHA256SUMS
grep -q a02916b971a9930c57da05485ef8e1ea63e0e669832286d11e17d8b0603cb79d SHA256SUMS
grep -q d0c2418e252e75bcbc46481988dce0199f55e2be4ed7ef3a1b48a88fb19b86b1 SHA256SUMS
tar -czf r188-payload.tar.gz Image board.dtb initramfs.cpio.gz
