/* SPDX-License-Identifier: GPL-2.0-only */
/* Private-copy prototype, NOT installed. SMB5 sequence based on matched vendor
 * smblib_set_icl_current/SW_OVERRIDE_HC_MODE. Hardware behavior unverified.
 * Error leaves input suspended. Never restore a previously higher current.
 */
#include "policy.h"
static int r236_apply_icl(struct pmic_typec_port *port, u32 ma, u32 mv)
{
    unsigned int code = r236_icl_code(ma, mv, port->r236_cap_ma);
    unsigned int v;
    int ret;
    ret = regmap_read(port->regmap, 0x1140, &v);
    if (ret || (v & 1))
        return ret ?: -EPERM;
    ret = regmap_read(port->regmap, 0x1340, &v);
    if (ret)
        return ret;
    /* Do not clear a suspend asserted by another owner. */
    if ((v & 1) && !port->r236_owned_suspend)
        return -EBUSY;
    ret = regmap_update_bits(port->regmap, 0x1340, 1, 1);
    if (ret)
        return ret;
    port->r236_owned_suspend = true;
    if (!code)
        return (mv && mv != 5000) ? -EINVAL : 0;
    /* Program a bounded current BEFORE selecting software HC mode. */
    ret = regmap_write(port->regmap, 0x1370, code);
    ret = ret ?: regmap_update_bits(port->regmap, 0x1366, 1, 1);
    ret = ret ?: regmap_update_bits(port->regmap, 0x1342, 1, 0);
    ret = ret ?: regmap_update_bits(port->regmap, 0x1365, 0x10, 0x10);
    ret = ret ?: regmap_read(port->regmap, 0x1370, &v);
    if (!ret && v != code)
        ret = -EIO;
    ret = ret ?: regmap_read(port->regmap, 0x1366, &v);
    if (!ret && !(v & 1))
        ret = -EIO;
    ret = ret ?: regmap_read(port->regmap, 0x1342, &v);
    if (!ret && (v & 1))
        ret = -EIO;
    ret = ret ?: regmap_read(port->regmap, 0x1365, &v);
    if (!ret && !(v & 0x10))
        ret = -EIO;
    /* Hardware thermal/OV and gauge safety remain independently enforced.
     * This callback alone is not a complete charger driver. */
    if (!ret)
        ret = regmap_update_bits(port->regmap, 0x1340, 1, 0);
    if (!ret)
        port->r236_owned_suspend = false;
    return ret;
}

static int r236_set_current_limit(struct tcpc_dev *tcpc, u32 ma, u32 mv)
{
    struct pmic_typec *tcpm = tcpc_to_tcpm(tcpc);
    struct pmic_typec_port *port = tcpm->pmic_typec_port;
    int ret;
    mutex_lock(&port->vbus_lock);
    ret = r236_apply_icl(port, ma, mv);
    mutex_unlock(&port->vbus_lock);
    return ret;
}
