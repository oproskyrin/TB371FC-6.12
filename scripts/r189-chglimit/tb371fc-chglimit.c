// SPDX-License-Identifier: GPL-2.0-only
/*
 * TB371FC battery charge limit for the PM8150B SMB5 charger (no Linux charger driver is bound).
 *
 * Every 60 s the MM8013 gauge capacity is compared with the limits: at >= stop % the battery
 * charging command bit (CHARGING_ENABLE_CMD 0x1042 bit 0) is cleared, at <= start % it is set
 * again. USB input stays active, so the tablet keeps running from the charger. This is the
 * "bypass charging" mode of the Xiaomi pipa qcom_pm8150b_charger driver; nothing else is written.
 *
 * The bit is only touched once limiting is enabled. Fail-safe: charging is re-enabled when the gauge cannot be read, when limiting is switched
 * off (enable=0), on module unload and on reboot/power-off.
 *
 *   /sys/module/tb371fc_chglimit/parameters/{enable,stop,start}
 *   dump=1 at load: read-only dump of the charger status/config registers.
 */
#include <linux/delay.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/power_supply.h>
#include <linux/reboot.h>
#include <linux/regmap.h>
#include <linux/workqueue.h>

#define CHGR_BASE		0x1000
#define BATTERY_CHARGER_STATUS_1	0x06
#define BATTERY_CHARGER_STATUS_2	0x07
#define CHARGING_ENABLE_CMD	0x42
#define CHARGING_ENABLE_CMD_BIT	BIT(0)

static bool enable;
module_param(enable, bool, 0644);
MODULE_PARM_DESC(enable, "limit charging (0 = always charge to 100 %)");
static int stop = 80;
module_param(stop, int, 0644);
MODULE_PARM_DESC(stop, "stop charging at this capacity (%)");
static int start = 75;
module_param(start, int, 0644);
MODULE_PARM_DESC(start, "resume charging at this capacity (%)");
static bool dump;
module_param(dump, bool, 0444);
MODULE_PARM_DESC(dump, "read-only register dump at load");

static struct regmap *map;
static struct delayed_work work;
static int state = -1;	/* -1 unknown, 1 charging allowed, 0 charging held */

static int set_charging(bool on, const char *why)
{
	int ret = regmap_update_bits(map, CHGR_BASE + CHARGING_ENABLE_CMD, CHARGING_ENABLE_CMD_BIT,
				     on ? CHARGING_ENABLE_CMD_BIT : 0);

	if (ret)
		pr_err("tb371fc-chglimit: write failed: %d\n", ret);
	else if (state != on)
		pr_info("tb371fc-chglimit: charging %s (%s)\n", on ? "enabled" : "held", why);
	if (!ret)
		state = on;
	return ret;
}

static int capacity(void)
{
	struct power_supply *psy = power_supply_get_by_name("mm8013");
	union power_supply_propval val;
	int ret;

	if (!psy)
		return -ENODEV;
	ret = power_supply_get_property(psy, POWER_SUPPLY_PROP_CAPACITY, &val);
	power_supply_put(psy);
	return ret ? ret : val.intval;
}

static void work_fn(struct work_struct *w)
{
	int cap = capacity();

	if (!enable || stop < 50 || stop > 100 || start >= stop || start < 20) {
		if (state == 0)
			set_charging(true, "limit off or invalid limits");
	} else if (cap < 0) {
		if (state == 0)
			set_charging(true, "gauge unreadable");
	} else if (cap >= stop) {
		set_charging(false, "capacity at the stop limit");
	} else if (cap <= start || state != 0) {
		set_charging(true, "capacity below the start limit");
	}
	schedule_delayed_work(&work, 60 * HZ);
}

static int reboot_cb(struct notifier_block *nb, unsigned long action, void *data)
{
	cancel_delayed_work_sync(&work);
	if (state == 0)
		set_charging(true, "reboot/power-off");
	return NOTIFY_DONE;
}

static struct notifier_block reboot_nb = { .notifier_call = reboot_cb };

static void dump_regs(void)
{
	static const u16 regs[] = { 0x06, 0x07, 0x0a, 0x0d, 0x42, 0x51, 0x60, 0x61, 0x70, 0x7d,
				    0x107, 0x108, 0x10b, 0x140, 0x153, 0x307, 0x366, 0x370 };
	unsigned int v;
	int i;

	for (i = 0; i < ARRAY_SIZE(regs); i++) {
		if (regmap_read(map, CHGR_BASE + regs[i], &v))
			pr_info("tb371fc-chglimit: 0x%04x read error\n", CHGR_BASE + regs[i]);
		else
			pr_info("tb371fc-chglimit: 0x%04x = 0x%02x\n", CHGR_BASE + regs[i], v);
	}
}

static int __init chglimit_init(void)
{
	struct device_node *np = of_find_node_by_path("/soc@0/spmi@c440000/pmic@2/temp-alarm@2400");
	struct platform_device *pdev;
	unsigned int v;
	int ret;

	if (!np)
		return -ENODEV;
	pdev = of_find_device_by_node(np);
	of_node_put(np);
	if (!pdev)
		return -EPROBE_DEFER;
	map = dev_get_regmap(pdev->dev.parent, NULL);
	put_device(&pdev->dev);
	if (!map)
		return -ENODEV;
	ret = regmap_read(map, CHGR_BASE + 0x04, &v);	/* PERPH_TYPE */
	if (ret)
		return ret;
	pr_info("tb371fc-chglimit: PM8150B charger peripheral type 0x%02x\n", v);
	if (dump)
		dump_regs();
	INIT_DELAYED_WORK(&work, work_fn);
	register_reboot_notifier(&reboot_nb);
	schedule_delayed_work(&work, 5 * HZ);
	return 0;
}

static void __exit chglimit_exit(void)
{
	unregister_reboot_notifier(&reboot_nb);
	cancel_delayed_work_sync(&work);
	if (state == 0)
		set_charging(true, "module unload");
}

module_init(chglimit_init);
module_exit(chglimit_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC battery charge limit (PM8150B SMB5 charging enable bit)");
