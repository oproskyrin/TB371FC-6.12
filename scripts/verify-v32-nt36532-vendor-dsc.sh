#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_tree=/root/tb371fc-lenovo-4.19-v32-nt36532-vendor-dsc-src
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v32-nt36532-vendor-dsc
image="$output_dir/tb371fc-arch-development-loader-v32-nt36532-vendor-dsc-recovery.img"
kernel="$output_dir/Image-v32-nt36532-vendor-dsc"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v28_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img
expected_sha256=3e63740d14de47725722f9b86000e8181491cfab89f75d04d6818bf0be705569
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v28_recovery" --out "$stage/v28" --format info \
	>"$stage/v28-info.txt"

"$project_dir/scripts/verify-diagnostic-recovery.sh" \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$image" \
	"$stock_recovery" \
	"$kernel" \
	"$stage/v28/ramdisk" \
	"$stage/v28/dtb" \
	"$expected_sha256"

panel="$source_tree/techpack/display/msm/dsi/dsi_panel.c"
grep -q 'tb371fc_nt36532_dsc_write(panel, 0x90, 0x03)' "$panel"
grep -q 'dsi_panel_tx_cmd_set(panel, DSI_CMD_SET_PPS)' "$panel"
grep -q 'tb371fc_nt36532_dsc_write(panel, 0x9d, 0x01)' "$panel"
grep -q 'MIPI_DSI_MSG_USE_LPM | MIPI_DSI_MSG_LASTCOMMAND' "$panel"
grep -q 'atomic_cmpxchg(&nt36532_enable_budget, 1, 0) == 1' "$panel"
grep -q 'TB371FC NT36532 vendor DSC enable complete' "$kernel"

python3 - "$panel" <<'PY'
import sys

text = open(sys.argv[1], encoding="utf-8").read()
tokens = [
    "tb371fc_nt36532_dsc_write(panel, 0x90, 0x03)",
    "dsi_panel_tx_cmd_set(panel, DSI_CMD_SET_PPS)",
    "tb371fc_nt36532_dsc_write(panel, 0x9d, 0x01)",
]
positions = [text.index(token) for token in tokens]
if positions != sorted(positions):
    raise SystemExit(f"incorrect NT36532 DSC sequence: {positions}")
print("Verified first-cold-enable NT36532 order: 90 03 -> PPS -> 9d 01")
PY

sha256sum "$kernel" "$image"
