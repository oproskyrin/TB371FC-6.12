# R152–R153: Wi-Fi and keyboard in the power-on autoboot

2026-10-24. Current installed state: recovery_b = R153 (42ea7f50…), vbmeta_b = test
(5faf802f…). Power-on → 4.19 console → 7 s countdown (touch/button cancels) → kexec →
6.12 with 8 CPUs, touchscreen (calibrated), KDE, Wi-Fi with SSH over Wi-Fi, keyboard
cover with touchpad. Verified by the user: keyboard/touchpad work, also after
detaching and re-attaching the cover. Boot 293e9433-c7cd-4008-8123-9a006f6d0227.

## R152 payload (Wi-Fi autostart)

`scripts/package-r152-wifi-autostart.sh`: R149b initramfs + the 12 Wi-Fi modules
(R151 + michael_mic) + `scripts/r152-config/` (r152-wifi.sh/.service/install.sh) +
the network credential. The credential is ONLY a hashed PSK generated into
`D:/TB371FC-builds/private/r152-wpa.conf` (outside git) and copied into the payload
(mode 0600). The Wi-Fi password is not in the repository, logs or reports.
r152-wifi.sh lowers /sys/class/firmware/timeout to 1 s while loading ath11k (the missing
optional firmware-2.bin no longer stalls 60 s), runs wpa_supplicant + dhcpcd and a
second key-only sshd on the Wi-Fi address (port 2222). Wi-Fi is up ~17 s after the
service starts. initramfs 191523a1….

## R153 DT (keyboard)

`scripts/prepare-r153-keyboard-dt.sh`, DTB e336fb1f…, base = R151 DTB. The node
`keyboard-cover@60` (hid-over-i2c, 17ef:6175) already existed under i2c@a94000 (QUP SE13);
the bus failed with "Error applying setting" because its pins were reserved. Changes:
interconnects removed from i2c@a94000 (no ICC provider), GPIO 36/37 (SDA/SCL), 108 (wake),
110 (irq), 114 (reset) freed. Drivers (I2C_HID_OF, HID_MULTITOUCH, HID_LENOVO) are built in.
Result: Keyboard, Touchpad, Consumer Control inputs at 2.7 s of boot; hotplug works.

## R153 recovery and install

`scripts/package-r153-autoboot-recovery.py` (R121 kernel/DTB/dtbo/cmdline byte-identical),
helper `scripts/r153-recovery/tb371fc-autoboot-612` pins Image 03b2f152…, DTB e336fb1f…,
initramfs 191523a1…, folder `tb371fc-linux/autoboot-6.12-r153`. AUDIT_RESULT=PASS,
allowlisted. SD: `scripts/r153-sd-install.sh` (read-back verified). Flash with
`temporary-vbmeta-recovery-test.ps1 -Action LaunchFastboot` under Start-Transcript (no
stream redirection) — clean OKAY. Rollback R150 (ddf9eb83…, its SD folder untouched),
then R121, then stock backups. R152 recovery was built but never flashed (superseded).

## Not done

- Root filesystem is still a RAM overlay: KDE settings/installed packages are lost on reboot.
- KDE network switching needs NetworkManager (Wi-Fi is wpa_supplicant with one network).
- No sound, battery level, suspend, brightness keys, Bluetooth, GPU acceleration yet.
- Full cold power-off → on not yet tested by the user.
