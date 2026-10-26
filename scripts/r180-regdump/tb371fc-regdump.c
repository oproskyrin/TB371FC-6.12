// SPDX-License-Identifier: GPL-2.0-only
/*
 * TB371FC: read-only dump of the SM8250 display path registers (DPU 6.0 + DSI), for comparing the
 * working Lenovo 4.19 SDE state with Linux 6.12 DPU. Builds for 4.19 and 6.12. Offsets from the
 * upstream sm8250 DPU catalog (relative to MDP 0x0ae01000) and the DSI controllers.
 */
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/module.h>

struct tb_range { const char *name; u32 phys; u32 len; };

static const struct tb_range tb_ranges[] = {
	{ "MDP_TOP", 0x0ae01000, 0x494 },
	{ "CTL_0",   0x0ae02000, 0x1e4 },
	{ "CTL_1",   0x0ae02200, 0x1e4 },
	{ "CTL_2",   0x0ae02400, 0x1e4 },
	{ "CTL_3",   0x0ae02600, 0x1e4 },
	{ "CTL_4",   0x0ae02800, 0x1e4 },
	{ "CTL_5",   0x0ae02a00, 0x1e4 },
	{ "LM_0",    0x0ae45000, 0x320 },
	{ "LM_1",    0x0ae46000, 0x320 },
	{ "PP_0",    0x0ae71000, 0x0d4 },
	{ "PP_1",    0x0ae71800, 0x0d4 },
	{ "MERGE3D_0", 0x0ae84000, 0x010 },
	{ "DSC_0",   0x0ae81000, 0x140 },
	{ "DSC_1",   0x0ae81400, 0x140 },
	{ "INTF_1",  0x0ae6b800, 0x2c4 },
	{ "INTF_2",  0x0ae6c000, 0x2c4 },
	{ "SSPP_DMA0", 0x0ae25000, 0x1f0 },
	{ "DSI_0",   0x0ae94000, 0x400 },
	{ "DSI_1",   0x0ae96000, 0x400 },
	{ "PHY0_CMN",  0x0ae94400, 0x200 },
	{ "PHY0_LANE", 0x0ae94600, 0x280 },
	{ "PHY0_PLL",  0x0ae94900, 0x260 },
	{ "PHY1_CMN",  0x0ae96400, 0x200 },
	{ "PHY1_LANE", 0x0ae96600, 0x280 },
	{ "PHY1_PLL",  0x0ae96900, 0x260 },
};

static int __init tb_regdump_init(void)
{
	unsigned int r, i;

	for (r = 0; r < ARRAY_SIZE(tb_ranges); r++) {
		void __iomem *b = ioremap(tb_ranges[r].phys, tb_ranges[r].len);

		if (!b) {
			pr_info("TB371FC_REG %s ioremap failed\n", tb_ranges[r].name);
			continue;
		}
		pr_info("TB371FC_REG == %s %08x\n", tb_ranges[r].name, tb_ranges[r].phys);
		for (i = 0; i + 16 <= tb_ranges[r].len; i += 16)
			pr_info("TB371FC_REG %08x: %08x %08x %08x %08x\n", tb_ranges[r].phys + i,
				readl_relaxed(b + i), readl_relaxed(b + i + 4),
				readl_relaxed(b + i + 8), readl_relaxed(b + i + 12));
		iounmap(b);
	}
	pr_info("TB371FC_REG done\n");
	return 0;
}

static void __exit tb_regdump_exit(void) { }

module_init(tb_regdump_init);
module_exit(tb_regdump_exit);
MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("TB371FC read-only display register dump");
