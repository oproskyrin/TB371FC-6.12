// SPDX-License-Identifier: GPL-2.0-only
/* TB371FC PM8150B: sink-only CC attach + service the EXISTING charger watchdog.
 * Do not disable watchdog, thermal protections, charge limit or change FV/FCC/ICL.
 * Only writes: Type-C power-role field (DISABLE then SINK), WDog PET command.
 * Unsafe/missing gauge data latches a fault and stops pets: hardware bite remains.
 */
#include <linux/module.h>
#include <linux/delay.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/regmap.h>
#include <linux/power_supply.h>
#include <linux/workqueue.h>
#include <linux/reboot.h>

static struct platform_device *pmic, *tcpc;
static struct regmap *map;
static struct delayed_work work;
static unsigned int original;
static bool changed, active;
static unsigned long pets;
static int fault;
module_param(active,bool,0444);
module_param(pets,ulong,0444);
module_param(fault,int,0444);

static int gauge_guard(void)
{
 struct power_supply *psy=power_supply_get_by_name("mm8013");
 union power_supply_propval t,v,h,c;
 int ret;
 if (!psy) return -ENODEV;
 ret=power_supply_get_property(psy,POWER_SUPPLY_PROP_TEMP,&t);
 ret=ret ?: power_supply_get_property(psy,POWER_SUPPLY_PROP_VOLTAGE_NOW,&v);
 ret=ret ?: power_supply_get_property(psy,POWER_SUPPLY_PROP_HEALTH,&h);
 ret=ret ?: power_supply_get_property(psy,POWER_SUPPLY_PROP_CURRENT_NOW,&c);
 power_supply_put(psy);
 if (ret) return ret;
 if(t.intval<50 || t.intval>420 || v.intval<3200000 || v.intval>4400000 ||
    h.intval!=POWER_SUPPLY_HEALTH_GOOD || c.intval < -2000000) return -ERANGE;
 return 0;
}

static int check_port(void)
{
 unsigned int val;
 int ret;
 device_lock(&tcpc->dev);ret=tcpc->dev.driver ? -EBUSY : 0;device_unlock(&tcpc->dev);
 if(ret)return ret;
 ret=regmap_read(map,0x1140,&val);if(ret || (val&1))return ret ?: -EBUSY;
 ret=regmap_read(map,0x100d,&val);if(ret || (val&0x0c))return ret ?: -ERANGE;
 ret=regmap_read(map,0x1007,&val);if(ret || (val&2))return ret ?: -ERANGE;
 return gauge_guard();
}

static void tick(struct work_struct *unused)
{
 unsigned int path;
 int ret=check_port();
 if(!ret)ret=regmap_read(map,0x1544,&path);
 if(!ret && path!=0x02)ret=-EPERM;
 if(!ret)ret=regmap_read(map,0x110b,&path);
 if(!ret && (path&0x11)==0x11) {
  /* Exact write used by the stock SMB5 watchdog bark handler. */
  ret=regmap_write(map,0x1643,1);
  if(!ret)pets++;
 }
 if(ret) {
  fault=ret;active=false;
  pr_err("R231 guard fault=%d: stop watchdog pets; hardware protection NOT disabled\n",ret);
  return;
 }
 schedule_delayed_work(&work,4*HZ);
}

static void stop(void)
{
 unsigned int current_mode;
 cancel_delayed_work_sync(&work);active=false;
 /* Never overwrite a new, separately bound Type-C driver's policy. */
 if(changed && !tcpc->dev.driver && !regmap_read(map,0x1544,&current_mode) && current_mode==0x02)
  pr_info("R231 restoring prior sink policy=%02x rc=%d\n",original,
   regmap_update_bits(map,0x1544,0x1f,original&0x1f));
 changed=false;
}
static int on_reboot(struct notifier_block *nb,unsigned long action,void *data)
{stop();return NOTIFY_DONE;}
static struct notifier_block reboot_nb={.notifier_call=on_reboot};

static int __init charge_init(void)
{
 struct device_node *np;
 unsigned int val;
 int ret;
 if(!of_machine_is_compatible("lenovo,tb371fc"))return -ENODEV;
 np=of_find_node_by_path("/soc@0/spmi@c440000/pmic@2/typec@1500");
 tcpc=np ? of_find_device_by_node(np) : NULL;of_node_put(np);
 if(!tcpc)return -ENODEV;
 np=of_find_node_by_path("/soc@0/spmi@c440000/pmic@2/temp-alarm@2400");
 pmic=np ? of_find_device_by_node(np) : NULL;of_node_put(np);
 if(!pmic){ret=-ENODEV;goto out;}
 map=dev_get_regmap(pmic->dev.parent,NULL);
 if(!map){ret=-ENODEV;goto out;}
 ret=regmap_read(map,0x1004,&val);if(ret||val!=2){ret=ret ?: -ENODEV;goto out;}
 ret=check_port();if(ret)goto out;
 ret=regmap_read(map,0x1544,&original);if(ret||original!=0x12){ret=ret ?: -EPERM;goto out;}
 ret=regmap_read(map,0x1651,&val);if(ret||val!=0x42){ret=ret ?: -EPERM;goto out;}
 ret=regmap_read(map,0x1653,&val);if(ret||val!=0xf3){ret=ret ?: -EPERM;goto out;}
 INIT_DELAYED_WORK(&work,tick);
 ret=regmap_write(map,0x1643,1);if(ret)goto out;
 changed=true;
 ret=regmap_update_bits(map,0x1544,0x1f,1);if(ret)goto restore;
 msleep(30);
 ret=regmap_update_bits(map,0x1544,0x1f,2);if(ret)goto restore;
 ret=register_reboot_notifier(&reboot_nb);if(ret)goto restore;
 active=true;schedule_delayed_work(&work,HZ);
 pr_info("R231 sink-only charging watchdog service started; FV/FCC/ICL/thermal/WD config unchanged\n");
 return 0;
restore:
 pr_info("R231 init failed; restore rc=%d\n",regmap_update_bits(map,0x1544,0x1f,original&0x1f));
 changed=false;
out:
 if(pmic)put_device(&pmic->dev);
 put_device(&tcpc->dev);return ret;
}
static void __exit charge_exit(void)
{
 unregister_reboot_notifier(&reboot_nb);stop();
 put_device(&pmic->dev);put_device(&tcpc->dev);
}
module_init(charge_init);module_exit(charge_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC guarded sink-only attach and stock SMB5 watchdog servicing");
