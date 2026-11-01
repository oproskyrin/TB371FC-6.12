// SPDX-License-Identifier: GPL-2.0-only
/* One-shot diagnostic: invoke the bound Novatek driver's OWN suspend/resume
 * after the display is ready. No clock, panel, DT, or filesystem changes.
 */
#include <linux/module.h>
#include <linux/device.h>
#include <linux/of.h>
#include <linux/spi/spi.h>
#include <linux/pm.h>
static int __init touch_init(void)
{
 struct device *dev;
 const struct dev_pm_ops *pm;
 struct module *owner;
 int ret;
 dev=bus_find_device_by_name(&spi_bus_type,NULL,"spi14.0");
 if (!dev) return -ENODEV;
 device_lock(dev);
 if (!dev->driver || strcmp(dev->driver->name,"NVT-ts-spi") ||
     !of_device_is_compatible(dev->of_node,"novatek,NVT-ts-spi")) {ret=-ENODEV;goto out;}
 pm=dev->driver->pm;owner=dev->driver->owner;
 if (!pm || !pm->suspend || !pm->resume || !try_module_get(owner)) {ret=-EOPNOTSUPP;goto out;}
 ret=pm->suspend(dev);
 pr_info("R225 touch own-driver suspend=%d\n",ret);
 if (!ret) {
  ret=pm->resume(dev);
  pr_info("R225 touch own-driver resume=%d; IRQ/input verification still required\n",ret);
 }
 module_put(owner);
out:
 device_unlock(dev);put_device(dev);
 return ret;
}
static void __exit touch_exit(void) {}
module_init(touch_init);
module_exit(touch_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC one-shot bound Novatek touch PM cycle after display ready");
