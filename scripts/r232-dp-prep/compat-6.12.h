/* Local API backport for the unmodified PS5169 v3 source. */
/* SPDX-License-Identifier: GPL-2.0-only */
#include <linux/gpio/consumer.h>
#include <linux/regmap.h>
static inline int regmap_assign_bits(struct regmap *map, unsigned int reg,
                                    unsigned int mask, bool set)
{
    return regmap_update_bits(map, reg, mask, set ? mask : 0);
}
