#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# < 4 || $# > 6 )); then
	echo "Usage: $0 INPUT_INITRAMFS FIRMWARE_DIR REBOOT_MODULE OUTPUT_INITRAMFS [QRTR_NS [QRTR_LOOKUP]]" >&2
	exit 2
fi
qrtr_lookup=
if (( $# == 6 )); then
	qrtr_lookup=$(realpath "$6")
	file "$qrtr_lookup" | grep -q 'ELF 64-bit.*ARM aarch64.*statically linked' || {
		echo "QRTR_LOOKUP is not a static AArch64 executable: $qrtr_lookup" >&2
		exit 1
	}
fi
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

input=$(realpath "$1")
firmware=$(realpath "$2")
reboot_module=$(realpath "$3")
output=$(realpath -m "$4")
qrtr_ns=
if (( $# >= 5 )); then
	qrtr_ns=$(realpath "$5")
	file "$qrtr_ns" | grep -q 'ELF 64-bit.*ARM aarch64.*statically linked' || {
		echo "QRTR_NS is not a static AArch64 executable: $qrtr_ns" >&2
		exit 1
	}
fi
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing initramfs: $output" >&2
	exit 1
}

required=(
	ath11k/QCA6390/hw2.0/amss.bin
	ath11k/QCA6390/hw2.0/m3.bin
	ath11k/QCA6390/hw2.0/regdb.bin
	lenovo/tb371fc/novatek_ts_fw_boe_6.bin
	lenovo/tb371fc/novatek_ts_tm_fw_6.bin
	lenovo/tb371fc/novatek_ts_mp_boe_6.bin
	lenovo/tb371fc/novatek_ts_tm_mp_6.bin
	qca/htbtfw20.tlv
	qca/htnv20.bin
	qca6390/bdwlan.elf
	wlan/qca_cld/WCNSS_qcom_cfg.ini
)
for path in "${required[@]}"; do
	[[ -s $firmware/$path ]] || {
		echo "Required firmware is missing: $firmware/$path" >&2
		exit 1
	}
done
[[ -s $reboot_module ]] || {
	echo "Reboot module is missing or empty: $reboot_module" >&2
	exit 1
}

stage=$(mktemp -d)
output_tmp=$(mktemp "$(dirname "$output")/.tb371fc-vendor-fw.XXXXXX")
cleanup() {
	rm -rf -- "$stage"
	rm -f -- "$output_tmp"
}
trap cleanup EXIT

(
	cd "$stage"
	gzip -dc "$input" | cpio -idmu 2>/dev/null
)

install -d "$stage/lib/firmware/qca6390" "$stage/lib/firmware/qca"
install -m0644 "$firmware/ath11k/QCA6390/hw2.0/amss.bin" \
	"$stage/lib/firmware/qca6390/amss20.bin"
install -m0644 "$firmware/ath11k/QCA6390/hw2.0/m3.bin" \
	"$stage/lib/firmware/qca6390/m3.bin"
install -m0644 "$firmware/ath11k/QCA6390/hw2.0/regdb.bin" \
	"$stage/lib/firmware/qca6390/regdb.bin"
expected_wlan_ini_sha256=ceebfa9bd1226ec748ecf28c5ed5543cb184fd8a55dd34ac1611300903598b17
actual_wlan_ini_sha256=$(sha256sum "$firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini" | awk '{print $1}')
[[ $actual_wlan_ini_sha256 == "$expected_wlan_ini_sha256" ]] || {
	echo "Unexpected WCNSS_qcom_cfg.ini SHA-256: $actual_wlan_ini_sha256" >&2
	exit 1
}
install -Dm0644 "$firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini" \
	"$stage/lib/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini"
for bdf in "$firmware/qca6390"/bdwlan.*; do
	[[ -s $bdf ]] || continue
	install -m0644 "$bdf" "$stage/lib/firmware/qca6390/$(basename "$bdf")"
done
install -m0644 "$firmware/qca/htbtfw20.tlv" \
	"$stage/lib/firmware/qca/htbtfw20.tlv"
install -m0644 "$firmware/qca/htnv20.bin" \
	"$stage/lib/firmware/qca/htnv20.bin"

for name in novatek_ts_fw_boe_6.bin novatek_ts_tm_fw_6.bin \
	novatek_ts_mp_boe_6.bin novatek_ts_tm_mp_6.bin; do
	install -m0644 "$firmware/lenovo/tb371fc/$name" \
		"$stage/lib/firmware/$name"
done

kernel_release=4.19.325-cip134-st18-perf+
install -d "$stage/lib/modules/$kernel_release/extra"
install -m0644 "$reboot_module" \
	"$stage/lib/modules/$kernel_release/extra/reboot-bootloader.ko"
ln -sf busybox "$stage/bin/insmod"
if [[ -n $qrtr_ns ]]; then
	install -m0755 "$qrtr_ns" "$stage/bin/qrtr-ns"
fi
if [[ -n $qrtr_lookup ]]; then
	install -m0755 "$qrtr_lookup" "$stage/bin/qrtr-lookup"
fi
for helper in collect-hardware-snapshot start-qrtr-diagnostics \
	stop-qrtr-diagnostics capture-input-events activate-wlan-once \
	return-to-bootloader; do
	install -m0755 "$repo_dir/initramfs/$helper" "$stage/bin/$helper"
done

(
	cd "$stage"
	find . -print0 | sort -z |
		cpio --null -o --format=newc --owner=0:0 2>/dev/null |
		gzip -9n >"$output_tmp"
)
mv -T "$output_tmp" "$output"
gzip -t "$output"
echo "Vendor-firmware diagnostic initramfs: $output"
sha256sum "$output"
