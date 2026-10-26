#!/bin/sh
# Read-only survey: do not dump credentials or network profiles.
set -u
uname -a
cat /proc/sys/kernel/random/boot_id /proc/cmdline
findmnt -no SOURCE,FSTYPE,OPTIONS /
ls -l /dev/dri /dev/dri/by-path
pacman -Q kwin plasma-workspace mesa vulkan-freedreno libdrm 2>/dev/null
systemctl cat r149-plasma.service
systemctl is-active r149-plasma.service r130-sshd.service NetworkManager bluetooth
find /sys/firmware/devicetree/base -maxdepth 3 -iname '*gpu*' -o -iname '*gmu*'
for p in /proc/device-tree/soc@0/gpu@3d00000/status /proc/device-tree/soc@0/display-subsystem@ae00000/status; do
    printf '\n%s: ' "$p"; tr -d '\000' < "$p" 2>/dev/null; printf '\n'
done
ls -l /sys/bus/platform/devices/3d00000.gpu/driver 2>/dev/null
ls -l /usr/lib/firmware/qcom/a650* /usr/lib/firmware/qcom/sm8250/*zap* 2>/dev/null
sha256sum /usr/lib/firmware/qcom/a650_sqe.fw /usr/lib/firmware/qcom/a650_gmu.bin 2>/dev/null
ps -eo pid,comm,args | grep -E 'kwin_wayland|plasmashell|Xwayland' | grep -v grep
journalctl -b --no-pager -u r149-plasma.service -n 65
dmesg | grep -iE 'adreno|gpu|gmu|drm|smmu|fault|oops' | tail -65
find /run -maxdepth 2 -name '*r17*' -o -name '*r18*'
df -h / /run
