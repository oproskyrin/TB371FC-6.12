// SPDX-License-Identifier: GPL-2.0-only
/* Exact-card150MHz boot transition, BEFORE mounting root. No runtime clock
 * table replacement: the R224 kernel contains a real150MHz GCC entry.
 * Same guarded transition as R210; release the RO exclusive claim at completion.
 */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/blkdev.h>
#include <linux/file.h>
#include <linux/mmc/host.h>
#include <linux/mmc/card.h>
#include "sdhci.h"
int __mmc_claim_host(struct mmc_host *, struct mmc_ctx *, atomic_t *);
void mmc_release_host(struct mmc_host *);
static int __init boot_init(void)
{
 struct device_node *np;
 struct platform_device *pdev;
 struct sdhci_host *host;
 struct mmc_host *mmc;
 struct file *disk;
 int ret;
 np=of_find_node_by_path("/chosen");
 ret=np && of_property_read_bool(np,"tb371fc,sd150");
 of_node_put(np);
 if (!ret) return -EPERM;
 np=of_find_node_by_path("/soc@0/mmc@8804000");
 pdev=np ? of_find_device_by_node(np) : NULL;
 of_node_put(np);
 if (!pdev) return -ENODEV;
 host=platform_get_drvdata(pdev);
 if (!host || !host->mmc || !host->mmc->card) {ret=-ENODEV;goto put;}
 mmc=host->mmc;
 if (memcmp(mmc->card->raw_cid,(u32[]){0x1b534d45,0x44325335,0x3044f468,0x49a18800},16)) {ret=-ENODEV;goto put;}
 disk=bdev_file_open_by_path("/dev/mmcblk0",BLK_OPEN_READ|BLK_OPEN_EXCL,THIS_MODULE,NULL);
 if (IS_ERR(disk)) {ret=PTR_ERR(disk);goto put;}
 if (!bdev_read_only(file_bdev(disk))) {ret=-EROFS;goto close;}
 __mmc_claim_host(mmc,NULL,NULL);
 host->quirks2&=~SDHCI_QUIRK2_NO_1_8_V;
 host->caps1=sdhci_readl(host,SDHCI_CAPABILITIES_1);
 host->flags|=SDHCI_SIGNALING_180;
 if (host->caps1&SDHCI_USE_SDR50_TUNING) host->flags|=SDHCI_SDR50_NEEDS_TUNING;
 // Reproduce the tested fresh-boot sequence exactly: SDR50/100 then SDR104/150.
 mmc->caps|=MMC_CAP_UHS_SDR12|MMC_CAP_UHS_SDR25|MMC_CAP_UHS_SDR50;
 mmc->caps&=~MMC_CAP_UHS_SDR104;
 mmc->f_max=100000000;
 ret=mmc_hw_reset(mmc->card);
 if (ret || !mmc->card || mmc->ios.timing!=MMC_TIMING_UHS_SDR50 ||
     mmc->ios.clock!=100000000 || mmc->actual_clock!=100000000) {
  ret=ret ?: -EIO;
  goto release_host;
 }
 pr_info("R224 intermediate SDR50/100MHz verified; root still UNMOUNTED/RO\n");
 mmc->caps|=MMC_CAP_UHS_SDR104;
 mmc->f_max=150000000;
 ret=mmc_hw_reset(mmc->card);
 if (!ret && (mmc->ios.timing!=MMC_TIMING_UHS_SDR104 ||
              mmc->ios.clock!=150000000 || mmc->actual_clock!=150000000)) ret=-EIO;
 pr_info("R224 SD150 reset=%d timing=%u requested=%u actual=%u; root still UNMOUNTED/RO\n",
         ret,mmc->ios.timing,mmc->ios.clock,mmc->actual_clock);
release_host:
 mmc_release_host(mmc);
close:
 fput(disk);
put:
 put_device(&pdev->dev);
 return ret;
}
static void __exit boot_exit(void) {}
module_init(boot_init);
module_exit(boot_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC exact-card150MHz pre-root boot transition for R224 GCC kernel");
