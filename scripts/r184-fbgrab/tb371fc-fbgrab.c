// SPDX-License-Identifier: GPL-2.0-only
/*
 * TB371FC: read-only screenshot of the simpledrm framebuffer (0x9c000000, 2944x1840 XRGB8888,
 * stride 11776) through /proc/tb371fc-fb. Used for README screenshots: KWin draws into this buffer.
 */
#include <linux/io.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>

#define FB_PHYS 0x9c000000UL
#define FB_SIZE (11776UL * 1840)

static void *fb;

static ssize_t fb_read(struct file *f, char __user *buf, size_t len, loff_t *pos)
{
	if (*pos >= FB_SIZE)
		return 0;
	len = min_t(size_t, len, FB_SIZE - *pos);
	if (copy_to_user(buf, fb + *pos, len))
		return -EFAULT;
	*pos += len;
	return len;
}

static const struct proc_ops fb_ops = { .proc_read = fb_read, .proc_lseek = default_llseek };

static int __init fbgrab_init(void)
{
	fb = memremap(FB_PHYS, FB_SIZE, MEMREMAP_WC);
	if (!fb)
		return -ENOMEM;
	if (!proc_create("tb371fc-fb", 0400, NULL, &fb_ops)) {
		memunmap(fb);
		return -ENOMEM;
	}
	return 0;
}

static void __exit fbgrab_exit(void)
{
	remove_proc_entry("tb371fc-fb", NULL);
	memunmap(fb);
}

module_init(fbgrab_init);
module_exit(fbgrab_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TB371FC simpledrm framebuffer screenshot");
