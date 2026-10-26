#!/bin/sh
# R161 recon on the first-stage 4.19 console (read-only): speaker-ID GPIO 1171 and stock TFA DT.
bb=/run/tb371fc-rescue/busybox
uname -r
mount -t debugfs none /sys/kernel/debug 2>/dev/null
echo "--- gpiochips"
for c in /sys/class/gpio/gpiochip*; do echo "$(basename $c) base=$(cat $c/base) ngpio=$(cat $c/ngpio) label=$(cat $c/label)"; done
echo "--- debugfs gpio (requested lines)"
"$bb" head -60 /sys/kernel/debug/gpio 2>&1
echo "--- stock DT nodes mentioning tfa"
for n in $("$bb" find /proc/device-tree -name compatible 2>/dev/null | while read f; do "$bb" grep -l -i "tfa" "$f" 2>/dev/null; done); do
  d=$("$bb" dirname $n); echo "== $d"
  for p in compatible reg reset-gpio reset-gpios reset-polarity irq-gpio spk-id-gpio status sound-name-prefix; do
    [ -e "$d/$p" ] && { printf "  %s: " $p; "$bb" od -An -tx1 "$d/$p" | "$bb" tr -s ' \n' ' '; printf " | %s\n" "$("$bb" tr '\0' ' ' < "$d/$p" | "$bb" tr -cd '[:print:] ')"; }
  done
done
echo "--- GPIO 1171 (speaker id)"
if [ ! -e /sys/class/gpio/gpio1171 ]; then echo 1171 > /sys/class/gpio/export 2>&1 && exported=1; fi
if [ -e /sys/class/gpio/gpio1171 ]; then
  echo "direction=$(cat /sys/class/gpio/gpio1171/direction) value=$(cat /sys/class/gpio/gpio1171/value)"
  [ -n "${exported:-}" ] && echo 1171 > /sys/class/gpio/unexport
else echo "gpio1171 not available"; fi
