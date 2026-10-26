// SPDX-License-Identifier: GPL-2.0
/*
 * TB371FC microSD (SDHC2, behind a BayHub BH201 bridge) write fix for Linux 6.12.
 *
 * Lenovo 4.19 runs the card in SDR104, so the SDHC2 IO rail (pm8150a L6) is at 1.8 V when 4.19
 * kexecs into 6.12. 6.12 has no regulator control for SDHC2 and leaves CORE_VENDOR_SPEC at its
 * power-on value, i.e. IO pads in 3.0 V mode. With 1.8 V on 3.0 V pads, reads still work but
 * host-driven transfers fail (command and write data CRC errors, "card removed"). Switching the
 * pads to 1.8 V fixes writes (300/300 16 KiB write+verify cycles, no errors).
 *
 * This module sets the pads to 1.8 V on the running host and again after every controller reset;
 * it can also fix the data timeout counter at 0xE as Lenovo does (off by default, not needed).
 */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/pm_runtime.h>
#include <linux/mmc/host.h>
#include "sdhci.h"

static bool fix_timeout;
module_param(fix_timeout, bool, 0444);
MODULE_PARM_DESC(fix_timeout, "fix the data timeout counter at 0xE (Lenovo 4.19 behaviour)");
static bool dump;
module_param(dump, bool, 0444);

#define TB_VENDOR_SPEC		0x20c	/* sdhci-msm v5 core_vendor_spec */
#define TB_PAD_SWITCH_EN	BIT(15)
#define TB_PAD_SWITCH_1V8	BIT(16)

static struct sdhci_host *bh_host;
static const struct sdhci_ops *orig_ops;
static struct sdhci_ops bh_ops;

static void bh201_pads_1v8(struct sdhci_host *host)
{
	u32 v = readl(host->ioaddr + TB_VENDOR_SPEC);

	if ((v & (TB_PAD_SWITCH_EN | TB_PAD_SWITCH_1V8)) != (TB_PAD_SWITCH_EN | TB_PAD_SWITCH_1V8))
		writel(v | TB_PAD_SWITCH_EN | TB_PAD_SWITCH_1V8, host->ioaddr + TB_VENDOR_SPEC);
}

static void bh201_reset(struct sdhci_host *host, u8 mask)
{
	orig_ops->reset(host, mask);
	bh201_pads_1v8(host);
}

static void bh201_set_timeout(struct sdhci_host *host, struct mmc_command *cmd)
{
	sdhci_writeb(host, 0xE, SDHCI_TIMEOUT_CONTROL);
	if (cmd && cmd->data)
		host->data_timeout = 22LL * NSEC_PER_SEC;
}

static void bh201_dump(struct sdhci_host *host)
{
	int i;

	for (i = 0; i < 0x80; i += 16)
		pr_info("tb371fc-bh201: sdhci %02x: %08x %08x %08x %08x\n", i,
			readl(host->ioaddr + i), readl(host->ioaddr + i + 4),
			readl(host->ioaddr + i + 8), readl(host->ioaddr + i + 12));
	for (i = 0x200; i < 0x270; i += 16)
		pr_info("tb371fc-bh201: vendor %03x: %08x %08x %08x %08x\n", i,
			readl(host->ioaddr + i), readl(host->ioaddr + i + 4),
			readl(host->ioaddr + i + 8), readl(host->ioaddr + i + 12));
}

static int __init bh201_init(void)
{
	struct device_node *np = of_find_node_by_path("/soc@0/mmc@8804000");
	struct platform_device *pdev;
	struct device *dev;

	if (!np)
		return -ENODEV;
	pdev = of_find_device_by_node(np);
	of_node_put(np);
	if (!pdev)
		return -ENODEV;
	bh_host = platform_get_drvdata(pdev);
	put_device(&pdev->dev);
	if (!bh_host || !bh_host->ops || !bh_host->ops->reset)
		return -ENODEV;
	dev = mmc_dev(bh_host->mmc);

	orig_ops = bh_host->ops;
	bh_ops = *orig_ops;
	bh_ops.reset = bh201_reset;
	if (fix_timeout)
		bh_ops.set_timeout = bh201_set_timeout;
	WRITE_ONCE(bh_host->ops, &bh_ops);

	pm_runtime_get_sync(dev);
	bh201_pads_1v8(bh_host);
	if (dump)
		bh201_dump(bh_host);
	pr_info("tb371fc-bh201: %s IO pads 1.8 V (vendor_spec %08x)%s\n",
		mmc_hostname(bh_host->mmc), readl(bh_host->ioaddr + TB_VENDOR_SPEC),
		fix_timeout ? ", data timeout 0xE" : "");
	pm_runtime_mark_last_busy(dev);
	pm_runtime_put_autosuspend(dev);
	return 0;
}

static void __exit bh201_exit(void)
{
	/* the pads stay at 1.8 V (the rail is 1.8 V); only the hooks are removed */
	WRITE_ONCE(bh_host->ops, orig_ops);
	synchronize_rcu();
}

module_init(bh201_init);
module_exit(bh201_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC microSD (BayHub BH201 bridge) write fix: SDHC2 IO pads at 1.8 V");
