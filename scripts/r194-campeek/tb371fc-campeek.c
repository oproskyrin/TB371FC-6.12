// SPDX-License-Identifier: GPL-2.0-only
/*
 * TB371FC camera clock controller probe aid: read-only accesses to CAM_CC (0x0ad00000) registers,
 * one per 700 ms, logged before each access, to find which access hangs the bus.
 */
#include <linux/delay.h>
#include <linux/io.h>
#include <linux/module.h>

static u32 offs[16] = { 0x0000, 0x0004, 0x1000, 0x2000, 0x3000, 0x4000, 0x7004, 0xc144, 0xc1a0, 0xc1bc };
static int noffs;
module_param_array(offs, uint, &noffs, 0444);
static int upto = 10;
module_param(upto, int, 0444);
static ulong base = 0x0ad00000;
module_param(base, ulong, 0444);

static int __init campeek_init(void)
{
	void __iomem *b = ioremap(base, 0x80000);
	int i;

	if (!b)
		return -ENOMEM;
	if (noffs)
		upto = noffs;
	for (i = 0; i < upto && i < ARRAY_SIZE(offs); i++) {
		pr_info("tb371fc-campeek: reading +0x%04x ...\n", offs[i]);
		msleep(700);
		pr_info("tb371fc-campeek: +0x%04x = 0x%08x\n", offs[i], readl(b + offs[i]));
		msleep(300);
	}
	iounmap(b);
	pr_info("tb371fc-campeek: done\n");
	return -EAGAIN;	/* never stays loaded */
}
module_init(campeek_init);
MODULE_LICENSE("GPL");
