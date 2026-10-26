#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 EXTRACTED_CAMERA_METADATA_DIR" >&2
	exit 2
fi

metadata_dir=$(realpath "$1")
manifest="$metadata_dir/SHA256SUMS"
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f $manifest ]] || {
	echo "Missing camera metadata manifest: $manifest" >&2
	exit 1
}

(
	cd "$metadata_dir"
	sha256sum -c SHA256SUMS >&2
)

echo "== file types =="
file \
	"$metadata_dir"/bin/init.dtab.camera.sh \
	"$metadata_dir"/bin/hw/android.hardware.camera.provider@2.4-service_64 \
	"$metadata_dir"/lib64/camera/* \
	"$metadata_dir"/lib64/hw/camera.qcom.so

echo
echo "== verified CamX sensor probe prefixes =="
for module in "$metadata_dir"/lib64/camera/com.qti.sensormodule.AX6637_*.bin; do
	python3 "$project_dir/scripts/decode-camx-sensor-probe.py" "$module"
done

echo
echo "== init.dtab.camera.sh =="
sed -n '1,240p' "$metadata_dir/bin/init.dtab.camera.sh"

echo
echo "== defined sensor-library symbols =="
for library in "$metadata_dir"/lib64/camera/com.qti.sensor*.so; do
	echo "--- $(basename "$library")"
	readelf -Ws "$library" |
		awk '$7 != "UND" && ($4 == "FUNC" || $4 == "OBJECT") { print }'
done

echo
echo "== targeted printable strings =="
find "$metadata_dir/lib64/camera" -maxdepth 1 -type f -print0 |
	sort -z |
	while IFS= read -r -d '' camera_file; do
		echo "--- $(basename "$camera_file")"
		strings -a -n 4 "$camera_file" |
			grep -Eai 'AX6637|s5k4h7|gc08a3|hi1339|slave|sensor|i2c|lane|resolution|width|height|module|eeprom|actuator|power|gpio|mclk' |
			sort -u || true
	done

echo
echo "== sensormodule headers and selected string offsets =="
for module in "$metadata_dir"/lib64/camera/com.qti.sensormodule.AX6637_*.bin; do
	echo "--- $(basename "$module")"
	xxd -g 4 -l 256 "$module"
	strings -a -t x "$module" |
		grep -Ea 'AX6637_|sensorDriverData|cameraModuleData|sensorName|sensorSlaveAddress|sensorId(RegAddr)?|laneAssign|resolutionInfo' |
		head -n 80 || true
done
