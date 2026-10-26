#!/bin/sh
dmesg | sed -n '/TFA98XX driver version/,$p' | grep -v -E "truncated|initcall|calling" | head -40
echo "--- MTP guard hits"; dmesg | grep -c "R161 MTP guard"
echo "--- TFA controls"; amixer -c 0 controls | grep -i "Primary Left" | cut -c1-120
amixer -c 0 cget name='Primary Left Profile' 2>&1 | tail -3
amixer -c 0 controls | grep -i -E "Profile|Stop|Cal|Vstep" | head -12
