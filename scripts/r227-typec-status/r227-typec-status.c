// SPDX-License-Identifier: GPL-2.0-only
/* Read-only PM8150B Type-C/OTG diagnostics. No role, VBUS, IRQ or PD writes. */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/regmap.h>

static int __init status_init(void)
{
 struct device_node *np;
 struct platform_device *pdev;
 struct regmap *map;
 unsigned int value;
 int i, ret;
 /* Same physically validated PM8150B regmap as the existing charge limiter.
  * Only normal status/config registers: never FIFO, IRQ clear/ack or commands.
  * Register definitions: matched 6.12 qcom_pmic_typec_port and VBUS drivers.
  */
 static const unsigned int regs[] = {
  0x1004, 0x1006, 0x1007, 0x1042,
  0x1104, 0x1140, 0x1152, 0x1153,
  0x1307, 0x1308, 0x130b,
  0x1504, 0x1506, 0x1508, 0x1509, 0x150a, 0x150b, 0x150d,
  0x1544, 0x1546, 0x1552,
 };
 np=of_find_node_by_path("/soc@0/spmi@c440000/pmic@2/temp-alarm@2400");
 if (!np) return -ENODEV;
 pdev=of_find_device_by_node(np);
 of_node_put(np);
 if (!pdev) return -ENODEV;
 map=dev_get_regmap(pdev->dev.parent,NULL);
 if (!map) {ret=-ENODEV;goto out;}
 ret=regmap_read(map,0x1004,&value);
 if (ret || value!=0x02) {ret=ret ?: -ENODEV;goto out;}
 pr_info("R227 PM8150B READ-ONLY status begin (no register writes)\n");
 for (i=0;i<ARRAY_SIZE(regs);i++) {
  ret=regmap_read(map,regs[i],&value);
  if (ret) pr_info("R227 reg=%04x read_error=%d\n",regs[i],ret);
  else pr_info("R227 reg=%04x value=%02x\n",regs[i],value);
 }
 ret=0;
 pr_info("R227 PM8150B READ-ONLY status end\n");
out:
 put_device(&pdev->dev);
 return ret;
}
static void __exit status_exit(void) {}
module_init(status_init);
module_exit(status_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC read-only PM8150B CC/VBUS/OTG status snapshot");
