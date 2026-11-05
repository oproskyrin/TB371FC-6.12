#!/bin/bash
# Offline compile check only. Never installs or loads modules.
set -euo pipefail
src=/root/tb371fc/linux-6.12.114-r200
out=/root/tb371fc/build-6.12.114-r200
dest=/mnt/d/TB371FC-builds/r232-dp-prep
work=$(mktemp -d /root/tb371fc/r232-dp-prep.XXXXXX)
cp "$src/drivers/usb/typec/altmodes/displayport.c" "$work/typec_displayport.c"
cp "$src/drivers/usb/typec/altmodes/displayport.h" "$work/"
cp "$src/drivers/usb/typec/mux/fsa4480.c" "$work/"
cp "$dest/ps5169.c" "$work/"
cp '/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo/scripts/r232-dp-prep/Makefile' "$work/"
cp '/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo/scripts/r232-dp-prep/compat-6.12.h' "$work/"
echo "Offline build directory: $work"
make -C "$out" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
mkdir -p "$dest/modules"
cp "$work/"*.ko "$dest/modules/"
sha256sum "$dest/modules/"*.ko
