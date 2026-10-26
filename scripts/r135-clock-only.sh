#!/bin/sh
set -eu
# Fix the proven missing reference provider first. Subsequent display stages
# deliberately require separate host commands and physical-screen checks.
/run/r130/busybox sh /run/r134/config/r135-display-stage.sh rpmh
echo 'R135: RPMh clocks ready; DISPCC/ICC/MDSS gated for physical-screen comparison'
