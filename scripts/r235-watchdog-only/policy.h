/* SPDX-License-Identifier: GPL-2.0-only */
/* Pure checks shared with host tests. Source voltage is TCPM policy, not ADC. */
static inline int r235_limits_ok(int temp, int vbatt, int ibatt, int good,
                                int online, int vsource, int isource, int icl)
{
    return temp >= 50 && temp <= 420 && vbatt >= 3200000 && vbatt <= 4400000 &&
           ibatt >= -2000000 && good && online == 1 && vsource == 5000000 &&
           isource > 0 && icl > 0 && icl <= 1500000 && icl <= isource;
}
