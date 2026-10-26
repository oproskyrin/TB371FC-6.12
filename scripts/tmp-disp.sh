m=/root/tb371fc/linux-6.12-r180-native/drivers/gpu/drm/msm/disp/dpu1
grep -n -i -E "0x0*0C\b" $m/dpu_hwio.h $m/dpu_hw_top.c 2>/dev/null | head
v=/root/tb371fc-desktop-v56-6-watchdog-kexec-src/techpack/display/msm/sde
grep -n -i -E "0x0*0C\b" $v/sde_hwio.h $v/sde_hw_top.c 2>/dev/null | head
grep -rn "INTR2_STATUS\|INTR2_CLEAR\|INTR2_EN\|HIST_INTR" $m/dpu_hwio.h | head
