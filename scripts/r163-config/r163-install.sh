#!/bin/sh
# R163: boot-time setup in RAM: timezone, oops must not freeze the system, PipeWire/WirePlumber
# speaker config, then start Wi-Fi and audio bring-up asynchronously.
cfg=/run/r130/config
echo 0 > /proc/sys/kernel/panic_on_oops
ln -sf /usr/share/zoneinfo/Asia/Yekaterinburg /etc/localtime
mkdir -p /etc/pipewire/pipewire.conf.d /etc/wireplumber/wireplumber.conf.d /etc/systemd/system
cp $cfg/50-tb371fc-speakers.conf /etc/pipewire/pipewire.conf.d/
cp $cfg/51-tb371fc-acp-off.conf /etc/wireplumber/wireplumber.conf.d/
cp $cfg/r163-audio.service $cfg/r163-wifi.service /etc/systemd/system/
chmod 0600 $cfg/r163-wpa.conf
# R167: no automatic screen lock (the lock screen asks for a password the user does not use)
runuser -u alarm -- kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
runuser -u alarm -- kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false
systemctl daemon-reload
systemctl --no-block start r163-audio.service r163-wifi.service
echo 'R163: timezone, speaker config, audio and Wi-Fi bring-up started'
# R168: Google QUIC (HTTP/3, UDP 443) does not get through on the home network and Chromium hangs
# on Google search; force TCP. /usr/bin/chromium (Arch) reads ~/.config/chromium-flags.conf.
runuser -u alarm -- sh -c 'mkdir -p ~/.config; grep -qx -- --disable-quic ~/.config/chromium-flags.conf 2>/dev/null || echo --disable-quic >> ~/.config/chromium-flags.conf'
# R168: Yandex as the default search engine in Chromium (Google answers this network with a captcha)
mkdir -p /etc/chromium/policies/managed
cp $cfg/tb371fc-search.json /etc/chromium/policies/managed/
# R170: panel backlight (two KTZ8866 on I2C5/I2C11 as one device) before KDE starts, so the
# brightness slider and keys work. Keeps the bootloader's level and its 4 LED strings.
mkdir -p /run/r163-modroot
[ -f /run/r163-modroot/lib/modules/$(uname -r)/modules.dep ] || tar -xzf $cfg/r163-modroot.tar.gz -C /run/r163-modroot
modprobe -d /run/r163-modroot tb371fc-ktz8866 sinks=15 || echo 'R170: backlight module failed'
# R171: Bluetooth (QCA6390 over UART6), stable BD address, bluetoothd
cp $cfg/r171-bt.service /etc/systemd/system/ 2>/dev/null && systemctl daemon-reload && systemctl --no-block start r171-bt.service
