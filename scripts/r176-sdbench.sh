echo "== $(cat /sys/kernel/debug/mmc0/ios | grep -E '^(clock|timing)' | tr '\n' ' ')"; dmesg | grep -m1 "SDHCI controller on 8804000"
sync; echo 3 > /proc/sys/vm/drop_caches
r=$(dd if=/dev/mmcblk0p2 of=/dev/null bs=4M count=64 skip=1000 iflag=direct 2>&1 | tail -1); echo "read direct 256M: $r"
w=$(dd if=/dev/zero of=/root/sdbench.bin bs=4M count=32 oflag=direct 2>&1 | tail -1); echo "write direct 128M: $w"
t0=$(date +%s.%N); dd if=/dev/urandom of=/root/sdbench2.bin bs=1M count=128 2>/dev/null; sync; t1=$(date +%s.%N); echo "write buffered 128M+sync: $(awk "BEGIN{printf \"%.1f\", 128/($t1-$t0)}") MB/s"
echo 3 > /proc/sys/vm/drop_caches; t0=$(date +%s.%N); cat /usr/lib/libQt6Gui.so* /usr/lib/libQt6Widgets.so* > /dev/null 2>&1; t1=$(date +%s.%N); echo "read files: $(du -cb /usr/lib/libQt6Gui.so* /usr/lib/libQt6Widgets.so* | tail -1 | cut -f1) bytes in $(awk "BEGIN{printf \"%.1f\", $t1-$t0}") s"
rm -f /root/sdbench.bin /root/sdbench2.bin; sync
grep -E "CRC|Timeout Occ" /sys/kernel/debug/mmc0/err_stats | tr '\n' ' '; echo
