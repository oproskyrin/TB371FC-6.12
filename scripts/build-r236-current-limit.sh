#!/bin/bash
# Compile prototype only. No tablet copy, loading or installation.
set -euo pipefail
src=/root/tb371fc/linux-6.12.114-r200
base=/root/tb371fc/build-6.12.114-r200
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r233-sink-test.XXXXXX)
cp "$src/drivers/usb/typec/tcpm/qcom/"*.c "$src/drivers/usb/typec/tcpm/qcom/"*.h "$work/"
cp "$src/drivers/usb/typec/tcpm/tcpm.c" "$work/"
cp "$p/scripts/r232-dp-prep/sink-test.Kbuild" "$work/Makefile"
python3 "$p/scripts/r232-dp-prep/prepare-sink-test.py" "$work"
cp "$p/scripts/r236-current-limit/"*.h "$p/scripts/r236-current-limit/"*.inc "$work/"
python3 "$p/scripts/r236-current-limit/prepare.py" "$work"
clang-18 -Wall -Wextra -Werror "$p/scripts/r236-current-limit/test-policy.c" -o "$work/test-policy"
"$work/test-policy"
clang-18 -Wall -Wextra -Werror "$p/scripts/r236-current-limit/test-transaction.c" -o "$work/test-transaction"
"$work/test-transaction"
make -C "$base" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
dest=/mnt/d/TB371FC-builds/r236-current-limit
mkdir -p "$dest"
cp "$work/"*.ko "$dest/"
sha256sum "$dest/"*.ko
echo "PRIVATE BUILD $work"
