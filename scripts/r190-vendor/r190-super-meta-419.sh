#!/bin/sh
# R190 (4.19 console, read-only): locate the dynamic-partition "super" on UFS and print its LP
# geometry + primary metadata (first 64 KiB after the 4 KiB reserved area) as hex for the PC parser.
bb=/run/tb371fc-rescue/busybox
for u in /sys/class/block/*/uevent; do
  n=$("$bb" grep -m1 '^PARTNAME=' "$u" | "$bb" cut -d= -f2)
  case "$n" in super|vendor_a|vendor_b|odm_a|odm_b) d=$("$bb" grep -m1 '^DEVNAME=' "$u" | "$bb" cut -d= -f2); echo "PART $n /dev/$d $(cat $(dirname $u)/size) sectors";; esac
done
dev=$(for u in /sys/class/block/*/uevent; do "$bb" grep -q '^PARTNAME=super$' "$u" && "$bb" grep -m1 '^DEVNAME=' "$u" | "$bb" cut -d= -f2; done | "$bb" head -1)
[ -n "$dev" ] || { echo "no super partition"; exit 1; }
[ -b /dev/$dev ] || "$bb" mknod /dev/$dev b $(cat /sys/class/block/$dev/dev | "$bb" tr ':' ' ')
echo "SUPER /dev/$dev"
"$bb" dd if=/dev/$dev bs=4096 skip=1 count=17 2>/dev/null | "$bb" od -A d -t x1 -v | "$bb" sed 's/^/HEX /'
echo R190_META_DONE
