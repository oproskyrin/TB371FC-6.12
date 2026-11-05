/* SPDX-License-Identifier: GPL-2.0-only */
/* Return 50mA register units. Zero means suspend, never round upward. */
static inline unsigned int r236_icl_code(unsigned int ma, unsigned int mv,
                                       unsigned int inherited_cap_ma)
{
    unsigned int cap = inherited_cap_ma < 1500 ? inherited_cap_ma : 1500;
    if (mv != 5000 || ma < 50 || cap < 50)
        return 0;
    if (ma > cap)
        ma = cap;
    return ma / 50;
}
