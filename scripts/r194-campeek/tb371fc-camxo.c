// SPDX-License-Identifier: GPL-2.0-only
/*
 * TB371FC camera bring-up aid: enable and hold selected GCC branch clocks (ids from
 * dt-bindings/clock/qcom,gcc-sm8250.h; default GCC_CAMERA_XO_CLK) before CAM_CC is touched.
 */
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/module.h>
#include <linux/of.h>

static uint ids[8] = { 13 };
static int nids = 1;
module_param_array(ids, uint, &nids, 0444);
static struct clk *clks[8];

static int __init camxo_init(void)
{
	struct of_phandle_args a = { .args_count = 1 };
	int i, ret;

	a.np = of_find_node_by_path("/soc@0/clock-controller@100000");
	if (!a.np)
		return -ENODEV;
	for (i = 0; i < nids && i < 8; i++) {
		a.args[0] = ids[i];
		clks[i] = of_clk_get_from_provider(&a);
		if (IS_ERR(clks[i])) {
			pr_info("tb371fc-camxo: gcc id %u: %ld\n", ids[i], PTR_ERR(clks[i]));
			clks[i] = NULL;
			continue;
		}
		pr_info("tb371fc-camxo: %s enabled before: %d\n", __clk_get_name(clks[i]),
			__clk_is_enabled(clks[i]));
		ret = clk_prepare_enable(clks[i]);
		pr_info("tb371fc-camxo: %s enable -> %d\n", __clk_get_name(clks[i]), ret);
	}
	of_node_put(a.np);
	return 0;
}

static void __exit camxo_exit(void)
{
	int i;

	for (i = 0; i < nids && i < 8; i++)
		if (clks[i]) {
			clk_disable_unprepare(clks[i]);
			clk_put(clks[i]);
		}
}

module_init(camxo_init);
module_exit(camxo_exit);
MODULE_LICENSE("GPL");
