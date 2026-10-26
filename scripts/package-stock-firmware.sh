#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: package-stock-firmware.sh NON_HLOS_DIR VENDOR_FIRMWARE_DIR BLUETOOTH_DIR [OUTPUT_DIR [WLAN_CONFIG]]

Build a Linux firmware tree from locally extracted TB371FC ZUI 16.0.474 images.
No proprietary files are downloaded or added to Git by this script.
EOF
}

if (( $# < 3 || $# > 5 )); then
	usage >&2
	exit 2
fi

non_hlos_dir=$(realpath "$1")
vendor_firmware_dir=$(realpath "$2")
bluetooth_dir=$(realpath "$3")
output_dir=${4:-firmware}
mkdir -p "$output_dir"
output_dir=$(realpath "$output_dir")
wlan_config=
if (( $# == 5 )); then
	wlan_config=$(realpath "$5")
fi

require_file() {
	if [[ ! -f "$1" ]]; then
		echo "Missing required stock firmware: $1" >&2
		exit 1
	fi
}

verify_sha256() {
	local path=$1 expected=$2 actual
	require_file "$path"
	actual=$(sha256sum "$path" | cut -d' ' -f1)
	if [[ $actual != "$expected" ]]; then
		echo "Unexpected SHA-256 for $path" >&2
		echo "Expected: $expected" >&2
		echo "Actual:   $actual" >&2
		exit 1
	fi
}

install_file() {
	local source=$1 destination=$2
	require_file "$source"
	install -Dm0644 "$source" "$output_dir/$destination"
}

# Qualcomm remote processors. The mainline MDT loader requests an .mbn metadata
# file and then loads the sibling .bXX segments.
for subsystem in adsp cdsp slpi; do
	remote_dir="qcom/sm8250/lenovo/tb371fc"
	install_file "$non_hlos_dir/$subsystem.mdt" "$remote_dir/$subsystem.mbn"
	found_segment=false
	for segment in "$non_hlos_dir/$subsystem".b[0-9][0-9]; do
		[[ -f "$segment" ]] || continue
		found_segment=true
		install_file "$segment" "$remote_dir/$(basename "$segment")"
	done
	if [[ $found_segment != true ]]; then
		echo "No $subsystem.bXX segments found in $non_hlos_dir" >&2
		exit 1
	fi
done

# Adreno 650 firmware. The zap metadata/segments are device-specific; SQE and
# GMU are requested by the MSM Adreno driver by these conventional names.
install_file "$vendor_firmware_dir/a650_sqe.fw" "qcom/a650_sqe.fw"
install_file "$vendor_firmware_dir/a650_gmu.bin" "qcom/a650_gmu.bin"
install_file "$vendor_firmware_dir/a650_zap.mdt" "qcom/sm8250/lenovo/tb371fc/a650_zap.mbn"
for segment in "$vendor_firmware_dir"/a650_zap.b[0-9][0-9]; do
	[[ -f "$segment" ]] || continue
	install_file "$segment" "qcom/sm8250/lenovo/tb371fc/$(basename "$segment")"
done

# QCA6390 WLAN. board-2.bin is intentionally not fabricated from an arbitrary
# bdwlan.eXX file; install the linux-firmware board database separately.
install_file "$non_hlos_dir/qca6390/amss20.bin" "ath11k/QCA6390/hw2.0/amss.bin"
install_file "$non_hlos_dir/qca6390/m3.bin" "ath11k/QCA6390/hw2.0/m3.bin"
install_file "$non_hlos_dir/qca6390/regdb.bin" "ath11k/QCA6390/hw2.0/regdb.bin"

# Lenovo's downstream CNSS2/QCACLD stack does not consume mainline's
# board-2.bin database.  Firmware reports a board ID over QMI and CNSS2 then
# requests the matching bdwlan.elf/bdwlan.eXX file verbatim.  Preserve the
# complete signed stock set in its native qca6390/ namespace so a diagnostic
# vendor-kernel initramfs can satisfy that request without guessing an ID.
bdf_count=0
for bdf in "$non_hlos_dir/qca6390"/bdwlan.*; do
	[[ -f $bdf ]] || continue
	install_file "$bdf" "qca6390/$(basename "$bdf")"
	((bdf_count += 1))
done
if (( bdf_count == 0 )); then
	echo "No QCA6390 bdwlan board-data files found" >&2
	exit 1
fi

# QCACLD requests this Android configuration through the normal Linux
# firmware loader after CNSS reports FW_READY. It is device configuration,
# not part of the QCA6390 executable firmware/BDF handshake above.
if [[ -n $wlan_config ]]; then
	verify_sha256 "$wlan_config" \
		"ceebfa9bd1226ec748ecf28c5ed5543cb184fd8a55dd34ac1611300903598b17"
	install_file "$wlan_config" "wlan/qca_cld/WCNSS_qcom_cfg.ini"
fi

# Mainline btqca derives these exact names from the QCA6390 ROM revision.
for name in htbtfw10.tlv htbtfw20.tlv htnv10.bin htnv20.bin; do
	install_file "$bluetooth_dir/$name" "qca/$name"
done

# Keep stock touch/audio payloads in a device-specific namespace until their
# upstream driver filename contracts are finalized.
verify_sha256 "$vendor_firmware_dir/tfa98xx_YC.cnt" \
	"8e7d4a1c4d9587382150cd949e202100d64e17447719a6b6efdb7611ffb952f5"
verify_sha256 "$vendor_firmware_dir/tfa98xx_QS.cnt" \
	"a3f641609cbb617ea2c3169e5a9edc6c04f89a342e99fd96dacc44f216cdfa81"

for name in \
	novatek_ts_fw_boe.bin novatek_ts_fw_boe_6.bin \
	novatek_ts_mp_boe.bin novatek_ts_mp_boe_6.bin \
	novatek_ts_tm_fw.bin novatek_ts_tm_fw_6.bin \
	novatek_ts_tm_mp.bin novatek_ts_tm_mp_6.bin \
	tfa98xx_QS.cnt tfa98xx_YC.cnt; do
	install_file "$vendor_firmware_dir/$name" "lenovo/tb371fc/$name"
done

echo "TB371FC stock firmware tree created at $output_dir"
echo "Install a compatible ath11k/QCA6390/hw2.0/board-2.bin from linux-firmware."
echo "Preserved $bdf_count stock CNSS2 QCA6390 board-data files."
