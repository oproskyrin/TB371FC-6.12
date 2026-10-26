#!/bin/sh
set -eu
cfg=/run/r130/config
mkdir -p /etc/systemd/system /etc/systemd/network /etc/ssh /root/.ssh
cp "$cfg/r130-usb.service" "$cfg/r130-sshd.service" /etc/systemd/system/
cp "$cfg/00-r130-usb.network" "$cfg/00-r130-usb.link" /etc/systemd/network/
cp "$cfg/sshd_config" /etc/ssh/sshd_config.r130
cp "$cfg/id_ed25519.pub" /root/.ssh/authorized_keys
chmod 0700 /root/.ssh
chmod 0600 /root/.ssh/authorized_keys
chmod 0644 /etc/systemd/system/r130-usb.service /etc/systemd/system/r130-sshd.service /etc/systemd/network/00-r130-usb.* /etc/ssh/sshd_config.r130
