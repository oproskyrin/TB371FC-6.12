// SPDX-License-Identifier: GPL-2.0
/*
 * TB371FC microSD UHS-I switch (loaded by the initramfs before the root is mounted): enable UHS
 * modes on the running SDHC2 host and re-initialise the card with mmc_hw_reset(). Enabling UHS
 * at host probe hangs the boot, switching afterwards works. The card is
 * still in 1.8 V signalling from the vendor kernel (no power cycle), so the core's v18 fixup
 * path selects a UHS bus speed without CMD11. modes: bit0 SDR50, bit1 SDR104.
 */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/mmc/host.h>
#include <linux/mmc/card.h>
#include "sdhci.h"

/* exported by mmc core (drivers/mmc/core/core.c), declared in its private core.h */
int __mmc_claim_host(struct mmc_host *host, struct mmc_ctx *ctx, atomic_t *abort);
void mmc_release_host(struct mmc_host *host);

static int modes = 1;
module_param(modes, int, 0444);
static unsigned int fmax; /* 0: 202 MHz for SDR104, 100 MHz for SDR50 */
module_param(fmax, uint, 0444);

static int __init uhs_init(void)
{
	struct device_node *np = of_find_node_by_path("/soc@0/mmc@8804000");
	struct platform_device *pdev;
	struct sdhci_host *host;
	struct mmc_host *mmc;
	struct mmc_card *card;
	int ret;

	if (!np)
		return -ENODEV;
	pdev = of_find_device_by_node(np);
	of_node_put(np);
	if (!pdev)
		return -ENODEV;
	host = platform_get_drvdata(pdev);
	put_device(&pdev->dev);
	if (!host)
		return -ENODEV;
	mmc = host->mmc;
	card = mmc->card;
	if (!card)
		return -ENODEV;
	pr_info("tb371fc-uhs: before: timing %u clock %u f_max %u caps %08x caps1 %08x(reg %08x) flags %08x quirks2 %08x sd3_bus_mode %02x\n",
		mmc->ios.timing, mmc->ios.clock, mmc->f_max, mmc->caps, host->caps1,
		sdhci_readl(host, SDHCI_CAPABILITIES_1), host->flags, host->quirks2,
		card->sw_caps.sd3_bus_mode);

	host->quirks2 &= ~SDHCI_QUIRK2_NO_1_8_V;
	host->caps1 = sdhci_readl(host, SDHCI_CAPABILITIES_1);
	host->flags |= SDHCI_SIGNALING_180;
	if (host->caps1 & SDHCI_USE_SDR50_TUNING)
		host->flags |= SDHCI_SDR50_NEEDS_TUNING;
	mmc->caps |= MMC_CAP_UHS_SDR12 | MMC_CAP_UHS_SDR25;
	if (modes & 1)
		mmc->caps |= MMC_CAP_UHS_SDR50;
	if (modes & 2)
		mmc->caps |= MMC_CAP_UHS_SDR104;
	mmc->f_max = fmax ? fmax : ((modes & 2) ? 202000000 : 100000000);

	__mmc_claim_host(mmc, NULL, NULL);
	ret = mmc_hw_reset(card);
	mmc_release_host(mmc);
	pr_info("tb371fc-uhs: hw_reset %d: timing %u clock %u signal %u sd3_bus_mode %02x\n",
		ret, mmc->ios.timing, mmc->ios.clock, mmc->ios.signal_voltage,
		card->sw_caps.sd3_bus_mode);
	return 0;
}

static void __exit uhs_exit(void) { }

module_init(uhs_init);
module_exit(uhs_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC microSD UHS-I switch (SDR50 default; SDR104 reads only, writes need BH201 output tuning)");
