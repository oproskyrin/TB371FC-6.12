// SPDX-License-Identifier: GPL-2.0-only
/*
 * TB371FC camera power experiment: attach and hold the power domains listed in the
 * "tb371fc,camvote" DT node (RPMh MX/MMCX at nominal, GCC MMNOC TBU GDSCs), one per second,
 * so the camera clock controller access can be retried with each extra vote.
 */
#include <linux/delay.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/pm_domain.h>
#include <linux/pm_runtime.h>

static int upto = 16;
module_param(upto, int, 0444);
static uint perf = 256;
module_param(perf, uint, 0444);

static int camvote_probe(struct platform_device *pdev)
{
	int i, n = of_property_count_strings(pdev->dev.of_node, "power-domain-names");

	for (i = 0; i < n && i < upto; i++) {
		const char *name;
		struct device *pd;
		int ret;

		of_property_read_string_index(pdev->dev.of_node, "power-domain-names", i, &name);
		pd = dev_pm_domain_attach_by_name(&pdev->dev, name);
		if (IS_ERR_OR_NULL(pd)) {
			dev_info(&pdev->dev, "%s: attach failed %ld\n", name, PTR_ERR(pd));
			continue;
		}
		if (!strcmp(name, "mx") || !strcmp(name, "mmcx") || !strcmp(name, "cx")) {
			ret = dev_pm_genpd_set_performance_state(pd, perf);
			dev_info(&pdev->dev, "%s: performance %u -> %d\n", name, perf, ret);
		}
		ret = pm_runtime_resume_and_get(pd);
		dev_info(&pdev->dev, "%s: on -> %d\n", name, ret);
		msleep(1000);
	}
	return 0;
}

static const struct of_device_id camvote_match[] = { { .compatible = "tb371fc,camvote" }, { } };
MODULE_DEVICE_TABLE(of, camvote_match);
static struct platform_driver camvote_driver = {
	.probe = camvote_probe,
	.driver = { .name = "tb371fc-camvote", .of_match_table = camvote_match },
};
module_platform_driver(camvote_driver);
MODULE_LICENSE("GPL");
