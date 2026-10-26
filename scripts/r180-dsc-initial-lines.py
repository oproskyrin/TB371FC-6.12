"""R180: DSC initial_lines from the downstream SDE (Hardent core) latency model (see patch 0004)."""
import sys
p = sys.argv[1]; s = open(p).read()
a = s.index('dpu_encoder_dsc_initial_line_calc(struct drm_dsc_config *dsc,\n\t\t\t\t  u32 enc_ip_width)\n{')
b = s.index('}\n', a) + 2
new = r'''dpu_encoder_dsc_initial_line_calc(struct drm_dsc_config *dsc,
				  u32 enc_ip_width)
{
	/*
	 * TB371FC: downstream SDE (Hardent core) latency model, which also counts the output
	 * buffer and the chunk latency. For the NT36532 panel (8 bpc, 8 bpp, initial_xmit_delay
	 * 512, slice/chunk 736) it gives 3 initial lines like the working bootloader/4.19
	 * configuration; the upstream model gives 2.
	 */
	const int max_muxword_size = 48, output_rate = 64, rtl_max_bpc = 10, pipeline_latency = 28;
	int bpp = dsc->bits_per_pixel >> 4;	/* U6.4 */
	int max_se_size = 4 * (rtl_max_bpc + 1);
	int max_ssm_delay = max_se_size + max_muxword_size - 1;
	int mux_word_size = dsc->bits_per_component >= 12 ? 64 : 48;
	int input_ssm_out_latency = pipeline_latency + 3 * (max_ssm_delay + 2);
	int obuf_latency, base_hs_latency, multi_hs_extra_latency;

	if (!bpp)
		bpp = 8;
	obuf_latency = DIV_ROUND_UP(9 * output_rate + mux_word_size, bpp) + 1;
	base_hs_latency = dsc->initial_xmit_delay + input_ssm_out_latency + obuf_latency;
	multi_hs_extra_latency = DIV_ROUND_UP(8 * dsc->slice_chunk_size, bpp);
	return DIV_ROUND_UP(base_hs_latency + multi_hs_extra_latency, dsc->slice_width);
}
'''
assert 'Hardent' not in s
s = s[:a] + new + s[b:]
open(p, 'w').write(s)
print('initial_lines patch applied')
