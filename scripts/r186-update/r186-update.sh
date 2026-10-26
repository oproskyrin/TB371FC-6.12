#!/bin/sh
# R186: full Arch Linux ARM upgrade of the persistent root (run as root on the tablet, logs to /var/log).
# Keeps the Lenovo Wi-Fi/BT firmware (pacman NoUpgrade) and skips the unused linux-aarch64 kernel
# (Linux 6.12 boots from the microSD payload, not from /boot).
set -eu
conf=/etc/pacman.conf
fw='usr/lib/firmware/ath11k/QCA6390/hw2.0/amss.bin usr/lib/firmware/ath11k/QCA6390/hw2.0/m3.bin usr/lib/firmware/qca/htbtfw20.tlv usr/lib/firmware/qca/htnv20.bin'
grep -q '^NoUpgrade *=.*htnv20.bin' $conf || sed -i "/^\[options\]/a NoUpgrade = $fw" $conf
grep -q '^IgnorePkg *=.*linux-aarch64' $conf || sed -i "/^\[options\]/a IgnorePkg = linux-aarch64 linux-aarch64-headers" $conf
grep -E '^(NoUpgrade|IgnorePkg)' $conf
mkdir -p /var/lib/tb371fc/fw-lenovo
for f in $fw; do cp -a "/$f" /var/lib/tb371fc/fw-lenovo/; done
sha256sum /var/lib/tb371fc/fw-lenovo/*
date
pacman -Sy --noconfirm archlinux-keyring archlinuxarm-keyring
pacman -Su --noconfirm
date
# the Lenovo firmware must be unchanged
for f in $fw; do cmp "/$f" "/var/lib/tb371fc/fw-lenovo/$(basename $f)" && echo "kept $f"; done
ls /usr/lib/firmware/ath11k/QCA6390/hw2.0/*.pacnew /usr/lib/firmware/qca/*.pacnew 2>/dev/null || true
find /etc -name '*.pacnew' 2>/dev/null
echo R186_UPDATE_DONE
