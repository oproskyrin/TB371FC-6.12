#!/system/bin/sh
set -u

out=/data/local/tmp/tb371fc-root-reference
mkdir -p "$out"
original=$(getenforce 2>/dev/null || echo Enforcing)
policy_applied=0
restore_selinux() {
	if [ "$policy_applied" -eq 1 ]; then
		magiskpolicy --live \
			'deny magisk vendor_proc_display_file file { open read getattr ioctl }' \
			'deny magisk vendor_sysfs_graphics file { open read getattr ioctl }' \
			2>/dev/null || true
	fi
	if [ "$original" = Enforcing ]; then
		setenforce 1 2>/dev/null || true
	fi
}
trap restore_selinux EXIT HUP INT TERM

if setenforce 0 2>/dev/null && [ "$(getenforce)" = Permissive ]; then
	current=Permissive
else
	magiskpolicy --live \
		'allow magisk vendor_proc_display_file file { open read getattr ioctl }' \
		'allow magisk vendor_sysfs_graphics file { open read getattr ioctl }'
	policy_applied=1
	current=TargetedPolicy
fi
printf 'original=%s\nduring=%s\npolicy_applied=%s\n' \
	"$original" "$current" "$policy_applied" \
	>"$out/selinux-permissive-window.txt"

dump_file() {
	f=$1
	name=$2
	{
		echo "PATH=$f"
		ls -l "$f" 2>&1 || true
		timeout 8 cat "$f" 2>&1 || true
	} >"$out/$name.txt"
}

dump_tree() {
	root=$1
	name=$2
	depth=${3:-5}
	{
		echo "ROOT=$root"
		find -L "$root" -maxdepth "$depth" -type f 2>/dev/null |
		while IFS= read -r f; do
			echo "### $f"
			timeout 3 cat "$f" 2>&1 || true
		done
	} >"$out/$name.txt" 2>&1
}

dump_file /sys/class/drm/card0-DSI-1/mipi_reg android_dsi_mipi_reg
dump_file /sys/class/drm/card0-DSI-1/modes android_dsi_modes
dump_file /sys/class/drm/card0-DSI-1/status android_dsi_status
dump_file /sys/class/drm/card0-DSI-1/enabled android_dsi_enabled
dump_file /sys/class/drm/card0-DSI-1/dpms android_dsi_dpms
dump_tree /sys/class/drm android_drm_sysfs_permissive 4
dump_tree /sys/class/graphics android_graphics_sysfs_permissive 4
dump_tree /sys/class/backlight android_backlight_sysfs_permissive 4
dump_tree /sys/devices/platform/soc/ae00000.qcom,mdss_mdp android_mdss_mdp_permissive 7
dump_tree /sys/devices/platform/soc/ae94000.qcom,mdss_dsi_ctrl0 android_dsi0_ctrl_permissive 6
dump_tree /sys/devices/platform/soc/ae94400.qcom,mdss_dsi_phy0 android_dsi0_phy_permissive 6
dump_tree /sys/devices/platform/soc/ae94900.qcom,mdss_dsi_pll android_dsi0_pll_permissive 6
dump_tree /sys/devices/platform/soc/ae96000.qcom,mdss_dsi_ctrl1 android_dsi1_ctrl_permissive 6
dump_tree /sys/devices/platform/soc/ae96400.qcom,mdss_dsi_phy1 android_dsi1_phy_permissive 6
dump_tree /sys/devices/platform/soc/ae96900.qcom,mdss_dsi_pll android_dsi1_pll_permissive 6
dump_tree /sys/devices/platform/soc/soc:qcom,dsi-display-primary android_panel_primary_permissive 7
dump_tree /sys/class/typec android_typec_permissive 6
dump_tree /sys/class/usbpd android_usbpd_permissive 6

dmesg >"$out/dmesg-permissive.txt" 2>&1 || true
cat /proc/iomem >"$out/iomem-permissive.txt" 2>&1 || true
cat /proc/kallsyms >"$out/kallsyms-permissive.txt" 2>&1 || true

if [ -r /sys/firmware/fdt ]; then
	cp /sys/firmware/fdt "$out/running-fdt-permissive.dtb" 2>/dev/null || true
fi
if [ -e /proc/device-tree ]; then
	tar -h -C /proc -czf "$out/proc-device-tree-permissive.tar.gz" device-tree 2>/dev/null || true
fi

restore_selinux
trap - EXIT HUP INT TERM
after=$(getenforce)
printf 'original=%s\nduring=%s\nafter=%s\npolicy_removed=1\n' \
	"$original" "$current" "$after" \
	>"$out/selinux-permissive-window.txt"
[ "$after" = "$original" ] || exit 2

archive=/data/local/tmp/tb371fc-root-reference.tar.gz
rm -f "$archive"
tar -C /data/local/tmp -czf "$archive" tb371fc-root-reference
sha256sum "$archive"
ls -l "$archive"
