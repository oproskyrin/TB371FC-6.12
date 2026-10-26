#!/bin/sh
# R191: LPASS LPI pinctrl (instead of tb371fc-lpass-vote) + WCD938x over SoundWire + LPASS VA/RX/TX macros.
kv=$(uname -r); mr=/run/r163-modroot/lib/modules/$kv; a=/usr/local/lib/tb371fc/audio-r191
ld() { grep -q "^$(basename "$1" .ko | tr - _) " /proc/modules || insmod "$1" || echo "tb371fc-mic: insmod $1 failed"; }
p=/sys/bus/platform/devices/33c0000.pinctrl
[ -e $p/driver ] && case "$(readlink $p/driver)" in *lpass-vote*) echo 33c0000.pinctrl > $p/driver/unbind;; esac
ld $a/pinctrl-lpass-lpi.ko; ld $a/pinctrl-sm8250-lpass-lpi.ko
ld $mr/kernel/drivers/soundwire/soundwire-bus.ko; ld $a/regmap-sdw.ko; ld $a/snd-soc-lpass-macro-common.ko
ld $a/snd-soc-lpass-va-macro.ko; ld $a/snd-soc-lpass-rx-macro.ko; ld $a/snd-soc-lpass-tx-macro.ko
ld $mr/kernel/drivers/soundwire/soundwire-qcom.ko
ld $a/snd-soc-wcd-classh.ko; ld $a/snd-soc-wcd-mbhc.ko; ld $a/snd-soc-wcd938x-sdw.ko; ld $a/snd-soc-wcd938x.ko
echo "tb371fc-mic: stack loaded ($(readlink $p/driver | sed 's#.*/##'))"
