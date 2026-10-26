#!/bin/sh
# R190: load the microphone stack (WCD938x over SoundWire + LPASS RX/TX/VA macros) when the DT has it.
[ -d /proc/device-tree/audio-codec ] || { echo "tb371fc-mic: no wcd938x in DT"; exit 0; }
kv=$(uname -r); mr=/run/r163-modroot/lib/modules/$kv; a=/usr/local/lib/tb371fc/audio
ld() { grep -q "^$(basename "$1" .ko | tr - _) " /proc/modules || insmod "$1" || echo "tb371fc-mic: insmod $1 failed"; }
ld $mr/kernel/drivers/soundwire/soundwire-bus.ko
ld $a/regmap-sdw.ko
ld $a/snd-soc-lpass-macro-common.ko
ld $a/snd-soc-lpass-va-macro.ko
ld $a/snd-soc-lpass-rx-macro.ko
ld $a/snd-soc-lpass-tx-macro.ko
ld $mr/kernel/drivers/soundwire/soundwire-qcom.ko
ld $a/snd-soc-wcd-classh.ko
ld $a/snd-soc-wcd-mbhc.ko
ld $a/snd-soc-wcd938x-sdw.ko
ld $a/snd-soc-wcd938x.ko
echo "tb371fc-mic: modules loaded"
