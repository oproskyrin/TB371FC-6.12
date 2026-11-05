// SPDX-License-Identifier: GPL-2.0-only
/* Temporary PM8150B sink-only CC rearm. Exact vendor SMB5 power-role mask.
 * Never requests source/Rp, VBUS, PD voltage, current, thermal or charger changes.
 * Original mode restored on unload or failed initialization.
 */
#include <linux/module.h>
#include <linux/delay.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/regmap.h>

static struct platform_device *pmic;
static struct regmap *map;
static unsigned int original;
static bool changed;
static int __init rearm_init(void)
{
 struct device_node *np;
 struct platform_device *typec;
 unsigned int v;
 int ret;
 np=of_find_node_by_path("/soc@0/spmi@c440000/pmic@2/typec@1500");
 typec=np ? of_find_device_by_node(np) : NULL;of_node_put(np);
 if (!typec) return -ENODEV;
 device_lock(&typec->dev);
 ret=typec->dev.driver ? -EBUSY : 0;
 device_unlock(&typec->dev);put_device(&typec->dev);
 if (ret) return ret;
 np=of_find_node_by_path("/soc@0/spmi@c440000/pmic@2/temp-alarm@2400");
 pmic=np ? of_find_device_by_node(np) : NULL;of_node_put(np);
 if (!pmic) return -ENODEV;
 map=dev_get_regmap(pmic->dev.parent,NULL);
 if (!map) {ret=-ENODEV;goto out;}
 ret=regmap_read(map,0x1004,&v);if(ret||v!=0x02){ret=ret ?: -ENODEV;goto out;}
 ret=regmap_read(map,0x1140,&v);if(ret||(v&1)){ret=ret ?: -EBUSY;goto out;}
 ret=regmap_read(map,0x1544,&original);if(ret||original!=0x12){ret=ret ?: -EPERM;goto out;}
 /* Same mask as vendor smblib_set_prop_typec_power_role(): low five bits. */
 changed=true;
 ret=regmap_update_bits(map,0x1544,0x1f,0x01);if(ret)goto restore;
 msleep(30);
 ret=regmap_update_bits(map,0x1544,0x1f,0x02);if(ret)goto restore;
 ret=regmap_read(map,0x1544,&v);if(ret||v!=0x02){ret=ret ?: -EIO;goto restore;}
 pr_info("R230 sink-only rearm old=%02x new=%02x; source remains OFF; no PD/current/thermal writes\n",original,v);
 return 0;
restore:
 regmap_update_bits(map,0x1544,0x1f,original&0x1f);changed=false;
out:
 put_device(&pmic->dev);pmic=NULL;return ret;
}
static void __exit rearm_exit(void)
{
 if(changed)pr_info("R230 restore mode=%02x rc=%d\n",original,
  regmap_update_bits(map,0x1544,0x1f,original&0x1f));
 if(pmic)put_device(&pmic->dev);
}
module_init(rearm_init);module_exit(rearm_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC temporary source-OFF sink-only Type-C rearm, restores on unload");
