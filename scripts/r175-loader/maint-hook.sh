if grep -qw tb371fc.maint /proc/cmdline; then
	show_status 'MAINTENANCE MODE: microSD is not mounted; starting USB (172.31.77.2:2323)'
	mkdir -p /run/r130/modules /run/r130/config
	cp /bin/busybox /run/r130/busybox; cp /r130-modules/*.ko /run/r130/modules/; cp /r130-config/* /run/r130/config/
	chmod 0755 /run/r130/busybox /run/r130/config/*.sh
	# start-usb.sh is written for Arch: provide every busybox applet (tee, mountpoint, ...)
	mkdir -p /run/maint-bin; /bin/busybox --install -s /run/maint-bin
	PATH=/run/maint-bin:$PATH /run/r130/busybox sh /run/r130/config/start-usb.sh > /run/maint-usb.log 2>&1 || true
	( exec busybox nc -lk -p 2323 -e /bin/sh ) &
	insmod /usr/maint/tb371fc-bh201.ko 2>/dev/null || true
	echo 1 > /proc/sys/kernel/sysrq
	show_status 'MAINTENANCE MODE: USB shell 172.31.77.2:2323 (reboots in 15 min without contact)'
	# no contact (/run/maint-keep) within 15 minutes: reboot back to the normal system
	( sleep 900; [ -f /run/maint-keep ] || { sync; echo b > /proc/sysrq-trigger; } ) &
	while :; do sleep 3600; done
fi
