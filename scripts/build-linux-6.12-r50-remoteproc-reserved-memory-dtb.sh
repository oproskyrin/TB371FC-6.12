#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

kernel_dir=/root/tb371fc/linux-6.12-donor-r47
out_dir=/root/tb371fc/build-6.12-r38-watchdog-handoff
dtb_name=sm8250-lenovo-tb371fc-archsafe-microsd
dts_path="$kernel_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-archsafe.dts"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r50-remoteproc-reserved-memory-dtb

test -d "$kernel_dir/.git"
test -f "$out_dir/.config"
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

# Revised hypothesis (2026-08-29): the community 6.12 board DTS reserves
# only cont_splash_mem. The stock Lenovo DTB reserves many more fixed
# physical regions (remote-processor firmware/PIL images, secure-memory
# metadata) as removed-dma-pool/no-map. Under kexec from a live V56.6,
# QCA6390 Wi-Fi, audio and other subsystems are already running with their
# firmware resident in exactly those regions; the r48 cold-boot test (where
# nothing is running yet) passed the same map_mem() checkpoint that every
# kexec attempt failed. Add the same fixed-address reservations the stock
# DTB carries so map_mem() excludes them from the linear map identically to
# 4.19, in case that is what's corrupting/faulting under a live handoff.
# Addresses/sizes copied verbatim from
# tb371fc-devicetree/qcom/original/lenovo-tb371fc.dts (decompiled stock DTB).
python3 - "$dts_path" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

needle = (
	"\treserved-memory {\n"
	"\t\tcont_splash_mem: memory@9c000000 {\n"
	"\t\t\treg = <0x0 0x9c000000 0x0 0x2300000>;\n"
	"\t\t\tno-map;\n"
	"\t\t};\n"
	"\t};\n"
)
assert text.count(needle) == 1, "reserved-memory node not found or not unique"

regions = [
	("xbl_aop_region", "80700000", "0x80700000", "0x160000"),
	("cmd_db_region",  "80860000", "0x80860000", "0x20000"),
	("res_xbl_uefi_log_region", "80880000", "0x80880000", "0x14000"),
	("smem_region",    "80900000", "0x80900000", "0x200000"),
	("removed_region", "80b00000", "0x80b00000", "0x5300000"),
	("pil_camera_region", "86200000", "0x86200000", "0x500000"),
	("pil_wlan_fw_region", "86700000", "0x86700000", "0x100000"),
	("pil_ipa_fw_region", "86800000", "0x86800000", "0x10000"),
	("pil_ipa_gsi_region", "86810000", "0x86810000", "0xa000"),
	("pil_gpu_region", "8681a000", "0x8681a000", "0x2000"),
	("pil_npu_region", "86900000", "0x86900000", "0x500000"),
	("pil_video_region", "86e00000", "0x86e00000", "0x500000"),
	("pil_cvp_region", "87300000", "0x87300000", "0x500000"),
	("pil_cdsp_region", "87800000", "0x87800000", "0x1400000"),
	("pil_slpi_region", "88c00000", "0x88c00000", "0x1500000"),
	("pil_adsp_region", "8a100000", "0x8a100000", "0x1d00000"),
	("pil_spss_region", "8be00000", "0x8be00000", "0x100000"),
	("cdsp_secure_heap_region", "8bf00000", "0x8bf00000", "0x4600000"),
	("boot_log_region", "b0000000", "0xb0000000", "0x80000"),
]
lines = ["\treserved-memory {\n", "\t\tcont_splash_mem: memory@9c000000 {\n",
	"\t\t\treg = <0x0 0x9c000000 0x0 0x2300000>;\n", "\t\t\tno-map;\n", "\t\t};\n"]
for label, addr, reg_hi, size in regions:
	lines.append(f"\t\t{label}: memory@{addr} {{\n")
	lines.append(f"\t\t\treg = <0x0 {reg_hi} 0x0 {size}>;\n")
	lines.append("\t\t\tno-map;\n")
	lines.append("\t\t};\n")
lines.append("\t};\n")
replacement = "".join(lines)

text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

grep -c 'no-map;' "$dts_path"
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 "qcom/${dtb_name}.dtb"
dtb_built="$out_dir/arch/arm64/boot/dts/qcom/${dtb_name}.dtb"
test -s "$dtb_built"

mkdir -p "$package"
install -m0644 "$dtb_built" "$package/${dtb_name}.dtb"
install -m0644 "$dts_path" "$package/sm8250-lenovo-tb371fc-archsafe.dts.built"
{
	echo 'TB371FC Linux 6.12 r50 -- remote-processor reserved-memory nodes added to community DTS'
	echo 'Base DTS: sm8250-lenovo-tb371fc-archsafe-microsd.dts (includes archsafe.dts)'
	echo 'Same fixed-address no-map regions as stock lenovo-tb371fc.dts, verbatim addresses/sizes'
	echo 'No kernel Image change; reuses the unmodified r47 Image (checkpoint after paging_init(), no TLB fix)'
	sha256sum "$package/${dtb_name}.dtb"
} >"$package/BUILD-INFO.txt"
cat "$package/BUILD-INFO.txt"
