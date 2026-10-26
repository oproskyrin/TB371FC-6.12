#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
base=${BASE_KERNEL_DIR:-/root/tb371fc-linux-7.1.7-full-panel-verify}
source_tree=${1:-${KERNEL_DIR:-/root/tb371fc-linux-7.1.7-longwrite-repro}}
out_dir=${2:-${OUT_DIR:-/root/tb371fc-linux-7.1.7-longwrite-repro-out}}

(( $# <= 2 )) || {
	echo "Usage: $0 [KERNEL_DIR [OUT_DIR]]" >&2
	exit 2
}

if [[ ! -e $source_tree/.git ]]; then
	(( $# == 0 )) || {
		echo "Explicit kernel tree does not exist: $source_tree" >&2
		exit 1
	}
	git -C "$base" worktree add --detach "$source_tree" HEAD
fi

KERNEL_DIR="$source_tree" OUT_DIR="$out_dir" \
	BUILD_TARGETS='drivers/gpu/drm/panel/panel-novatek-nt36523.o qcom/sm8250-lenovo-tb371fc-display-test.dtb' \
	"$project_dir/scripts/build-kernel.sh"

"$project_dir/scripts/verify-mainline-panel-order.py" "$source_tree"

object="$out_dir/drivers/gpu/drm/panel/panel-novatek-nt36523.o"
dtb="$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-display-test.dtb"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
install -m0644 "$object" "$stage/panel.o"
aarch64-linux-gnu-objcopy --strip-debug "$stage/panel.o"

actual=$(sha256sum "$stage/panel.o" | cut -d' ' -f1)
kernel_release=$(make -s -C "$source_tree" O="$out_dir" ARCH=arm64 \
	CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= kernelrelease)
case "$kernel_release" in
	7.1.7-tb371fc*)
		expected_stripped_sha256=ae7502e9ae8b3456851027fff73790fbe501091c7ee48bca2201939ea6822a57
		expected_dtb_sha256=d41d9d67366c0a38a83317baf4b7d8c15854b05fd9e10947f45714d89808d9a9
		;;
	7.1.8-tb371fc*)
		expected_stripped_sha256=9188b7d7a231f5441e759e2923f08efac4656abf794c70c93ccf4ac60958a5a4
		expected_dtb_sha256=69f68b1a30796986f1676c60faad11a0be8a861278f21e364c6af01eaf18182d
		;;
	*)
		echo "No pinned panel reference for kernel release: $kernel_release" >&2
		exit 1
		;;
esac
[[ $actual == "$expected_stripped_sha256" ]] || {
	echo "Unexpected stripped panel object: $actual" >&2
	exit 1
}

file "$object" | grep -q 'ELF 64-bit LSB relocatable, ARM aarch64'
test "$(sha256sum "$dtb" | cut -d' ' -f1)" = "$expected_dtb_sha256"

echo "Verified reproducible $kernel_release panel ordering, ARM64 object and DTB."
sha256sum "$stage/panel.o" "$dtb"
