#!/system/bin/sh
set -u

out=/data/local/tmp/tb371fc-root-reference
dbg=$out/debugfs
rm -rf "$out"
mkdir -p "$out" "$dbg"

capture() {
	name=$1
	shift
	"$@" >"$out/$name.txt" 2>&1 || true
}

capture_sh() {
	name=$1
	shift
	sh -c "$*" >"$out/$name.txt" 2>&1 || true
}

capture identity id
capture uname uname -a
capture cmdline cat /proc/cmdline
capture bootconfig cat /proc/bootconfig
capture getprop getprop
capture mounts cat /proc/mounts
capture filesystems cat /proc/filesystems
capture modules cat /proc/modules
capture interrupts cat /proc/interrupts
capture iomem cat /proc/iomem
capture meminfo cat /proc/meminfo
capture cpuinfo cat /proc/cpuinfo
capture_sh sysfs_classes 'find /sys/class -maxdepth 3 -type l -o -type f 2>/dev/null | sort'
capture_sh platform_devices 'find /sys/devices/platform -maxdepth 4 -type d 2>/dev/null | sort'
capture_sh firmware_manifest 'find /vendor/firmware /vendor/etc/firmware /odm/firmware -type f -printf "%p %s\n" 2>/dev/null | sort'
capture_sh vendor_hardware_configs 'find /vendor/etc /odm/etc -maxdepth 4 -type f 2>/dev/null | grep -Ei "display|panel|camera|media|audio|bluetooth|wifi|wlan|touch|pen|sensor|usb|typec" | sort'

capture surfaceflinger dumpsys SurfaceFlinger
capture surfaceflinger_displays dumpsys SurfaceFlinger --display-id
capture display_service dumpsys display
capture power_service dumpsys power
capture battery dumpsys battery
capture usb_service dumpsys usb
capture media_camera dumpsys media.camera
capture sensorservice dumpsys sensorservice
capture input_service dumpsys input
capture audio_service dumpsys audio
capture bluetooth_manager dumpsys bluetooth_manager
capture wifi_service dumpsys wifi
capture lshal lshal
capture service_list service list
capture input_devices getevent -lp
capture dmesg dmesg
capture logcat_all logcat -b all -d

capture_sh drm_sysfs 'for x in /sys/class/drm/*; do echo "### $x"; find "$x" -maxdepth 1 -type f -exec sh -c '\''for f; do echo "## $f"; cat "$f" 2>/dev/null; done'\'' sh {} +; done'
capture_sh graphics_sysfs 'for x in /sys/class/graphics/*; do echo "### $x"; find "$x" -maxdepth 1 -type f -exec sh -c '\''for f; do echo "## $f"; cat "$f" 2>/dev/null; done'\'' sh {} +; done'
capture_sh backlight_sysfs 'for x in /sys/class/backlight/*; do echo "### $x"; find "$x" -maxdepth 1 -type f -exec sh -c '\''for f; do echo "## $f"; cat "$f" 2>/dev/null; done'\'' sh {} +; done'
capture_sh typec_sysfs 'find /sys/class/typec -maxdepth 4 -type f -exec sh -c '\''for f; do echo "## $f"; cat "$f" 2>/dev/null; done'\'' sh {} +'
capture_sh power_supply_sysfs 'find /sys/class/power_supply -maxdepth 3 -type f -exec sh -c '\''for f; do echo "## $f"; cat "$f" 2>/dev/null; done'\'' sh {} +'
capture_sh thermal_sysfs 'for x in /sys/class/thermal/thermal_zone*; do echo "### $x"; cat "$x/type" "$x/temp" 2>/dev/null; done'
capture_sh devfreq_sysfs 'for x in /sys/class/devfreq/*; do echo "### $x"; cat "$x/name" "$x/available_frequencies" "$x/cur_freq" "$x/min_freq" "$x/max_freq" 2>/dev/null; done'
capture_sh rfkill_sysfs 'for x in /sys/class/rfkill/*; do echo "### $x"; cat "$x/name" "$x/type" "$x/state" "$x/soft" "$x/hard" 2>/dev/null; done'
capture_sh net_sysfs 'for x in /sys/class/net/*; do echo "### $x"; cat "$x/address" "$x/operstate" "$x/mtu" 2>/dev/null; done'

debugfs_mounted=0
if grep -qw debugfs /proc/filesystems; then
	if mount -t debugfs debugfs "$dbg" 2>"$out/debugfs-mount-error.txt"; then
		debugfs_mounted=1
		capture_sh debugfs_tree "find '$dbg' -maxdepth 5 -type f 2>/dev/null | sort"
		capture_sh dri_state "cat '$dbg'/dri/0/state 2>/dev/null"
		capture_sh dsi_ctrl_regs "for f in '$dbg'/dri/0/debug/dsi*_ctrl_reg; do echo \"### \$f\"; timeout 5 cat \"\$f\"; done"
		capture_sh dsi_phy_regs "for f in '$dbg'/dri/0/debug/dsi*_phy_reg; do echo \"### \$f\"; timeout 5 cat \"\$f\"; done"
		capture_sh crtc_status "for f in '$dbg'/dri/0/crtc*/status; do echo \"### \$f\"; timeout 5 cat \"\$f\"; done"
		capture_sh encoder_status "for f in '$dbg'/dri/0/encoder*/status; do echo \"### \$f\"; timeout 5 cat \"\$f\"; done"
		capture_sh clk_summary "cat '$dbg'/clk/clk_summary 2>/dev/null"
		capture_sh regulator_summary "cat '$dbg'/regulator/regulator_summary 2>/dev/null"
		capture_sh gpio "cat '$dbg'/gpio 2>/dev/null"
		capture_sh genpd "cat '$dbg'/pm_genpd/pm_genpd_summary 2>/dev/null"
	fi
fi

if [ -r /sys/firmware/fdt ]; then
	cp /sys/firmware/fdt "$out/running-fdt.dtb" 2>/dev/null || true
fi
if [ -d /proc/device-tree ]; then
	tar -C /proc -czf "$out/proc-device-tree.tar.gz" device-tree 2>/dev/null || true
fi

printf 'debugfs_mounted=%s\n' "$debugfs_mounted" >"$out/collection-status.txt"
if [ "$debugfs_mounted" -eq 1 ]; then
	umount "$dbg" 2>/dev/null || true
fi

archive=/data/local/tmp/tb371fc-root-reference.tar.gz
rm -f "$archive"
tar -C /data/local/tmp -czf "$archive" tb371fc-root-reference
sha256sum "$archive"
ls -l "$archive"
