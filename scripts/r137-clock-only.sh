#!/bin/sh
set -eu
/run/r130/busybox sh /run/r134/config/r137-native-stage.sh rpmh
echo 'R137: USB/SSH + RPMh ready; power/DISPCC/ICC/backlight/panel require separate host commands'
