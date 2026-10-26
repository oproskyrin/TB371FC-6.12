#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r56
kernel_dir=/root/tb371fc/linux-6.12-donor-r57
out_dir=/root/tb371fc/build-6.12-r57-boot-log-region-reserved-dtb
dtb_name=sm8250-lenovo-tb371fc-archsafe-microsd
dts_path="$kernel_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-archsafe.dts"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb

test -d "$source_dir/.git"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"

# The shared r47 donor tree's DTS was permanently modified in place by r50
# (19 stock reserved-memory regions added) and every rXX since has copied
# from it, so this fresh r57 copy's DTS also carries that 19-region
# edit. r57 needs a much narrower, targeted test: revert to the plain
# community baseline (cont_splash_mem only) and add ONLY boot_log_region,
# the single region the r56 hardware test's framebuffer colour diagnostic
# identified as the last region being mapped when execution hung (colour
# read back as pure red, matching 0xb0000000's encoding). boot_log_region
# is not reserved in the community DTS at all; it is the exact physical
# region V56.6's autonomous snapshot-log feature actively writes to, and
# is a strong, specific, well-motivated candidate for a live-kexec-only
# mapping conflict (matching the r48 cold-boot-succeeds finding, since
# nothing would be writing there on a cold boot).
python3 - "$dts_path" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

# Revert r50's 19-region edit back to the plain single-node baseline.
stock_regions_needle_start = "\t\txbl_aop_region: memory@80700000 {\n"
stock_regions_needle_end = "\t\tboot_log_region: memory@b0000000 {\n\t\t\treg = <0x0 0xb0000000 0x0 0x80000>;\n\t\t\tno-map;\n\t\t};\n"
start_idx = text.find(stock_regions_needle_start)
end_marker_idx = text.find(stock_regions_needle_end)
assert start_idx != -1, "r50's first added region (xbl_aop_region) not found -- DTS may already be reverted or different"
assert end_marker_idx != -1, "r50's last added region (boot_log_region) not found"
end_idx = end_marker_idx + len(stock_regions_needle_end)
removed = text[start_idx:end_idx]
assert removed.count("no-map;") == 19, f"expected to remove exactly 19 no-map regions, found {removed.count('no-map;')}"
text = text[:start_idx] + text[end_idx:]

# Confirm we are back to the plain single-node baseline.
plain_needle = (
	"\treserved-memory {\n"
	"\t\tcont_splash_mem: memory@9c000000 {\n"
	"\t\t\treg = <0x0 0x9c000000 0x0 0x2300000>;\n"
	"\t\t\tno-map;\n"
	"\t\t};\n"
	"\t};\n"
)
assert text.count(plain_needle) == 1, "plain baseline reserved-memory node not found after revert"

# Add ONLY boot_log_region (verbatim address/size from the stock decompiled
# DTB, same as used in r50's list).
replacement = (
	"\treserved-memory {\n"
	"\t\tcont_splash_mem: memory@9c000000 {\n"
	"\t\t\treg = <0x0 0x9c000000 0x0 0x2300000>;\n"
	"\t\t\tno-map;\n"
	"\t\t};\n"
	"\t\tboot_log_region: memory@b0000000 {\n"
	"\t\t\treg = <0x0 0xb0000000 0x0 0x80000>;\n"
	"\t\t\tno-map;\n"
	"\t\t};\n"
	"\t};\n"
)
text = text.replace(plain_needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

grep -c 'no-map;' "$dts_path"
test "$(grep -c 'no-map;' "$dts_path")" = "2"

test -f /root/tb371fc/build-6.12-r56-membank-region-fb-color-log/.config
mkdir -p "$out_dir"
cp /root/tb371fc/build-6.12-r56-membank-region-fb-color-log/.config "$out_dir/.config"
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 "qcom/${dtb_name}.dtb"
dtb_built="$out_dir/arch/arm64/boot/dts/qcom/${dtb_name}.dtb"
test -s "$dtb_built"

mkdir -p "$package"
install -m0644 "$dtb_built" "$package/${dtb_name}.dtb"
install -m0644 "$dts_path" "$package/sm8250-lenovo-tb371fc-archsafe.dts.built"
{
	echo 'TB371FC Linux 6.12 r57 -- boot_log_region-only reserved-memory DTS'
	echo 'Base DTS: sm8250-lenovo-tb371fc-archsafe-microsd.dts (includes archsafe.dts)'
	echo 'Reverted r50 19-region edit; added ONLY boot_log_region (0xb0000000, 0x80000)'
	echo 'Targeted by r56 hardware framebuffer-colour diagnostic (pure red = 0xb0000000)'
	echo 'Kernel Image: reuses r56 unmodified (fb-colour diagnostic, no PSCI reset)'
	sha256sum "$package/${dtb_name}.dtb"
} >"$package/BUILD-INFO.txt"
cat "$package/BUILD-INFO.txt"
