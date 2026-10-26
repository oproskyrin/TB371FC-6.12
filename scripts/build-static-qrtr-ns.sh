#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
	echo "Usage: $0 QRTR_SOURCE NS_OUTPUT [LOOKUP_OUTPUT]" >&2
	exit 2
fi

source_dir=$(realpath "$1")
output=$(realpath -m "$2")
lookup_output=
if (( $# == 3 )); then
	lookup_output=$(realpath -m "$3")
fi
expected_commit=8f9b2bc3b60f59ecc9e6193764fa885cdef7f0ce

[[ $(git -C "$source_dir" rev-parse HEAD) == "$expected_commit" ]] || {
	echo "QRTR source must be the audited v1.1 commit $expected_commit" >&2
	exit 1
}
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing output: $output" >&2
	exit 1
}
if [[ -n $lookup_output && -e $lookup_output ]]; then
	echo "Refusing to overwrite existing output: $lookup_output" >&2
	exit 1
fi

mkdir -p "$(dirname "$output")"
if [[ -n $lookup_output ]]; then
	mkdir -p "$(dirname "$lookup_output")"
fi
output_tmp=$(mktemp "$(dirname "$output")/.qrtr-ns.XXXXXX")
lookup_tmp=
cleanup() {
	rm -f -- "$output_tmp"
	[[ -z $lookup_tmp ]] || rm -f -- "$lookup_tmp"
}
trap cleanup EXIT

aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra \
	-I"$source_dir/include" -I"$source_dir/src" \
	"$source_dir/src/addr.c" \
	"$source_dir/src/hash.c" \
	"$source_dir/src/map.c" \
	"$source_dir/src/ns.c" \
	"$source_dir/src/util.c" \
	"$source_dir/src/waiter.c" \
	"$source_dir/lib/logging.c" \
	"$source_dir/lib/qmi.c" \
	"$source_dir/lib/qrtr.c" \
	-o "$output_tmp"

file "$output_tmp" | grep -q 'ELF 64-bit.*ARM aarch64.*statically linked' || {
	echo "qrtr-ns is not a static AArch64 executable" >&2
	exit 1
}
mv -T "$output_tmp" "$output"
echo "Static QRTR name service: $output"
sha256sum "$output"

if [[ -n $lookup_output ]]; then
	lookup_tmp=$(mktemp "$(dirname "$lookup_output")/.qrtr-lookup.XXXXXX")
	aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra \
		-I"$source_dir/include" -I"$source_dir/src" \
		"$source_dir/src/lookup.c" \
		"$source_dir/lib/logging.c" \
		"$source_dir/lib/qmi.c" \
		"$source_dir/lib/qrtr.c" \
		-o "$lookup_tmp"
	file "$lookup_tmp" | grep -q 'ELF 64-bit.*ARM aarch64.*statically linked' || {
		echo "qrtr-lookup is not a static AArch64 executable" >&2
		exit 1
	}
	mv -T "$lookup_tmp" "$lookup_output"
	echo "Static QRTR lookup tool: $lookup_output"
	sha256sum "$lookup_output"
fi
