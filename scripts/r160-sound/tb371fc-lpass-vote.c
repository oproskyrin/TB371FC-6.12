// SPDX-License-Identifier: GPL-2.0
/*
 * Test helper for TB371FC: hold the LPASS core/audio HW votes (q6afe-clocks
 * LPASS_HW_MACRO_VOTE and LPASS_HW_DCODEC_VOTE) that the upstream LPI pinctrl
 * driver would hold, without touching LPI registers. Binds to the LPI pinctrl
 * DT node only because this kernel lacks GENERIC_PINCTRL_GROUPS.
 */
#include <linux/clk.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>

static int lpass_vote_probe(struct platform_device *pdev)
{
	struct clk_bulk_data *clks;
	int n, ret;

	n = devm_clk_bulk_get_all(&pdev->dev, &clks);
	if (n < 0)
		return dev_err_probe(&pdev->dev, n, "get clocks\n");
	ret = clk_bulk_prepare_enable(n, clks);
	if (ret)
		return dev_err_probe(&pdev->dev, ret, "enable clocks\n");
	platform_set_drvdata(pdev, clks);
	dev_set_drvdata(&pdev->dev, clks);
	dev_info(&pdev->dev, "holding %d LPASS HW vote clocks\n", n);
	pdev->dev.platform_data = (void *)(long)n;
	return 0;
}

static void lpass_vote_remove(struct platform_device *pdev)
{
	clk_bulk_disable_unprepare((long)pdev->dev.platform_data,
				   platform_get_drvdata(pdev));
}

static const struct of_device_id lpass_vote_match[] = {
	{ .compatible = "qcom,sm8250-lpass-lpi-pinctrl" },
	{ }
};
MODULE_DEVICE_TABLE(of, lpass_vote_match);

static struct platform_driver lpass_vote_driver = {
	.probe = lpass_vote_probe,
	.remove_new = lpass_vote_remove,
	.driver = { .name = "tb371fc-lpass-vote", .of_match_table = lpass_vote_match },
};
module_platform_driver(lpass_vote_driver);
MODULE_DESCRIPTION("TB371FC test: hold LPASS HW votes");
MODULE_LICENSE("GPL");
