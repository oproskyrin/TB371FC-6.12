// SPDX-License-Identifier: GPL-2.0-only
/* Read-only SMB5 input/charge faults plus the actual stock charge-control GPIO.
 * Register meanings from matched vendor smb5-reg.h and pinctrl-spmi-gpio.c.
 * Absolutely no register writes, no IRQ/FIFO/ack accesses.
 */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/regmap.h>

static int snapshot(const char *path, const u16 *regs, int count)
{
 struct device_node *np=of_find_node_by_path(path);
 struct platform_device *pdev;
 struct regmap *map;
 unsigned int value;
 int i, ret;
 if (!np) return -ENODEV;
 pdev=of_find_device_by_node(np);of_node_put(np);
 if (!pdev) return -ENODEV;
 map=dev_get_regmap(pdev->dev.parent,NULL);
 if (!map) {put_device(&pdev->dev);return -ENODEV;}
 pr_info("R229 READ-ONLY node=%s\n",path);
 for (i=0;i<count;i++) {
  ret=regmap_read(map,regs[i],&value);
  if (ret) pr_info("R229 reg=%04x read_error=%d\n",regs[i],ret);
  else pr_info("R229 reg=%04x value=%02x\n",regs[i],value);
 }
 put_device(&pdev->dev);return 0;
}
static int __init status_init(void)
{
 static const u16 smb[] = {
  0x1004,0x1005,0x1006,0x1007,0x100b,0x100d,0x1042,0x1043,
  0x1061,0x1070,0x1090,
  0x1106,0x1107,0x1108,0x110a,0x110b,0x1140,0x1152,0x1153,
  0x1210,0x1306,0x1307,0x1308,0x1309,0x1310,
  0x1340,0x1342,0x1344,0x1362,0x1363,0x1365,0x1366,0x1370,0x1380,
  0x1506,0x1508,0x1509,0x150a,0x150b,0x1544,0x1570,
  0x1610,0x1651,0x1653,
 };
 static const u16 gpio[] = {0xc904,0xc905,0xc908,0xc940,0xc941,0xc942,0xc943,0xc944,0xc945,0xc946};
 int ret=snapshot("/soc@0/spmi@c440000/pmic@2/temp-alarm@2400",smb,ARRAY_SIZE(smb));
 if (ret) return ret;
 ret=snapshot("/soc@0/spmi@c440000/pmic@0/gpio@c000",gpio,ARRAY_SIZE(gpio));
 pr_info("R229 GPIO10 snapshot result=%d; no registers written\n",ret);
 return 0;
}
static void __exit status_exit(void) {}
module_init(status_init);module_exit(status_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC read-only SMB5 input and stock PM8150 GPIO10 charger diagnostics");
