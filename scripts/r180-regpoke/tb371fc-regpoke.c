// SPDX-License-Identifier: GPL-2.0-only
/*
 * TB371FC: write up to 8 display registers on the running Linux 6.12 DPU/DSI (experiments while a
 * test pattern is shown). regs=addr:val,addr:val (hex). Each write is read back and logged.
 */
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/string.h>

static char *regs = "";
module_param(regs, charp, 0444);

static int __init tb_poke_init(void)
{
	char *buf = kstrdup(regs, GFP_KERNEL), *p = buf, *tok;
	int n = 0;

	if (!buf)
		return -ENOMEM;
	while ((tok = strsep(&p, ",")) && n < 8) {
		u32 addr, val;
		void __iomem *b;
		char *c = strchr(tok, ':');

		if (!c)
			continue;
		*c = 0;
		if (kstrtou32(tok, 16, &addr) || kstrtou32(c + 1, 16, &val))
			continue;
		b = ioremap(addr & ~0xfffu, 0x1000);
		if (!b)
			continue;
		pr_info("TB371FC_POKE %08x: %08x -> %08x", addr, readl(b + (addr & 0xfff)), val);
		writel(val, b + (addr & 0xfff));
		pr_cont(" readback %08x\n", readl(b + (addr & 0xfff)));
		iounmap(b);
		n++;
	}
	kfree(buf);
	return 0;
}

static void __exit tb_poke_exit(void) { }
module_init(tb_poke_init);
module_exit(tb_poke_exit);
MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("TB371FC display register poke (experiments)");
