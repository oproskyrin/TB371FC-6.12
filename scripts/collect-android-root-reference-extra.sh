#!/system/bin/sh
set -u

out=/data/local/tmp/tb371fc-root-reference
mkdir -p "$out"

dump_tree() {
	name=$1
	root=$2
	depth=${3:-3}
	{
		echo "ROOT=$root"
		if [ -e "$root" ]; then
			find -L "$root" -maxdepth "$depth" -type f 2>/dev/null |
			while IFS= read -r f; do
				echo "### $f"
				timeout 2 cat "$f" 2>&1 || true
			done
		else
			echo MISSING
		fi
	} >"$out/$name.txt" 2>&1
}

dump_tree drm_sysfs_root /sys/class/drm 3
dump_tree graphics_sysfs_root /sys/class/graphics 3
dump_tree backlight_sysfs_root /sys/class/backlight 3
dump_tree typec_sysfs_root /sys/class/typec 5
dump_tree usbpd_sysfs_root /sys/class/usbpd 5
dump_tree power_supply_sysfs_root /sys/class/power_supply 3
dump_tree rfkill_sysfs_root /sys/class/rfkill 3
dump_tree input_sysfs_root /sys/class/input 3
dump_tree pen_sysfs_root /sys/class/lenovo_penraw 4
dump_tree sound_sysfs_root /sys/class/sound 3
dump_tree mdss_mdp_sysfs /sys/devices/platform/soc/ae00000.qcom,mdss_mdp 5
dump_tree dsi0_ctrl_sysfs /sys/devices/platform/soc/ae94000.qcom,mdss_dsi_ctrl0 4
dump_tree dsi0_phy_sysfs /sys/devices/platform/soc/ae94400.qcom,mdss_dsi_phy0 4
dump_tree dsi0_pll_sysfs /sys/devices/platform/soc/ae94900.qcom,mdss_dsi_pll 4
dump_tree dsi1_ctrl_sysfs /sys/devices/platform/soc/ae96000.qcom,mdss_dsi_ctrl1 4
dump_tree dsi1_phy_sysfs /sys/devices/platform/soc/ae96400.qcom,mdss_dsi_phy1 4
dump_tree dsi1_pll_sysfs /sys/devices/platform/soc/ae96900.qcom,mdss_dsi_pll 4
dump_tree panel_primary_sysfs /sys/devices/platform/soc/soc:qcom,dsi-display-primary 5
dump_tree kgsl_sysfs /sys/devices/platform/soc/3d00000.qcom,kgsl-3d0 5
dump_tree cnss_sysfs /sys/devices/platform/soc/b0000000.qcom,cnss-qca6390 5
dump_tree usb0_sysfs /sys/devices/platform/soc/a600000.ssusb 5
dump_tree usb1_sysfs /sys/devices/platform/soc/a800000.ssusb 5

{
	for m in msm_drm msm_dsi_display msm_dsi_panel msm_dsi_phy sde_rsc kgsl_core wlan cnss2 nt36523_ts; do
		for d in /sys/module/$m /sys/module/*$m*; do
			[ -d "$d" ] || continue
			echo "### $d"
			find -L "$d/parameters" -maxdepth 1 -type f 2>/dev/null |
			while IFS= read -r f; do echo "## $f"; cat "$f" 2>&1 || true; done
		done
	done
} >"$out/module_parameters.txt" 2>&1

ls -lR /dev/block/by-name >"$out/block_by_name.txt" 2>&1 || true
ps -AZ >"$out/processes_selinux.txt" 2>&1 || true
getenforce >"$out/selinux_mode.txt" 2>&1 || true

if [ -r /proc/config.gz ]; then
	cp /proc/config.gz "$out/android-kernel-config.gz" 2>/dev/null || true
fi
if [ -r /sys/firmware/fdt ]; then
	cp /sys/firmware/fdt "$out/running-fdt.dtb" 2>/dev/null || true
fi
if [ -e /proc/device-tree ]; then
	tar -h -C /proc -czf "$out/proc-device-tree-dereferenced.tar.gz" device-tree 2>/dev/null || true
fi

{
	find /vendor/firmware /vendor/etc/firmware /odm/firmware -type f 2>/dev/null |
	while IFS= read -r f; do
		sz=$(wc -c <"$f" 2>/dev/null || echo 0)
		printf '%s %s\n' "$sz" "$f"
	done
} >"$out/firmware_manifest_root.txt"

{
	find /vendor/lib /vendor/lib64 /vendor/bin /vendor/bin/hw -type f 2>/dev/null |
	grep -Ei 'display|composer|camera|media|audio|bluetooth|wifi|wlan|sensor|usb|typec' |
	sort
} >"$out/vendor_hal_binary_manifest.txt"

cfg=$out/vendor-port-configs.tar.gz
rm -f "$cfg"
tar -czf "$cfg" \
	/vendor/etc/qdcm_calib_data_nt36532_tianma_3k_video_mode_dsi_panel.xml \
	/vendor/etc/display* /vendor/etc/camera /vendor/etc/media* \
	/vendor/etc/audio* /vendor/etc/wifi /vendor/etc/bluetooth \
	/vendor/etc/sensors /vendor/etc/usb* /odm/etc 2>"$out/vendor-port-configs-errors.txt" || true

archive=/data/local/tmp/tb371fc-root-reference.tar.gz
rm -f "$archive"
tar -C /data/local/tmp -czf "$archive" tb371fc-root-reference
sha256sum "$archive"
ls -l "$archive"
