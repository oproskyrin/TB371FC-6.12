// SPDX-License-Identifier: GPL-2.0-only
/* TB371FC RAM-only USB3 diagnostic; NOT a production Type-C driver.
 * PS5169 ID/config bits: Esteban Urrutia's upstream v3 patch,
 * 20260810-ps5169-bup-v3-2-a2178b2834d7@proton.me.
 * Preserve EQ, GPIO, regulators, DP and VBUS. Restore registers on unload.
 * Optional LFPS bit0 on8d/90 matches Lenovo TB321FU ps5169_USB_seq.
 */
#include <linux/module.h>
#include <linux/i2c.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/usb/typec_mux.h>
#include "mux.h" /* Matched R200 internal layout, diagnostic callback only. */
static struct i2c_client *chip;
static struct typec_switch_dev *sw;
static u8 saved_config;
static u8 saved_lfps[2];
static bool fine_lfps;
module_param(fine_lfps, bool, 0400);
static int orientation = 1;
static DEFINE_MUTEX(test_lock);

static int read_reg(u8 reg, u8 *buf, int len)
{
 struct i2c_msg msg[] = {
  { .addr = chip->addr, .len = 1, .buf = &reg },
  { .addr = chip->addr, .flags = I2C_M_RD, .len = len, .buf = buf },
 };
 int ret = i2c_transfer(chip->adapter, msg, ARRAY_SIZE(msg));
 return ret == ARRAY_SIZE(msg) ? 0 : ret < 0 ? ret : -EIO;
}
static int write_reg(u8 reg, u8 value)
{
 u8 data[] = { reg, value }, check;
 int ret = i2c_master_send(chip, data, sizeof(data));
 if (ret != sizeof(data)) return ret < 0 ? ret : -EIO;
 ret = read_reg(reg, &check, 1);
 return ret ? ret : check == value ? 0 : -EIO;
}
static int write_config(u8 value) { return write_reg(0x40, value); }
static int set_orientation(const char *value, const struct kernel_param *kp)
{
 int val, ret = kstrtoint(value, 0, &val);
 u8 prev;
 if (ret || val < 1 || val > 2) return -EINVAL;
 mutex_lock(&test_lock);
 if (!sw) { orientation = val; goto out; }
 ret = read_reg(0x40, &prev, 1);
 if (ret) goto out;
 /* BASE + USB3, no DisplayPort or VBUS. Orientation bit is bit4. */
 ret = write_config(0xc0 | (val == 2 ? 0x10 : 0));
 if (ret) { write_config(prev); goto out; }
 ret = sw->set(sw, val == 1 ? TYPEC_ORIENTATION_NORMAL : TYPEC_ORIENTATION_REVERSE);
 if (ret) { write_config(prev); goto out; }
 orientation = val;
 pr_info("R207 PS5169 USB-only orientation=%d config=%02x (verified)\n",
         val, 0xc0 | (val == 2 ? 0x10 : 0));
out:
 mutex_unlock(&test_lock);
 return ret;
}
static const struct kernel_param_ops param_ops = {
 .set = set_orientation, .get = param_get_int,
};
module_param_cb(orientation, &param_ops, &orientation, 0600);

static int __init test_init(void)
{
 struct device_node *np;
 struct device *phy, *child;
 struct i2c_adapter *adapter;
 u8 id[2], rev[2];
 char name[80], val[2] = { '1', 0 };
 int ret;
 np = of_find_node_by_path("/chosen");
 ret = np && of_property_match_string(np, "tb371fc,experiment", "r207-ps5169-usb3") >= 0;
 of_node_put(np);
 if (!ret) return -EPERM;
 np = of_find_node_by_path("/soc@0/phy@88e8000");
 phy = np ? bus_find_device_by_of_node(&platform_bus_type, np) : NULL;
 of_node_put(np);
 if (!phy) return -ENODEV;
 snprintf(name, sizeof(name), "%s-switch", dev_name(phy));
 child = device_find_child_by_name(phy, name);
 put_device(phy);
 if (!child) return -EPROBE_DEFER;
 if (!child->parent->driver || !try_module_get(child->parent->driver->owner)) {
  put_device(child); return -ENODEV;
 }
 sw = to_typec_switch_dev(child);
 adapter = i2c_get_adapter(9);
 if (!adapter) { ret = -ENODEV; goto put_sw; }
 chip = i2c_new_dummy_device(adapter, 0x28);
 i2c_put_adapter(adapter);
 if (IS_ERR(chip)) { ret = PTR_ERR(chip); chip = NULL; goto put_sw; }
 ret = read_reg(0xac, id, 2);
 if (ret) goto put_chip;
 if (id[0] != 0x87 || id[1] != 0x69) { ret = -ENODEV; goto put_chip; }
 ret = read_reg(0xae, rev, 2);
 if (ret) goto put_chip;
 ret = read_reg(0x40, &saved_config, 1);
 if (ret) goto put_chip;
 ret = read_reg(0x8d, &saved_lfps[0], 1);
 if (ret) goto put_chip;
 ret = read_reg(0x90, &saved_lfps[1], 1);
 if (ret) goto put_chip;
 if (fine_lfps) {
  ret = write_reg(0x8d, saved_lfps[0] | 1);
  if (!ret) ret = write_reg(0x90, saved_lfps[1] | 1);
  if (ret) goto restore;
  pr_info("R207 PS5169 LFPS50ohm enabled, original=%02x/%02x\n",
          saved_lfps[0], saved_lfps[1]);
 }
 pr_info("R207 PS5169 id=6987 rev=%02x%02x original config=%02x\n",
         rev[1], rev[0], saved_config);
 val[0] = '0' + orientation;
 ret = set_orientation(val, NULL);
 if (!ret) return 0;
restore:
 write_config(saved_config);
 if (fine_lfps) {
  write_reg(0x8d, saved_lfps[0]);
  write_reg(0x90, saved_lfps[1]);
 }
put_chip:
 i2c_unregister_device(chip); chip = NULL;
put_sw:
 module_put(sw->dev.parent->driver->owner);
 put_device(&sw->dev); sw = NULL;
 return ret;
}
static void __exit test_exit(void)
{
 int ret = write_config(saved_config);
 pr_info("R207 restore PS5169 config=%02x result=%d\n", saved_config, ret);
 if (fine_lfps) {
  int a = write_reg(0x8d, saved_lfps[0]);
  int b = write_reg(0x90, saved_lfps[1]);
  pr_info("R207 restore LFPS=%02x/%02x results=%d/%d\n",
          saved_lfps[0], saved_lfps[1], a, b);
 }
 sw->set(sw, TYPEC_ORIENTATION_NONE);
 i2c_unregister_device(chip);
 module_put(sw->dev.parent->driver->owner);
 put_device(&sw->dev);
}
module_init(test_init);
module_exit(test_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC PS5169 reversible USB-only RAM diagnostic");
