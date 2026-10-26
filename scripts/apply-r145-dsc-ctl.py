#!/usr/bin/env python3
"""Apply R145 per-CTL DSC ownership to a 6.12 tree (exact-match edits only)."""
import sys
from pathlib import Path

p = Path(sys.argv[1]) / "drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
s = p.read_text()
if "each CTL owns only its own DSC" in s:
    sys.exit("already applied")

old1 = """	for (i = 0; i < MAX_CHANNELS_PER_ENC; i++)
		dpu_encoder_dsc_pipe_cfg(ctl, hw_dsc[i], hw_pp[i],
					 dsc, dsc_common_mode, initial_lines);
}"""
new1 = """	for (i = 0; i < MAX_CHANNELS_PER_ENC; i++) {
		struct dpu_hw_ctl *dsc_ctl = ctl;

		/* bonded DSI without DSC merge: each CTL flushes its own DSC */
		if (dpu_enc->num_phys_encs > 1 &&
		    !dpu_encoder_use_dsc_merge(enc_master->parent) &&
		    i < dpu_enc->num_phys_encs && dpu_enc->phys_encs[i] &&
		    dpu_enc->phys_encs[i]->hw_ctl)
			dsc_ctl = dpu_enc->phys_encs[i]->hw_ctl;

		dpu_encoder_dsc_pipe_cfg(dsc_ctl, hw_dsc[i], hw_pp[i],
					 dsc, dsc_common_mode, initial_lines);
	}
}"""
old2 = """	struct dpu_encoder_virt *dpu_enc = to_dpu_encoder_virt(encoder);

	return dpu_enc->dsc_mask;
}"""
new2 = """	struct dpu_encoder_virt *dpu_enc = to_dpu_encoder_virt(encoder);
	int i;

	/* bonded DSI without DSC merge: each CTL owns only its own DSC */
	if (dpu_enc->num_phys_encs > 1 && !dpu_encoder_use_dsc_merge(encoder)) {
		for (i = 0; i < dpu_enc->num_phys_encs && i < MAX_CHANNELS_PER_ENC; i++)
			if (dpu_enc->phys_encs[i] == phys_enc)
				return dpu_enc->hw_dsc[i] ?
					BIT(dpu_enc->hw_dsc[i]->idx - DSC_0) : 0;
	}

	return dpu_enc->dsc_mask;
}"""
for old, new in ((old1, new1), (old2, new2)):
    if s.count(old) != 1:
        sys.exit(f"context not unique/found:\n{old}")
    s = s.replace(old, new)
p.write_text(s)
print("applied")
