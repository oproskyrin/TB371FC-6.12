#!/bin/sh
# R191: audio bring-up wrapper. On a microphone-capable system (R191 kernel: GENERIC_PINCTRL_GROUPS for
# the upstream LPASS LPI pinctrl, DT with the WCD938x) the stock R163 script is run with:
#  - the LPI pinctrl + WCD938x/SoundWire/LPASS macro stack instead of the tb371fc-lpass-vote helper,
#  - the microphone route after the speaker route.
# Otherwise the stock script runs unchanged (older payloads keep working).
src=/run/r130/config/r163-audio.sh; out=/run/tb371fc-audio.sh
if [ -d /proc/device-tree/audio-codec ] && zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_GENERIC_PINCTRL_GROUPS=y' \
   && [ -f /usr/local/lib/tb371fc/audio-r191/snd-soc-wcd938x.ko ]; then
	sed -e 's/ tb371fc-lpass-vote / /' \
	    -e 's#^mp snd-soc-tb371fc$#sh /usr/local/sbin/tb371fc-mic.sh\nmp snd-soc-tb371fc#' \
	    -e "s#^\(amixer -c 0 cset name='PRIMARY_TDM_RX_0 Audio Mixer MultiMedia1' 1.*\)\$#\1\nsh /usr/local/sbin/tb371fc-mic-route.sh#" \
	    "$src" > "$out"
	grep -q tb371fc-mic.sh "$out" && grep -q tb371fc-mic-route.sh "$out" && ! grep -q lpass-vote "$out" || { echo "tb371fc-audio: patch failed, stock script"; exec /bin/sh "$src"; }
	/bin/sh "$out"
	# alsa-restore (udev, on card add) may replay an older mixer state after our route: apply it again
	sleep 3; sh /usr/local/sbin/tb371fc-mic-route.sh >>/run/r163-audio.log 2>&1
	exit 0
fi
exec /bin/sh "$src"
