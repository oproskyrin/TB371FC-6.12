// SPDX-License-Identifier: GPL-2.0
/*
 * Samsung S5K4H7 image sensor driver
 *
 * Register programming is based on the TB371FC ZUI 16.0.474 CamX module
 * (AX6637_ofilm_s5k4h7_main) and cross-checked against the published
 * MediaTek S5K4H7 driver from Hadenix kernel_umidigi_f2_mt6771_4.14.
 */

#include <linux/clk.h>
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/pm_runtime.h>
#include <linux/regulator/consumer.h>
#include <linux/units.h>

#include <media/v4l2-cci.h>
#include <media/v4l2-ctrls.h>
#include <media/v4l2-device.h>
#include <media/v4l2-fwnode.h>

#define S5K4H7_XCLK_FREQ		(24 * HZ_PER_MHZ)
#define S5K4H7_LINK_FREQ		(366 * HZ_PER_MHZ)
#define S5K4H7_PIXEL_RATE		292800000ULL
#define S5K4H7_DATA_LANES		4

#define S5K4H7_REG_CHIP_ID		CCI_REG16(0x0000)
#define S5K4H7_CHIP_ID			0x487b
#define S5K4H7_REG_MODE_SELECT		CCI_REG8(0x0100)
#define S5K4H7_MODE_STANDBY		0x00
#define S5K4H7_MODE_STREAMING		0x01
#define S5K4H7_REG_ORIENTATION		CCI_REG8(0x0101)
#define S5K4H7_HFLIP			BIT(0)
#define S5K4H7_VFLIP			BIT(1)
#define S5K4H7_REG_EXPOSURE		CCI_REG16(0x0202)
#define S5K4H7_EXPOSURE_MIN		4
#define S5K4H7_EXPOSURE_STEP		1
#define S5K4H7_EXPOSURE_MARGIN		4
#define S5K4H7_EXPOSURE_DEFAULT		0x03d0
#define S5K4H7_REG_ANALOG_GAIN		CCI_REG16(0x0204)
#define S5K4H7_ANALOG_GAIN_MIN		0x20
#define S5K4H7_ANALOG_GAIN_MAX		0x400
#define S5K4H7_ANALOG_GAIN_DEFAULT	0x20
#define S5K4H7_REG_FRAME_LENGTH		CCI_REG16(0x0340)
#define S5K4H7_FRAME_LENGTH_MAX		0xffff

struct s5k4h7_reg_list {
	const struct cci_reg_sequence *regs;
	unsigned int num_regs;
};

struct s5k4h7_mode {
	u32 width;
	u32 height;
	u32 hts;
	u32 vts;
	struct s5k4h7_reg_list reg_list;
};

struct s5k4h7 {
	struct device *dev;
	struct regmap *regmap;
	struct clk *xclk;
	struct gpio_desc *reset_gpio;
	struct regulator *vdda;
	struct regulator *vddio;
	struct regulator *vddd;

	struct v4l2_subdev sd;
	struct media_pad pad;
	struct v4l2_ctrl_handler ctrl_handler;
	struct v4l2_ctrl *link_freq;
	struct v4l2_ctrl *pixel_rate;
	struct v4l2_ctrl *hblank;
	struct v4l2_ctrl *vblank;
	struct v4l2_ctrl *exposure;
	struct v4l2_ctrl *hflip;
	struct v4l2_ctrl *vflip;

	const struct s5k4h7_mode *mode;
};

#define to_s5k4h7(_sd) container_of(_sd, struct s5k4h7, sd)

static const s64 s5k4h7_link_freq_menu[] = {
	S5K4H7_LINK_FREQ,
};

static const u32 s5k4h7_mbus_formats[] = {
	MEDIA_BUS_FMT_SGRBG10_1X10,
	MEDIA_BUS_FMT_SRGGB10_1X10,
	MEDIA_BUS_FMT_SBGGR10_1X10,
	MEDIA_BUS_FMT_SGBRG10_1X10,
};

/*
 * ZUI common initialization. Two writes to the read-only chip-ID register
 * found in the serialized CamX table are intentionally omitted. The rest
 * is byte-for-byte equivalent, including Lenovo's 0x0a02 = 0x15 setting.
 */
static const struct cci_reg_sequence s5k4h7_common_regs[] = {
	{ S5K4H7_REG_MODE_SELECT, 0x00 },
	{ CCI_REG8(0x0a02), 0x15 },
	{ S5K4H7_REG_MODE_SELECT, 0x00 },
	{ CCI_REG8(0x0b05), 0x01 },
	{ CCI_REG8(0x3074), 0x06 },
	{ CCI_REG8(0x3075), 0x2f },
	{ CCI_REG8(0x308a), 0x20 },
	{ CCI_REG8(0x308b), 0x08 },
	{ CCI_REG8(0x308c), 0x0b },
	{ CCI_REG8(0x3081), 0x07 },
	{ CCI_REG8(0x307b), 0x85 },
	{ CCI_REG8(0x307a), 0x0a },
	{ CCI_REG8(0x3079), 0x0a },
	{ CCI_REG8(0x306e), 0x71 },
	{ CCI_REG8(0x306f), 0x28 },
	{ CCI_REG8(0x301f), 0x20 },
	{ CCI_REG8(0x306b), 0x9a },
	{ CCI_REG8(0x3091), 0x1f },
	{ CCI_REG8(0x30c4), 0x06 },
	{ CCI_REG8(0x3200), 0x09 },
	{ CCI_REG8(0x306a), 0x79 },
	{ CCI_REG8(0x30b0), 0xff },
	{ CCI_REG8(0x306d), 0x08 },
	{ CCI_REG8(0x3080), 0x00 },
	{ CCI_REG8(0x3929), 0x3f },
	{ CCI_REG8(0x3084), 0x16 },
	{ CCI_REG8(0x3070), 0x0f },
	{ CCI_REG8(0x3b45), 0x01 },
	{ CCI_REG8(0x30c2), 0x05 },
	{ CCI_REG8(0x3069), 0x87 },
	{ CCI_REG8(0x3924), 0x7f },
	{ CCI_REG8(0x3925), 0xfd },
	{ CCI_REG8(0x3c08), 0xff },
	{ CCI_REG8(0x3c09), 0xff },
	{ CCI_REG8(0x3c31), 0xff },
	{ CCI_REG8(0x3c32), 0xff },
	{ CCI_REG8(0x300a), 0x52 },
	{ CCI_REG8(0x3012), 0x52 },
	{ CCI_REG8(0x3013), 0x36 },
	{ CCI_REG8(0x3019), 0x5f },
	{ CCI_REG8(0x301a), 0x57 },
	{ CCI_REG8(0x3024), 0x10 },
	{ CCI_REG8(0x3025), 0x4e },
	{ CCI_REG8(0x3026), 0x9a },
	{ CCI_REG8(0x302d), 0x0b },
	{ CCI_REG8(0x302e), 0x09 },
	{ CCI_REG8(0x3c0a), 0x05 },
	{ CCI_REG8(0x3930), 0x80 },
	{ CCI_REG8(0x3931), 0x02 },
	{ CCI_REG8(0x3932), 0x80 },
	{ CCI_REG8(0x3400), 0x00 },
	{ CCI_REG8(0x0b00), 0x01 },
};

static const struct cci_reg_sequence s5k4h7_3264x2448_regs[] = {
	{ S5K4H7_REG_MODE_SELECT, 0x00 },
	{ CCI_REG8(0x0136), 0x18 }, { CCI_REG8(0x0137), 0x00 },
	{ CCI_REG8(0x0305), 0x06 }, { CCI_REG8(0x0306), 0x00 },
	{ CCI_REG8(0x0307), 0x88 }, { CCI_REG8(0x030d), 0x06 },
	{ CCI_REG8(0x030e), 0x00 }, { CCI_REG8(0x030f), 0xab },
	{ CCI_REG8(0x3c1f), 0x00 }, { CCI_REG8(0x3c17), 0x00 },
	{ CCI_REG8(0x3c1c), 0x05 }, { CCI_REG8(0x3c1d), 0x15 },
	{ CCI_REG8(0x0301), 0x04 },
	{ CCI_REG8(0x0820), 0x02 }, { CCI_REG8(0x0821), 0xdc },
	{ CCI_REG8(0x0822), 0x00 }, { CCI_REG8(0x0823), 0x00 },
	{ CCI_REG8(0x0112), 0x0a }, { CCI_REG8(0x0113), 0x0a },
	{ CCI_REG8(0x0114), 0x03 }, { CCI_REG8(0x3906), 0x00 },
	{ CCI_REG8(0x0344), 0x00 }, { CCI_REG8(0x0345), 0x08 },
	{ CCI_REG8(0x0346), 0x00 }, { CCI_REG8(0x0347), 0x08 },
	{ CCI_REG8(0x0348), 0x0c }, { CCI_REG8(0x0349), 0xc7 },
	{ CCI_REG8(0x034a), 0x09 }, { CCI_REG8(0x034b), 0x97 },
	{ CCI_REG8(0x034c), 0x0c }, { CCI_REG8(0x034d), 0xc0 },
	{ CCI_REG8(0x034e), 0x09 }, { CCI_REG8(0x034f), 0x90 },
	{ CCI_REG8(0x0900), 0x00 }, { CCI_REG8(0x0901), 0x00 },
	{ CCI_REG8(0x0381), 0x01 }, { CCI_REG8(0x0383), 0x01 },
	{ CCI_REG8(0x0385), 0x01 }, { CCI_REG8(0x0387), 0x01 },
	{ S5K4H7_REG_ORIENTATION, 0x00 },
	{ CCI_REG8(0x0340), 0x09 }, { CCI_REG8(0x0341), 0xe2 },
	{ CCI_REG8(0x0342), 0x0d }, { CCI_REG8(0x0343), 0xfc },
	{ CCI_REG8(0x0200), 0x0d }, { CCI_REG8(0x0201), 0x6c },
	{ CCI_REG8(0x0202), 0x00 }, { CCI_REG8(0x0203), 0x02 },
	{ CCI_REG8(0x3400), 0x01 },
};

static const struct cci_reg_sequence s5k4h7_3264x1836_regs[] = {
	{ S5K4H7_REG_MODE_SELECT, 0x00 },
	{ CCI_REG8(0x0136), 0x18 }, { CCI_REG8(0x0137), 0x00 },
	{ CCI_REG8(0x0305), 0x06 }, { CCI_REG8(0x0306), 0x00 },
	{ CCI_REG8(0x0307), 0x88 }, { CCI_REG8(0x030d), 0x06 },
	{ CCI_REG8(0x030e), 0x00 }, { CCI_REG8(0x030f), 0xb7 },
	{ CCI_REG8(0x3c1f), 0x00 }, { CCI_REG8(0x3c17), 0x00 },
	{ CCI_REG8(0x3c1c), 0x05 }, { CCI_REG8(0x3c1d), 0x15 },
	{ CCI_REG8(0x0301), 0x04 },
	{ CCI_REG8(0x0820), 0x02 }, { CCI_REG8(0x0821), 0xdc },
	{ CCI_REG8(0x0822), 0x00 }, { CCI_REG8(0x0823), 0x00 },
	{ CCI_REG8(0x0112), 0x0a }, { CCI_REG8(0x0113), 0x0a },
	{ CCI_REG8(0x0114), 0x03 }, { CCI_REG8(0x3906), 0x00 },
	{ CCI_REG8(0x0344), 0x00 }, { CCI_REG8(0x0345), 0x08 },
	{ CCI_REG8(0x0346), 0x01 }, { CCI_REG8(0x0347), 0x3a },
	{ CCI_REG8(0x0348), 0x0c }, { CCI_REG8(0x0349), 0xc7 },
	{ CCI_REG8(0x034a), 0x08 }, { CCI_REG8(0x034b), 0x65 },
	{ CCI_REG8(0x034c), 0x0c }, { CCI_REG8(0x034d), 0xc0 },
	{ CCI_REG8(0x034e), 0x07 }, { CCI_REG8(0x034f), 0x2c },
	{ CCI_REG8(0x0900), 0x00 }, { CCI_REG8(0x0901), 0x00 },
	{ CCI_REG8(0x0381), 0x01 }, { CCI_REG8(0x0383), 0x01 },
	{ CCI_REG8(0x0385), 0x01 }, { CCI_REG8(0x0387), 0x01 },
	{ S5K4H7_REG_ORIENTATION, 0x00 },
	{ CCI_REG8(0x0340), 0x09 }, { CCI_REG8(0x0341), 0xe2 },
	{ CCI_REG8(0x0342), 0x0d }, { CCI_REG8(0x0343), 0xfc },
	{ CCI_REG8(0x0200), 0x0d }, { CCI_REG8(0x0201), 0x6c },
	{ CCI_REG8(0x0202), 0x00 }, { CCI_REG8(0x0203), 0x02 },
	{ CCI_REG8(0x3400), 0x01 },
};

static const struct s5k4h7_mode s5k4h7_modes[] = {
	{
		.width = 3264,
		.height = 2448,
		.hts = 3580,
		.vts = 2530,
		.reg_list = {
			.regs = s5k4h7_3264x2448_regs,
			.num_regs = ARRAY_SIZE(s5k4h7_3264x2448_regs),
		},
	},
	{
		.width = 3264,
		.height = 1836,
		.hts = 3580,
		.vts = 2530,
		.reg_list = {
			.regs = s5k4h7_3264x1836_regs,
			.num_regs = ARRAY_SIZE(s5k4h7_3264x1836_regs),
		},
	},
};

static int s5k4h7_set_ctrl(struct v4l2_ctrl *ctrl)
{
	struct s5k4h7 *sensor = container_of(ctrl->handler, struct s5k4h7,
					       ctrl_handler);
	const struct s5k4h7_mode *mode = sensor->mode;
	s64 exposure_max;
	int ret = 0;

	if (ctrl->id == V4L2_CID_VBLANK) {
		exposure_max = mode->height + ctrl->val - S5K4H7_EXPOSURE_MARGIN;
		__v4l2_ctrl_modify_range(sensor->exposure,
					 sensor->exposure->minimum, exposure_max,
					 sensor->exposure->step,
					 min_t(s64, sensor->exposure->default_value,
					       exposure_max));
	}

	if (!pm_runtime_get_if_active(sensor->dev))
		return 0;

	switch (ctrl->id) {
	case V4L2_CID_ANALOGUE_GAIN:
		ret = cci_write(sensor->regmap, S5K4H7_REG_ANALOG_GAIN,
				ctrl->val, NULL);
		break;
	case V4L2_CID_EXPOSURE:
		ret = cci_write(sensor->regmap, S5K4H7_REG_EXPOSURE,
				ctrl->val, NULL);
		break;
	case V4L2_CID_VBLANK:
		ret = cci_write(sensor->regmap, S5K4H7_REG_FRAME_LENGTH,
				ctrl->val + mode->height, NULL);
		break;
	case V4L2_CID_HFLIP:
	case V4L2_CID_VFLIP:
		ret = cci_write(sensor->regmap, S5K4H7_REG_ORIENTATION,
				(sensor->hflip->val ? S5K4H7_HFLIP : 0) |
				(sensor->vflip->val ? S5K4H7_VFLIP : 0), NULL);
		break;
	default:
		ret = -EINVAL;
		break;
	}

	pm_runtime_put(sensor->dev);
	return ret;
}

static const struct v4l2_ctrl_ops s5k4h7_ctrl_ops = {
	.s_ctrl = s5k4h7_set_ctrl,
};

static int s5k4h7_init_controls(struct s5k4h7 *sensor)
{
	const struct s5k4h7_mode *mode = sensor->mode;
	struct v4l2_ctrl_handler *hdl = &sensor->ctrl_handler;
	struct v4l2_fwnode_device_properties props;
	s64 hblank = mode->hts - mode->width;
	s64 vblank = mode->vts - mode->height;
	s64 exposure_max = mode->vts - S5K4H7_EXPOSURE_MARGIN;
	int ret;

	v4l2_ctrl_handler_init(hdl, 8);
	sensor->link_freq = v4l2_ctrl_new_int_menu(hdl, &s5k4h7_ctrl_ops,
						   V4L2_CID_LINK_FREQ,
				ARRAY_SIZE(s5k4h7_link_freq_menu) - 1, 0,
				s5k4h7_link_freq_menu);
	if (sensor->link_freq)
		sensor->link_freq->flags |= V4L2_CTRL_FLAG_READ_ONLY;

	sensor->pixel_rate = v4l2_ctrl_new_std(hdl, &s5k4h7_ctrl_ops,
					       V4L2_CID_PIXEL_RATE, S5K4H7_PIXEL_RATE,
				S5K4H7_PIXEL_RATE, 1, S5K4H7_PIXEL_RATE);
	sensor->hblank = v4l2_ctrl_new_std(hdl, &s5k4h7_ctrl_ops,
					   V4L2_CID_HBLANK, hblank, hblank, 1, hblank);
	if (sensor->hblank)
		sensor->hblank->flags |= V4L2_CTRL_FLAG_READ_ONLY;

	sensor->vblank = v4l2_ctrl_new_std(hdl, &s5k4h7_ctrl_ops,
					   V4L2_CID_VBLANK, vblank,
				S5K4H7_FRAME_LENGTH_MAX - mode->height, 1,
				vblank);
	sensor->exposure = v4l2_ctrl_new_std(hdl, &s5k4h7_ctrl_ops,
					     V4L2_CID_EXPOSURE, S5K4H7_EXPOSURE_MIN,
				exposure_max, S5K4H7_EXPOSURE_STEP,
				S5K4H7_EXPOSURE_DEFAULT);
	v4l2_ctrl_new_std(hdl, &s5k4h7_ctrl_ops, V4L2_CID_ANALOGUE_GAIN,
			  S5K4H7_ANALOG_GAIN_MIN, S5K4H7_ANALOG_GAIN_MAX,
			  1, S5K4H7_ANALOG_GAIN_DEFAULT);
	sensor->hflip = v4l2_ctrl_new_std(hdl, &s5k4h7_ctrl_ops,
					  V4L2_CID_HFLIP, 0, 1, 1, 0);
	sensor->vflip = v4l2_ctrl_new_std(hdl, &s5k4h7_ctrl_ops,
					  V4L2_CID_VFLIP, 0, 1, 1, 0);
	if (sensor->hflip)
		sensor->hflip->flags |= V4L2_CTRL_FLAG_MODIFY_LAYOUT;
	if (sensor->vflip)
		sensor->vflip->flags |= V4L2_CTRL_FLAG_MODIFY_LAYOUT;

	if (hdl->error) {
		ret = hdl->error;
		goto error;
	}

	ret = v4l2_fwnode_device_parse(sensor->dev, &props);
	if (ret)
		goto error;
	ret = v4l2_ctrl_new_fwnode_properties(hdl, &s5k4h7_ctrl_ops, &props);
	if (ret)
		goto error;

	sensor->sd.ctrl_handler = hdl;
	return 0;

error:
	v4l2_ctrl_handler_free(hdl);
	return ret;
}

static u32 s5k4h7_get_format_code(struct s5k4h7 *sensor)
{
	unsigned int index = (sensor->vflip->val ? 2 : 0) |
				 (sensor->hflip->val ? 1 : 0);

	return s5k4h7_mbus_formats[index];
}

static void s5k4h7_update_format(struct s5k4h7 *sensor,
				 const struct s5k4h7_mode *mode,
				 struct v4l2_mbus_framefmt *fmt)
{
	fmt->code = s5k4h7_get_format_code(sensor);
	fmt->width = mode->width;
	fmt->height = mode->height;
	fmt->field = V4L2_FIELD_NONE;
	fmt->colorspace = V4L2_COLORSPACE_RAW;
	fmt->ycbcr_enc = V4L2_YCBCR_ENC_DEFAULT;
	fmt->quantization = V4L2_QUANTIZATION_FULL_RANGE;
	fmt->xfer_func = V4L2_XFER_FUNC_NONE;
}

static int s5k4h7_set_format(struct v4l2_subdev *sd,
			     struct v4l2_subdev_state *state,
			     struct v4l2_subdev_format *fmt)
{
	struct s5k4h7 *sensor = to_s5k4h7(sd);
	const struct s5k4h7_mode *mode;
	s64 hblank, vblank, exposure_max;

	mode = v4l2_find_nearest_size(s5k4h7_modes, ARRAY_SIZE(s5k4h7_modes),
				      width, height, fmt->format.width,
				      fmt->format.height);
	s5k4h7_update_format(sensor, mode, &fmt->format);
	*v4l2_subdev_state_get_format(state, 0) = fmt->format;

	if (fmt->which != V4L2_SUBDEV_FORMAT_ACTIVE || sensor->mode == mode)
		return 0;

	hblank = mode->hts - mode->width;
	__v4l2_ctrl_modify_range(sensor->hblank, hblank, hblank, 1, hblank);
	vblank = mode->vts - mode->height;
	__v4l2_ctrl_modify_range(sensor->vblank, vblank,
				 S5K4H7_FRAME_LENGTH_MAX - mode->height, 1,
				 vblank);
	__v4l2_ctrl_s_ctrl(sensor->vblank, vblank);
	exposure_max = mode->vts - S5K4H7_EXPOSURE_MARGIN;
	__v4l2_ctrl_modify_range(sensor->exposure, S5K4H7_EXPOSURE_MIN,
				 exposure_max, S5K4H7_EXPOSURE_STEP,
				 S5K4H7_EXPOSURE_DEFAULT);
	__v4l2_ctrl_s_ctrl(sensor->exposure, S5K4H7_EXPOSURE_DEFAULT);
	sensor->mode = mode;

	return sensor->ctrl_handler.error;
}

static int s5k4h7_enum_mbus_code(struct v4l2_subdev *sd,
				 struct v4l2_subdev_state *state,
				  struct v4l2_subdev_mbus_code_enum *code)
{
	struct s5k4h7 *sensor = to_s5k4h7(sd);

	if (code->index)
		return -EINVAL;
	code->code = s5k4h7_get_format_code(sensor);
	return 0;
}

static int s5k4h7_enum_frame_size(struct v4l2_subdev *sd,
				  struct v4l2_subdev_state *state,
				   struct v4l2_subdev_frame_size_enum *fse)
{
	struct s5k4h7 *sensor = to_s5k4h7(sd);

	if (fse->index >= ARRAY_SIZE(s5k4h7_modes) ||
	    fse->code != s5k4h7_get_format_code(sensor))
		return -EINVAL;
	fse->min_width = s5k4h7_modes[fse->index].width;
	fse->max_width = fse->min_width;
	fse->min_height = s5k4h7_modes[fse->index].height;
	fse->max_height = fse->min_height;
	return 0;
}

static int s5k4h7_init_state(struct v4l2_subdev *sd,
			     struct v4l2_subdev_state *state)
{
	struct s5k4h7 *sensor = to_s5k4h7(sd);
	struct v4l2_subdev_format fmt = {
		.which = V4L2_SUBDEV_FORMAT_TRY,
		.pad = 0,
		.format = {
			.width = sensor->mode->width,
			.height = sensor->mode->height,
		},
	};

	return s5k4h7_set_format(sd, state, &fmt);
}

static int s5k4h7_enable_streams(struct v4l2_subdev *sd,
				 struct v4l2_subdev_state *state,
				  u32 pad, u64 streams_mask)
{
	struct s5k4h7 *sensor = to_s5k4h7(sd);
	const struct s5k4h7_reg_list *regs = &sensor->mode->reg_list;
	int ret;

	ret = pm_runtime_resume_and_get(sensor->dev);
	if (ret < 0)
		return ret;

	ret = cci_multi_reg_write(sensor->regmap, s5k4h7_common_regs,
				  ARRAY_SIZE(s5k4h7_common_regs), NULL);
	if (!ret)
		ret = cci_multi_reg_write(sensor->regmap, regs->regs,
					  regs->num_regs, NULL);
	if (!ret)
		ret = __v4l2_ctrl_handler_setup(sensor->sd.ctrl_handler);
	if (!ret)
		ret = cci_write(sensor->regmap, S5K4H7_REG_MODE_SELECT,
				S5K4H7_MODE_STREAMING, NULL);
	if (!ret)
		return 0;

	dev_err(sensor->dev, "failed to start streaming: %d\n", ret);
	pm_runtime_put_autosuspend(sensor->dev);
	return ret;
}

static int s5k4h7_disable_streams(struct v4l2_subdev *sd,
				  struct v4l2_subdev_state *state,
				   u32 pad, u64 streams_mask)
{
	struct s5k4h7 *sensor = to_s5k4h7(sd);
	int ret;

	ret = cci_write(sensor->regmap, S5K4H7_REG_MODE_SELECT,
			S5K4H7_MODE_STANDBY, NULL);
	pm_runtime_put_autosuspend(sensor->dev);
	return ret;
}

static const struct v4l2_subdev_video_ops s5k4h7_video_ops = {
	.s_stream = v4l2_subdev_s_stream_helper,
};

static const struct v4l2_subdev_pad_ops s5k4h7_pad_ops = {
	.set_fmt = s5k4h7_set_format,
	.get_fmt = v4l2_subdev_get_fmt,
	.enum_mbus_code = s5k4h7_enum_mbus_code,
	.enum_frame_size = s5k4h7_enum_frame_size,
	.enable_streams = s5k4h7_enable_streams,
	.disable_streams = s5k4h7_disable_streams,
};

static const struct v4l2_subdev_ops s5k4h7_subdev_ops = {
	.video = &s5k4h7_video_ops,
	.pad = &s5k4h7_pad_ops,
};

static const struct v4l2_subdev_internal_ops s5k4h7_internal_ops = {
	.init_state = s5k4h7_init_state,
};

static const struct media_entity_operations s5k4h7_entity_ops = {
	.link_validate = v4l2_subdev_link_validate,
};

static int s5k4h7_check_hwcfg(struct s5k4h7 *sensor)
{
	struct fwnode_handle *ep;
	struct v4l2_fwnode_endpoint bus_cfg = {
		.bus_type = V4L2_MBUS_CSI2_DPHY,
	};
	unsigned long freq_bitmap;
	int ret;

	ep = fwnode_graph_get_next_endpoint(dev_fwnode(sensor->dev), NULL);
	if (!ep)
		return -EINVAL;
	ret = v4l2_fwnode_endpoint_alloc_parse(ep, &bus_cfg);
	fwnode_handle_put(ep);
	if (ret)
		return ret;
	if (bus_cfg.bus.mipi_csi2.num_data_lanes != S5K4H7_DATA_LANES) {
		ret = -EINVAL;
		goto free_endpoint;
	}
	ret = v4l2_link_freq_to_bitmap(sensor->dev, bus_cfg.link_frequencies,
				       bus_cfg.nr_of_link_frequencies,
				       s5k4h7_link_freq_menu,
				       ARRAY_SIZE(s5k4h7_link_freq_menu),
				       &freq_bitmap);

free_endpoint:
	v4l2_fwnode_endpoint_free(&bus_cfg);
	return ret;
}

static int s5k4h7_power_on(struct device *dev)
{
	struct s5k4h7 *sensor = to_s5k4h7(dev_get_drvdata(dev));
	int ret;

	/* Reproduce the stock VANA -> VIO -> VDIG -> RESET -> MCLK order. */
	ret = regulator_enable(sensor->vdda);
	if (ret)
		return ret;
	ret = regulator_enable(sensor->vddio);
	if (ret)
		goto disable_vdda;
	ret = regulator_enable(sensor->vddd);
	if (ret)
		goto disable_vddio;
	fsleep(5 * USEC_PER_MSEC);

	gpiod_set_value_cansleep(sensor->reset_gpio, 0);
	fsleep(12 * USEC_PER_MSEC);
	ret = clk_prepare_enable(sensor->xclk);
	if (ret)
		goto assert_reset;
	fsleep(10 * USEC_PER_MSEC);
	return 0;

assert_reset:
	gpiod_set_value_cansleep(sensor->reset_gpio, 1);
	regulator_disable(sensor->vddd);
disable_vddio:
	regulator_disable(sensor->vddio);
disable_vdda:
	regulator_disable(sensor->vdda);
	return ret;
}

static int s5k4h7_power_off(struct device *dev)
{
	struct s5k4h7 *sensor = to_s5k4h7(dev_get_drvdata(dev));

	clk_disable_unprepare(sensor->xclk);
	fsleep(USEC_PER_MSEC);
	gpiod_set_value_cansleep(sensor->reset_gpio, 1);
	fsleep(USEC_PER_MSEC);
	regulator_disable(sensor->vddd);
	regulator_disable(sensor->vddio);
	regulator_disable(sensor->vdda);
	return 0;
}

static int s5k4h7_identify(struct s5k4h7 *sensor)
{
	u64 id;
	int ret;

	ret = cci_read(sensor->regmap, S5K4H7_REG_CHIP_ID, &id, NULL);
	if (ret)
		return ret;
	if (id != S5K4H7_CHIP_ID)
		return dev_err_probe(sensor->dev, -ENODEV,
				     "chip ID mismatch: expected %04x, got %04llx\n",
				     S5K4H7_CHIP_ID, id);
	return 0;
}

static int s5k4h7_probe(struct i2c_client *client)
{
	struct s5k4h7 *sensor;
	unsigned long rate;
	int ret;

	sensor = devm_kzalloc(&client->dev, sizeof(*sensor), GFP_KERNEL);
	if (!sensor)
		return -ENOMEM;
	sensor->dev = &client->dev;
	v4l2_i2c_subdev_init(&sensor->sd, client, &s5k4h7_subdev_ops);

	sensor->regmap = devm_cci_regmap_init_i2c(client, 16);
	if (IS_ERR(sensor->regmap))
		return dev_err_probe(sensor->dev, PTR_ERR(sensor->regmap),
				     "failed to initialize CCI\n");
	sensor->xclk = devm_v4l2_sensor_clk_get(sensor->dev, NULL);
	if (IS_ERR(sensor->xclk))
		return dev_err_probe(sensor->dev, PTR_ERR(sensor->xclk),
				     "failed to get external clock\n");
	rate = clk_get_rate(sensor->xclk);
	if (rate != S5K4H7_XCLK_FREQ)
		return dev_err_probe(sensor->dev, -EINVAL,
				     "unsupported clock frequency %lu\n", rate);

	ret = s5k4h7_check_hwcfg(sensor);
	if (ret)
		return dev_err_probe(sensor->dev, ret,
				     "invalid endpoint configuration\n");
	sensor->reset_gpio = devm_gpiod_get(sensor->dev, "reset",
					    GPIOD_OUT_HIGH);
	if (IS_ERR(sensor->reset_gpio))
		return dev_err_probe(sensor->dev, PTR_ERR(sensor->reset_gpio),
				     "failed to get reset GPIO\n");
	sensor->vdda = devm_regulator_get(sensor->dev, "vdda");
	if (IS_ERR(sensor->vdda))
		return dev_err_probe(sensor->dev, PTR_ERR(sensor->vdda),
				     "failed to get vdda supply\n");
	sensor->vddio = devm_regulator_get(sensor->dev, "vddio");
	if (IS_ERR(sensor->vddio))
		return dev_err_probe(sensor->dev, PTR_ERR(sensor->vddio),
				     "failed to get vddio supply\n");
	sensor->vddd = devm_regulator_get(sensor->dev, "vddd");
	if (IS_ERR(sensor->vddd))
		return dev_err_probe(sensor->dev, PTR_ERR(sensor->vddd),
				     "failed to get vddd supply\n");

	ret = s5k4h7_power_on(sensor->dev);
	if (ret)
		return ret;
	ret = s5k4h7_identify(sensor);
	if (ret)
		goto power_off;

	sensor->mode = &s5k4h7_modes[0];
	ret = s5k4h7_init_controls(sensor);
	if (ret)
		goto power_off;
	sensor->sd.state_lock = sensor->ctrl_handler.lock;
	sensor->sd.internal_ops = &s5k4h7_internal_ops;
	sensor->sd.flags |= V4L2_SUBDEV_FL_HAS_DEVNODE;
	sensor->sd.entity.ops = &s5k4h7_entity_ops;
	sensor->sd.entity.function = MEDIA_ENT_F_CAM_SENSOR;
	sensor->pad.flags = MEDIA_PAD_FL_SOURCE;

	ret = media_entity_pads_init(&sensor->sd.entity, 1, &sensor->pad);
	if (ret)
		goto free_controls;
	ret = v4l2_subdev_init_finalize(&sensor->sd);
	if (ret)
		goto cleanup_entity;

	pm_runtime_set_active(sensor->dev);
	pm_runtime_enable(sensor->dev);
	pm_runtime_set_autosuspend_delay(sensor->dev, 1000);
	pm_runtime_use_autosuspend(sensor->dev);

	ret = v4l2_async_register_subdev_sensor(&sensor->sd);
	if (ret)
		goto cleanup_subdev;
	pm_runtime_idle(sensor->dev);
	return 0;

cleanup_subdev:
	pm_runtime_disable(sensor->dev);
	v4l2_subdev_cleanup(&sensor->sd);
cleanup_entity:
	media_entity_cleanup(&sensor->sd.entity);
free_controls:
	v4l2_ctrl_handler_free(&sensor->ctrl_handler);
power_off:
	s5k4h7_power_off(sensor->dev);
	return ret;
}

static void s5k4h7_remove(struct i2c_client *client)
{
	struct v4l2_subdev *sd = i2c_get_clientdata(client);
	struct s5k4h7 *sensor = to_s5k4h7(sd);

	v4l2_async_unregister_subdev(sd);
	v4l2_subdev_cleanup(sd);
	media_entity_cleanup(&sd->entity);
	v4l2_ctrl_handler_free(sd->ctrl_handler);
	pm_runtime_disable(sensor->dev);
	if (!pm_runtime_status_suspended(sensor->dev)) {
		s5k4h7_power_off(sensor->dev);
		pm_runtime_set_suspended(sensor->dev);
	}
}

static const struct dev_pm_ops s5k4h7_pm_ops = {
	SET_RUNTIME_PM_OPS(s5k4h7_power_off, s5k4h7_power_on, NULL)
};

static const struct of_device_id s5k4h7_of_match[] = {
	{ .compatible = "samsung,s5k4h7" },
	{ }
};
MODULE_DEVICE_TABLE(of, s5k4h7_of_match);

static struct i2c_driver s5k4h7_i2c_driver = {
	.driver = {
		.name = "s5k4h7",
		.pm = &s5k4h7_pm_ops,
		.of_match_table = s5k4h7_of_match,
	},
	.probe = s5k4h7_probe,
	.remove = s5k4h7_remove,
};
module_i2c_driver(s5k4h7_i2c_driver);

MODULE_DESCRIPTION("Samsung S5K4H7 image sensor driver");
MODULE_LICENSE("GPL");
