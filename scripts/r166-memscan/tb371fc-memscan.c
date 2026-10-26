// SPDX-License-Identifier: GPL-2.0
/*
 * TB371FC diagnostic: READ one word from every page of the "System RAM" resources inside
 * [lo, hi), upward (dir=0) or downward (dir=1), logging progress every step_kb KiB, to locate RAM
 * that hangs the CPU on access (firmware-owned memory reported as System RAM). Read-only.
 */
#include <linux/delay.h>
#include <linux/io.h>
#include <linux/ioport.h>
#include <linux/mm.h>
#include <linux/module.h>

static unsigned long long lo, hi = ~0ULL;
static unsigned long step_kb = 16384, dir;
module_param(lo, ullong, 0444);
module_param(hi, ullong, 0444);
module_param(step_kb, ulong, 0444);
module_param(dir, ulong, 0444);

#define MAXR 64
static struct { phys_addr_t s, e; } r[MAXR];
static int nr;
static unsigned long pages, sum;

static int collect(struct resource *res, void *arg)
{
	phys_addr_t s = max_t(phys_addr_t, PAGE_ALIGN(res->start), lo);
	phys_addr_t e = min_t(phys_addr_t, res->end + 1, hi);

	if (s < e && nr < MAXR) { r[nr].s = s; r[nr].e = e & PAGE_MASK; nr++; }
	return 0;
}

static void probe(phys_addr_t pa)
{
	if (!pfn_valid(PHYS_PFN(pa)))
		return;
	if ((pa & ((step_kb << 10) - 1)) == 0) {
		pr_info("memscan: at %pa\n", &pa);
		msleep(10);
	}
	sum += READ_ONCE(*(volatile unsigned long *)phys_to_virt(pa));
	pages++;
}

static int __init memscan_init(void)
{
	int i;
	phys_addr_t pa;

	walk_iomem_res_desc(IORES_DESC_NONE, IORESOURCE_SYSTEM_RAM | IORESOURCE_BUSY, 0, -1, NULL, collect);
	pr_info("memscan: %d ranges in [%llx,%llx) dir=%lu step=%luK\n", nr, lo, hi, dir, step_kb);
	if (!dir) {
		for (i = 0; i < nr; i++)
			for (pa = r[i].s; pa < r[i].e; pa += PAGE_SIZE)
				probe(pa);
	} else {
		for (i = nr - 1; i >= 0; i--)
			for (pa = r[i].e - PAGE_SIZE; pa >= r[i].s && pa < r[i].e; pa -= PAGE_SIZE)
				probe(pa);
	}
	pr_info("memscan: done, %lu pages read, sum %lx\n", pages, sum);
	return -EAGAIN;
}
module_init(memscan_init);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC read-only RAM access scan");
