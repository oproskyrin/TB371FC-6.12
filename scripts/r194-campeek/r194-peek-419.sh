#!/bin/sh
# R194 (first-stage 4.19 console, read-only): GCC camera/display branch registers and CAM_CC registers.
uname -r
mount -t debugfs none /sys/kernel/debug 2>/dev/null
grep -i -E "gcc_camera|cam_cc_pll0 |cam_cc_core_ahb|cam_cc_gdsc|titan|cam_cc_xo|disp_cc_xo" /sys/kernel/debug/clk/clk_summary 2>/dev/null | head -20
for set in 0xb000,0xb004,0xb008,0xb00c,0xb010,0xb014,0xb018,0xb01c,0xb020,0xb024,0xb028,0xb02c,0xb030,0xb034,0xb038,0xb03c 0xb040,0xb044,0xb048,0xb04c,0xb050,0xb054,0xb058,0xb05c; do
  insmod /run/tb371fc-campeek-419.ko base=0x100000 offs=$set 2>/dev/null; done
insmod /run/tb371fc-campeek-419.ko base=0x0ad00000 offs=0x0,0x4,0x1000,0x2000,0x7004,0xc144 2>/dev/null
dmesg | grep "tb371fc-campeek: +" | sed 's/^\[[^]]*\] //'
echo R194_PEEK_DONE
