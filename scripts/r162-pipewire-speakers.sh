#!/bin/sh
# R162: route MM1 -> PRIMARY_TDM_RX_0, replace the ACP pro-audio profile with a plain
# stereo sink (50-tb371fc-speakers.conf), default sink at 35 %.
set -u
amixer -c 0 cset name='PRIMARY_TDM_RX_0 Audio Mixer MultiMedia1' 1 >/dev/null
mkdir -p /etc/pipewire/pipewire.conf.d
cp /run/50-tb371fc-speakers.conf /etc/pipewire/pipewire.conf.d/
U() { su alarm -c "XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus $*" 2>&1 | grep -v -i rtkit; }
U pactl set-card-profile alsa_card.platform-sound off
U systemctl --user restart pipewire
sleep 4
U pactl set-card-profile alsa_card.platform-sound off
U pactl list short sinks
U pactl set-default-sink tb371fc-speakers
U pactl set-sink-volume tb371fc-speakers 35%
U pactl list sinks | grep -E "Name:|Description|Sample Spec|Volume:|State"
