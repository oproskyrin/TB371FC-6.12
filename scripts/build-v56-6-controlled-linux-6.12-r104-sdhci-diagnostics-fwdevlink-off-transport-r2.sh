#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r98-fullboot-ufs-disabled-transport-r2.sh"
base_inner='/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2/initramfs-6.12-arch-development.cpio.gz'
inner_out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r104-sdhci-diagnostic-initramfs
inner="$inner_out/initramfs-6.12-r104-sdhci-diagnostics.cpio.gz"
generated=$(mktemp)
stage=$(mktemp -d)
trap 'rm -rf -- "$generated" "$stage"' EXIT

test -s "$template"
test -s "$base_inner"
if test -e "$inner_out"; then
  test -d "$inner_out" || { echo "Refusing non-directory $inner_out" >&2; exit 1; }
  unexpected=$(find "$inner_out" -mindepth 1 -maxdepth 1 ! -name "$(basename "$inner")" -print -quit)
  test -z "$unexpected" || { echo "Refusing unexpected content: $unexpected" >&2; exit 1; }
fi
mkdir -p "$inner_out"
( cd "$stage"; gzip -dc "$base_inner" | cpio -idmu 2>/dev/null || true )
test -x "$stage/bin/boot-arch-development-rootfs"

python3 - "$stage/bin/boot-arch-development-rootfs" <<'PYEOF'
import sys

path = sys.argv[1]
text = open(path, encoding='utf-8').read()
old = '''rescue() {
\techo "Arch development handoff failed: $1" >&2
\techo 'Android partitions were not mounted.' >&2
\techo 'USB NCM rescue shell remains on 169.254.77.2:2323.' >&2
\texec setsid cttyhack sh
}'''
new = '''rescue() {
\techo "Arch development handoff failed: $1" >&2
\techo 'Android partitions were not mounted.' >&2
\techo '=== R104 SDHCI DIAGNOSTICS BEGIN ===' >&2
\techo '--- /proc/cmdline ---' >&2
\tcat /proc/cmdline >&2 2>/dev/null || true
\techo '--- filtered dmesg ---' >&2
\tdmesg 2>/dev/null | grep -iE '8804000|sdhci|mmc|gcc|clock|clk|reset|probe' | busybox tail -n 160 >&2 || true
\techo '--- deferred probes ---' >&2
\tcat /sys/kernel/debug/devices_deferred >&2 2>/dev/null || true
\techo '--- SDHCI device paths and links ---' >&2
\tfind /sys/devices -type d -name '8804000.mmc' 2>/dev/null | while read -r dev; do
\t\techo "DEVICE=$dev" >&2
\t\tls -la "$dev" >&2 2>/dev/null || true
\t\tfor link in "$dev"/supplier:* "$dev"/consumer:*; do
\t\t\t[ -e "$link" ] || continue
\t\t\techo "$link -> $(readlink "$link" 2>/dev/null)" >&2
\t\tdone
\tdone
\techo '=== R104 SDHCI DIAGNOSTICS END ===' >&2
\techo 'USB is intentionally disabled in this headless test.' >&2
\texec setsid cttyhack sh
}'''
assert text.count(old) == 1, 'rescue function anchor changed'
text = text.replace(old, new)
open(path, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
touch -d '@0' "$stage/bin/boot-arch-development-rootfs"
sh -n "$stage/bin/boot-arch-development-rootfs"
grep -Fq 'R104 SDHCI DIAGNOSTICS BEGIN' "$stage/bin/boot-arch-development-rootfs"
grep -Fq 'busybox tail -n 160' "$stage/bin/boot-arch-development-rootfs"
grep -Fq "find /sys/devices -type d -name '8804000.mmc'" "$stage/bin/boot-arch-development-rootfs"
( cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 2>/dev/null | gzip -9n >"$inner" )
inner_sha=$(sha256sum "$inner" | awk '{print $1}')

python3 - "$template" "$generated" "$inner" "$inner_sha" <<'PYEOF'
import sys

src, dst, inner, inner_sha = sys.argv[1:5]
text = open(src, encoding='utf-8').read()
assert text.count('r98') == 7, f'unexpected r98 anchor count: {text.count("r98")}'
text = text.replace('r98', 'r104')

old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r104-ufs-disabled-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb'
assert text.count(old_dtb) == 1, 'r104 DTB path anchor not unique'
text = text.replace(old_dtb, new_dtb)

old = '''Linux 6.12 payload: exact r70 layout-preserving full-boot Image,
full 19-range real-RAM DTB with only UFS host and PHY disabled, and rodata=on.
This preserves the r95-proven paging path while removing the r96 UFS/OPP
-EPROBE_DEFER storm. Internal Android UFS is neither required nor accessed.
The embedded 1 MiB early page-table pool and Arch initramfs are retained.'''
new = '''Linux 6.12 payload: exact r70 layout-preserving Image and exact r101
headless DTB. The second-stage command line contains exactly one fw_devlink=off
token and no permissive token. The r104 inner initramfs uses BusyBox tail and
discovers the actual 8804000.mmc sysfs path before reporting device links.
UFS and USB1 remain disabled and Android partitions are never mounted.'''
assert text.count(old) == 1, 'r104 BUILD-INFO anchor not unique'
text = text.replace(old, new)

# The r98 script generates the final package script from the r64 template.
# Extend that nested transform so the generated helper pins the selected inner
# initramfs hash and carries one unambiguous fw_devlink mode.
write_anchor = "open(dst, 'w', encoding='utf-8', newline='\\n').write(text)"
assert text.count(write_anchor) == 1, 'nested generator write anchor changed'
injected = f'''inner_path_anchor = 'linux612_initrd=$diag39/initramfs-6.12-arch-development.cpio.gz'\nassert text.count(inner_path_anchor) == 1, 'inner initramfs path anchor changed'\ntext = text.replace(inner_path_anchor, "linux612_initrd={inner!r}")\ninner_sha_anchor = 'c807299d26b83c2d585a1ae8402dfbb68852a647ed153bf190123e9a7048dd9c'\nassert text.count(inner_sha_anchor) == 1, 'inner initramfs verifier anchor changed'\ntext = text.replace(inner_sha_anchor, {inner_sha!r})\nhelper_anchor = 'chmod 0755 "$stage/bin/load-linux-6.12-r38"\\n'\nassert text.count(helper_anchor) == 1, 'load helper chmod anchor changed'\nhelper_fix = helper_anchor + "sed -i 's/fw_devlink=permissive/fw_devlink=off/' \\\"$stage/bin/load-linux-6.12-r38\\\"\\n" + "sed -i 's/c807299d26b83c2d585a1ae8402dfbb68852a647ed153bf190123e9a7048dd9c/{inner_sha}/' \\\"$stage/bin/load-linux-6.12-r38\\\"\\n" + "test \\\"$(grep -o 'fw_devlink=off' \\\"$stage/bin/load-linux-6.12-r38\\\" | wc -l)\\\" = 1\\n" + "! grep -Fq 'fw_devlink=permissive' \\\"$stage/bin/load-linux-6.12-r38\\\"\\n" + "grep -Fq '{inner_sha}' \\\"$stage/bin/load-linux-6.12-r38\\\"\\n"\ntext = text.replace(helper_anchor, helper_fix)\nfor stale_assert in (\n    "grep -Fq 'TB371FC_SERIAL_SSH_SESSION_TIMEOUT:-300' \\\"$stage/bin/tb371fc-development-init-runtime\\\"\\n",\n    "grep -Fq '__TB371FC_SSH_STREAM_CLOSED__' \\\"$stage/bin/tb371fc-development-init-runtime\\\"\\n",\n):\n    assert text.count(stale_assert) == 1, 'stale runtime assertion anchor changed'\n    text = text.replace(stale_assert, '')\n'''
text = text.replace(write_anchor, injected + write_anchor)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
printf 'INNER_INITRAMFS_SHA256=%s\n' "$inner_sha"
