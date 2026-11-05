// SPDX-License-Identifier: GPL-2.0-only
/* OFFLINE prototype. Only hardware write is SMB5 PET1643=1.
 * No CC/PD/ICL/FV/FCC/thermal/charge-enable/watchdog-configuration writes.
 * Requires explicitly marked DT and a bound sink-only TCPM owner.
 * Not installable on current R234; no automatic attach or charge recovery.
 */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/device/driver.h>
#include <linux/power_supply.h>
#include <linux/regmap.h>
#include <linux/workqueue.h>
#include <linux/reboot.h>
#include "policy.h"

static struct platform_device *port;
static struct regmap *map;
static struct delayed_work work;
static unsigned long pets;
static int fault;
static bool active;
module_param(pets, ulong, 0444);
module_param(fault, int, 0444);
module_param(active, bool, 0444);

static int property(struct power_supply *psy, enum power_supply_property id, int *n)
{
    union power_supply_propval v;
    int ret = power_supply_get_property(psy, id, &v);
    if (!ret)
        *n = v.intval;
    return ret;
}

static int r235_check_limits(void)
{
    struct power_supply *gauge, *source;
    char name[160];
    unsigned int v, icl;
    int ret, temp, vbatt, ibatt, health, online, vsource, isource;
    device_lock(&port->dev);
    ret = !port->dev.driver || strcmp(port->dev.driver->name, "qcom,pmic-typec")
          ? -ENODEV : 0;
    device_unlock(&port->dev);
    if (ret)
        return ret;
    ret = regmap_read(map, 0x1140, &v);
    if (ret || (v & 1))
        return ret ?: -EPERM;
    ret = regmap_read(map, 0x1544, &v);
    if (ret || v != 2)
        return ret ?: -EPERM;
    ret = regmap_read(map, 0x100d, &v);
    if (ret || (v & 0x0c))
        return ret ?: -ERANGE;
    ret = regmap_read(map, 0x1007, &v);
    if (ret || (v & 2))
        return ret ?: -ERANGE;
    ret = regmap_read(map, 0x1370, &icl);
    if (ret)
        return ret;
    gauge = power_supply_get_by_name("mm8013");
    if (!gauge)
        return -ENODEV;
    ret = property(gauge, POWER_SUPPLY_PROP_TEMP, &temp);
    ret = ret ?: property(gauge, POWER_SUPPLY_PROP_VOLTAGE_NOW, &vbatt);
    ret = ret ?: property(gauge, POWER_SUPPLY_PROP_CURRENT_NOW, &ibatt);
    ret = ret ?: property(gauge, POWER_SUPPLY_PROP_HEALTH, &health);
    power_supply_put(gauge);
    if (ret)
        return ret;
    snprintf(name, sizeof(name), "tcpm-source-psy-%s", dev_name(&port->dev));
    source = power_supply_get_by_name(name);
    if (!source)
        return -ENODEV;
    if (source->dev.parent != &port->dev) {
        power_supply_put(source);
        return -EPERM;
    }
    ret = property(source, POWER_SUPPLY_PROP_ONLINE, &online);
    ret = ret ?: property(source, POWER_SUPPLY_PROP_VOLTAGE_NOW, &vsource);
    ret = ret ?: property(source, POWER_SUPPLY_PROP_CURRENT_MAX, &isource);
    power_supply_put(source);
    if (ret)
        return ret;
    if (!r235_limits_ok(temp, vbatt, ibatt, health == POWER_SUPPLY_HEALTH_GOOD,
                        online, vsource, isource, icl * 50000))
        return -ERANGE;
    ret = regmap_read(map, 0x110b, &v);
    return ret ?: ((v & 0x11) == 0x11 ? 0 : -ENOLINK);
}

static void tick(struct work_struct *unused)
{
    int ret = r235_check_limits();
    if (!ret)
        ret = regmap_write(map, 0x1643, 1);
    if (ret) {
        fault = ret;
        active = false;
        pr_err("R235 watchdog guard fault=%d; pets stopped, hardware protection retained\n", ret);
        return;
    }
    pets++;
    schedule_delayed_work(&work, 4 * HZ);
}

static int reboot_stop(struct notifier_block *nb, unsigned long event, void *data)
{
    cancel_delayed_work_sync(&work);
    active = false;
    return NOTIFY_DONE;
}
static struct notifier_block reboot_nb = { .notifier_call = reboot_stop };

static int __init start(void)
{
    struct device_node *np;
    unsigned int v;
    int ret;
    if (!of_machine_is_compatible("lenovo,tb371fc"))
        return -ENODEV;
    np = of_find_node_by_path("/soc@0/spmi@c440000/pmic@2/typec@1500");
    if (!np)
        return -ENODEV;
    if (!of_property_read_bool(np, "tb371fc,r235-watchdog-only-test")) {
        of_node_put(np);
        return -EPERM;
    }
    port = of_find_device_by_node(np);
    of_node_put(np);
    if (!port)
        return -ENODEV;
    map = dev_get_regmap(port->dev.parent, NULL);
    if (!map) { ret = -ENODEV; goto release; }
    ret = regmap_read(map, 0x1004, &v);
    if (ret || v != 2) { ret = ret ?: -ENODEV; goto release; }
    ret = regmap_read(map, 0x1651, &v);
    if (ret || v != 0x42) { ret = ret ?: -EPERM; goto release; }
    ret = regmap_read(map, 0x1653, &v);
    if (ret || v != 0xf3) { ret = ret ?: -EPERM; goto release; }
    ret = r235_check_limits();
    if (ret)
        goto release;
    INIT_DELAYED_WORK(&work, tick);
    ret = register_reboot_notifier(&reboot_nb);
    if (ret)
        goto release;
    active = true;
    schedule_delayed_work(&work, HZ);
    return 0;
release:
    put_device(&port->dev);
    return ret;
}
static void __exit stop(void)
{
    unregister_reboot_notifier(&reboot_nb);
    cancel_delayed_work_sync(&work);
    active = false;
    put_device(&port->dev);
}
module_init(start);
module_exit(stop);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC experimental watchdog-only 5V sink guard, no CC writes");
