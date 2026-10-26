// SPDX-License-Identifier: GPL-2.0-only
/*
 * Lenovo TB371FC dual KTZ8866 backlight controller
 *
 * The tablet uses two KTZ8866 devices at the same address on separate I2C
 * buses.  They drive the two halves of one LCD and must receive identical
 * brightness and enable writes.
 */

#include <linux/backlight.h>
#include <linux/bitops.h>
#include <linux/i2c.h>
#include <linux/list.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/regmap.h>

#define TB371FC_KTZ8866_BRT_LSB		0x04
#define TB371FC_KTZ8866_BRT_MSB		0x05
#define TB371FC_KTZ8866_BL_EN		0x08
#define TB371FC_KTZ8866_ALL_SINKS	GENMASK(5, 0)
#define TB371FC_KTZ8866_ENABLE		BIT(6)
#define TB371FC_KTZ8866_MAX_BRIGHTNESS	2047
#define TB371FC_KTZ8866_DEFAULT_BRIGHTNESS 1200

struct tb371fc_ktz8866 {
	struct i2c_client *client;
	struct regmap *regmap;
	struct list_head node;
};

static LIST_HEAD(tb371fc_ktz8866_devices);
static DEFINE_MUTEX(tb371fc_ktz8866_lock);
static struct backlight_device *tb371fc_backlight;

static const struct regmap_config tb371fc_ktz8866_regmap_config = {
	.reg_bits = 8,
	.val_bits = 8,
	.max_register = 0x15,
};

static int tb371fc_ktz8866_write_level(struct tb371fc_ktz8866 *ktz,
				       unsigned int brightness)
{
	int ret;

	ret = regmap_write(ktz->regmap, TB371FC_KTZ8866_BRT_LSB,
			   brightness & 0x7);
	if (ret)
		return ret;

	ret = regmap_write(ktz->regmap, TB371FC_KTZ8866_BRT_MSB,
			   brightness >> 3);
	if (ret)
		return ret;

	return regmap_write(ktz->regmap, TB371FC_KTZ8866_BL_EN,
		brightness ? TB371FC_KTZ8866_ALL_SINKS |
			     TB371FC_KTZ8866_ENABLE : 0);
}

static int tb371fc_ktz8866_update_status(struct backlight_device *backlight)
{
	struct tb371fc_ktz8866 *ktz;
	unsigned int brightness = backlight_get_brightness(backlight);
	int first_error = 0;
	int ret;

	mutex_lock(&tb371fc_ktz8866_lock);
	list_for_each_entry(ktz, &tb371fc_ktz8866_devices, node) {
		ret = tb371fc_ktz8866_write_level(ktz, brightness);
		if (ret && !first_error)
			first_error = ret;
	}
	mutex_unlock(&tb371fc_ktz8866_lock);

	return first_error;
}

static const struct backlight_ops tb371fc_ktz8866_backlight_ops = {
	.options = BL_CORE_SUSPENDRESUME,
	.update_status = tb371fc_ktz8866_update_status,
};

static int tb371fc_ktz8866_probe(struct i2c_client *client)
{
	struct backlight_properties props = { 0 };
	struct tb371fc_ktz8866 *ktz;
	struct tb371fc_ktz8866 *peer;
	bool primary;
	int ret = 0;

	ktz = devm_kzalloc(&client->dev, sizeof(*ktz), GFP_KERNEL);
	if (!ktz)
		return -ENOMEM;

	ktz->client = client;
	ktz->regmap = devm_regmap_init_i2c(client,
					   &tb371fc_ktz8866_regmap_config);
	if (IS_ERR(ktz->regmap))
		return dev_err_probe(&client->dev, PTR_ERR(ktz->regmap),
				     "failed to initialize regmap\n");

	primary = device_property_read_bool(&client->dev,
					    "lenovo,primary-backlight");

	mutex_lock(&tb371fc_ktz8866_lock);
	list_add_tail(&ktz->node, &tb371fc_ktz8866_devices);
	i2c_set_clientdata(client, ktz);

	if (primary && !tb371fc_backlight) {
		props.type = BACKLIGHT_RAW;
		props.max_brightness = TB371FC_KTZ8866_MAX_BRIGHTNESS;
		props.brightness = TB371FC_KTZ8866_DEFAULT_BRIGHTNESS;
		props.scale = BACKLIGHT_SCALE_LINEAR;

		tb371fc_backlight = devm_backlight_device_register(
			&client->dev, "tb371fc-panel-backlight", &client->dev,
			NULL, &tb371fc_ktz8866_backlight_ops, &props);
		if (IS_ERR(tb371fc_backlight)) {
			ret = PTR_ERR(tb371fc_backlight);
			tb371fc_backlight = NULL;
			list_del(&ktz->node);
		}
	}

	if (!ret && tb371fc_backlight) {
		unsigned int brightness =
			backlight_get_brightness(tb371fc_backlight);

		/* If the secondary half probed first, initialize it now as well. */
		if (primary) {
			list_for_each_entry(peer, &tb371fc_ktz8866_devices, node) {
				ret = tb371fc_ktz8866_write_level(peer, brightness);
				if (ret)
					break;
			}
		} else {
			ret = tb371fc_ktz8866_write_level(ktz, brightness);
		}
	}
	mutex_unlock(&tb371fc_ktz8866_lock);

	if (ret)
		return dev_err_probe(&client->dev, ret,
				     "failed to initialize synchronized backlight\n");

	dev_info(&client->dev, "registered %s TB371FC backlight half\n",
		 primary ? "primary" : "secondary");
	return 0;
}

static void tb371fc_ktz8866_remove(struct i2c_client *client)
{
	struct tb371fc_ktz8866 *ktz = i2c_get_clientdata(client);

	mutex_lock(&tb371fc_ktz8866_lock);
	tb371fc_ktz8866_write_level(ktz, 0);
	list_del(&ktz->node);
	if (tb371fc_backlight && tb371fc_backlight->dev.parent == &client->dev)
		tb371fc_backlight = NULL;
	mutex_unlock(&tb371fc_ktz8866_lock);
}

static const struct of_device_id tb371fc_ktz8866_of_match[] = {
	{ .compatible = "lenovo,tb371fc-ktz8866" },
	{ }
};
MODULE_DEVICE_TABLE(of, tb371fc_ktz8866_of_match);

static struct i2c_driver tb371fc_ktz8866_driver = {
	.driver = {
		.name = "tb371fc-ktz8866",
		.of_match_table = tb371fc_ktz8866_of_match,
	},
	.probe = tb371fc_ktz8866_probe,
	.remove = tb371fc_ktz8866_remove,
};
module_i2c_driver(tb371fc_ktz8866_driver);

MODULE_DESCRIPTION("Lenovo TB371FC synchronized dual KTZ8866 backlight");
MODULE_LICENSE("GPL");
