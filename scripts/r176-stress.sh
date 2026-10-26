# R176: write/verify stress on the root partition (8 x 256 MiB files), then remove them
ok=0; bad=0
for i in 1 2 3 4 5 6 7 8; do
  head -c 268435456 /dev/urandom > /dev/shm/src; a=$(sha256sum /dev/shm/src | cut -c1-16)
  cp /dev/shm/src /root/stress$i.bin; sync
  echo 3 > /proc/sys/vm/drop_caches
  b=$(sha256sum /root/stress$i.bin | cut -c1-16)
  [ "$a" = "$b" ] && ok=$((ok+1)) || bad=$((bad+1))
  echo "file $i: $([ "$a" = "$b" ] && echo OK || echo FAIL) uptime=$(cut -d' ' -f1 /proc/uptime)"
done
rm -f /root/stress*.bin /dev/shm/src; sync
echo "stress ok=$ok bad=$bad"
grep -E "CRC|Timeout Occ" /sys/kernel/debug/mmc0/err_stats | tr '\n' ' '; echo
dmesg | grep -i -E "mmc0|mmcblk0|EXT4-fs error|smmu.*fault" | tail -5
