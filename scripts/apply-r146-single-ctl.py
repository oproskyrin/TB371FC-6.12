#!/usr/bin/env python3
"""R146: backport the 7.1 single-CTL model for active-CTL DPU (>= 5.x).

On DPU 5+ one CTL drives both interfaces of a bonded DSI pipe and the
master INTF is selected through CTL_INTF_MASTER (as downstream SDE does).
6.12 instead reserves two split-display CTLs and only ever flushes the
master one, so the slave half of TB371FC's dual-DSI/DSC panel is garbage.

Edits are exact-match; the script refuses to run on an unexpected tree.
"""
import sys
from pathlib import Path

root = Path(sys.argv[1]) / "drivers/gpu/drm/msm/disp/dpu1"
MARK = "R146 single CTL"


def edit(name, pairs):
    p = root / name
    s = p.read_text()
    for old, new in pairs:
        if s.count(old) != 1:
            sys.exit(f"{name}: context not found exactly once:\n{old}")
        s = s.replace(old, new)
    p.write_text(s)
    print(f"edited {name}")


if MARK in (root / "dpu_rm.c").read_text():
    sys.exit("already applied")

edit("dpu_rm.h", [(
"""	struct dpu_hw_blk *cdm_blk;
};""",
"""	struct dpu_hw_blk *cdm_blk;
	/* R146 single CTL: DPU uses pre-ACTIVE CTL blocks (core < 5) */
	bool has_legacy_ctls;
};""")])

edit("dpu_rm.c", [
("""	/* Clear, setup lists */
	memset(rm, 0, sizeof(*rm));
""",
"""	/* Clear, setup lists */
	memset(rm, 0, sizeof(*rm));

	/* R146 single CTL (7.1): ACTIVE CTLs drive all INTFs of one pipe */
	rm->has_legacy_ctls = (cat->mdss_ver->core_major_ver < 5);
"""),
("""	/* each hw_intf needs its own hw_ctrl to program its control path */
	num_ctls = top->num_intf;

	needs_split_display = _dpu_rm_needs_split_display(top);
""",
"""	if (rm->has_legacy_ctls) {
		/* each hw_intf needs its own hw_ctrl to program its control path */
		num_ctls = top->num_intf;

		needs_split_display = _dpu_rm_needs_split_display(top);
	} else {
		/* use single CTL */
		num_ctls = 1;
		needs_split_display = false;
	}
"""),
])

edit("dpu_encoder.c", [(
"""		phys->hw_ctl = i < num_ctl ? to_dpu_hw_ctl(hw_ctl[i]) : NULL;""",
"""		/* Use first (and only) CTL if active CTLs are supported */
		if (num_ctl == 1)
			phys->hw_ctl = to_dpu_hw_ctl(hw_ctl[0]);
		else
			phys->hw_ctl = i < num_ctl ? to_dpu_hw_ctl(hw_ctl[i]) : NULL;""")])

edit("dpu_hw_ctl.h", [
(""" * @dsc:                   DSC BIT masks used
 */
struct dpu_hw_intf_cfg {
	enum dpu_intf intf;
""",
""" * @dsc:                   DSC BIT masks used
 * @intf_master:           Master interface id in the dual pipe topology
 */
struct dpu_hw_intf_cfg {
	enum dpu_intf intf;
	enum dpu_intf intf_master;
""")])

edit("dpu_hw_ctl.c", [
("""	DPU_REG_WRITE(c, CTL_DSC_ACTIVE, dsc_active);

	if (cfg->merge_3d)
		DPU_REG_WRITE(c, CTL_MERGE_3D_ACTIVE,
			      BIT(cfg->merge_3d - MERGE_3D_0));
""",
"""	DPU_REG_WRITE(c, CTL_DSC_ACTIVE, dsc_active);

	if (cfg->merge_3d)
		DPU_REG_WRITE(c, CTL_MERGE_3D_ACTIVE,
			      BIT(cfg->merge_3d - MERGE_3D_0));

	if (cfg->intf_master)
		DPU_REG_WRITE(c, CTL_INTF_MASTER, BIT(cfg->intf_master - INTF_0));
"""),
("""	u32 intf_active = 0;
	u32 wb_active = 0;
	u32 merge3d_active = 0;""",
"""	u32 intf_active = 0;
	u32 intf_master = 0;
	u32 wb_active = 0;
	u32 merge3d_active = 0;"""),
("""		intf_active = DPU_REG_READ(c, CTL_INTF_ACTIVE);
		intf_active &= ~BIT(cfg->intf - INTF_0);
		DPU_REG_WRITE(c, CTL_INTF_ACTIVE, intf_active);
""",
"""		intf_active = DPU_REG_READ(c, CTL_INTF_ACTIVE);
		intf_active &= ~BIT(cfg->intf - INTF_0);
		DPU_REG_WRITE(c, CTL_INTF_ACTIVE, intf_active);

		intf_master = DPU_REG_READ(c, CTL_INTF_MASTER);

		/* Unset this intf as master, if it is the current master */
		if (intf_master == BIT(cfg->intf - INTF_0))
			DPU_REG_WRITE(c, CTL_INTF_MASTER, 0);
"""),
])

edit("dpu_encoder_phys_vid.c", [(
"""	intf_cfg.intf = phys_enc->hw_intf->idx;
	intf_cfg.intf_mode_sel = DPU_CTL_MODE_SEL_VID;""",
"""	intf_cfg.intf = phys_enc->hw_intf->idx;
	if (phys_enc->split_role == ENC_ROLE_MASTER)
		intf_cfg.intf_master = phys_enc->hw_intf->idx;
	intf_cfg.intf_mode_sel = DPU_CTL_MODE_SEL_VID;""")])
print("R146 applied")
