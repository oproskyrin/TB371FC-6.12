#!/usr/bin/env python3
"""Make tb371fc-sndcard.c from upstream 6.12 sm8250.c: adds PRI_TDM_RX_0 (4 x 32-bit slots,
6.144 MHz bit clock, byte offsets 0/4/8/12, 4ch/48 kHz; BE S16_LE for now, Lenovo uses S32_LE)."""
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()

assert s.count('#include <sound/pcm.h>\n') == 1
s = s.replace('#include <sound/pcm.h>\n', '#include <sound/pcm.h>\n#include <sound/pcm_params.h>\n')

def rep(old, new):
    global s
    assert s.count(old) == 1, old
    s = s.replace(old, new)

rep('#define DRIVER_NAME\t\t"sm8250"\n#define MI2S_BCLK_RATE\t\t1536000\n',
    '#define DRIVER_NAME\t\t"tb371fc"\n#define MI2S_BCLK_RATE\t\t1536000\n'
    '#define TDM_SLOTS\t\t4\n#define TDM_SLOT_WIDTH\t\t32\n'
    '#define TDM_BCLK_RATE\t\t(48000 * TDM_SLOTS * TDM_SLOT_WIDTH)\n'
    'static const unsigned int tdm_slot_offset[TDM_SLOTS] = {0, 4, 8, 12};\n')

rep('''	rate->min = rate->max = 48000;
	channels->min = channels->max = 2;
''', '''	struct snd_soc_dai *cpu_dai = snd_soc_rtd_to_cpu(rtd, 0);

	rate->min = rate->max = 48000;
	channels->min = channels->max = 2;
	if (cpu_dai->id == PRIMARY_TDM_RX_0) {
		struct snd_mask *fmt = hw_param_mask(params, SNDRV_PCM_HW_PARAM_FORMAT);

		channels->min = channels->max = TDM_SLOTS;
		snd_mask_none(fmt);
		/* 6.12 q6routing only knows S16/S24 for ADM; 16-bit data in 32-bit slots */
		snd_mask_set_format(fmt, SNDRV_PCM_FORMAT_S16_LE);
	}
''')

rep('''	default:
		break;
	}

	return qcom_snd_sdw_startup(substream);''', '''	case PRIMARY_TDM_RX_0: {
		int rc;

		dev_info(rtd->dev, "R160 TDM startup: cpu=%s codec=%s, set_sysclk %u\\n",
			 cpu_dai->name, codec_dai->name, TDM_BCLK_RATE);
		rc = snd_soc_dai_set_sysclk(cpu_dai,
			Q6AFE_LPASS_CLK_ID_PRI_TDM_IBIT,
			TDM_BCLK_RATE, SNDRV_PCM_STREAM_PLAYBACK);
		dev_info(rtd->dev, "R160 TDM startup: set_sysclk rc=%d\\n", rc);
		/*
		 * Not SoundWire: qcom_snd_sdw_startup() calls snd_soc_dai_set_stream()
		 * on every codec DAI, which dereferences codec ops without a NULL check
		 * (6.12) - oopses on ops-less codecs such as spdif-dit.
		 */
		return rc;
	}
	default:
		break;
	}

	return qcom_snd_sdw_startup(substream);''')

rep('''	struct sm8250_snd_data *pdata = snd_soc_card_get_drvdata(rtd->card);

	return qcom_snd_sdw_hw_params(''', '''	struct sm8250_snd_data *pdata = snd_soc_card_get_drvdata(rtd->card);
	int ret;

	if (cpu_dai->id == PRIMARY_TDM_RX_0) {
		dev_info(rtd->dev, "R160 TDM hw_params: %u ch, %u Hz, width %u\\n",
			 params_channels(params), params_rate(params), params_width(params));
		ret = snd_soc_dai_set_tdm_slot(cpu_dai, 0, BIT(TDM_SLOTS) - 1,
					       TDM_SLOTS, TDM_SLOT_WIDTH);
		if (ret < 0)
			return ret;
		ret = snd_soc_dai_set_channel_map(cpu_dai, 0, NULL,
						  params_channels(params), tdm_slot_offset);
		if (ret < 0)
			return ret;
	}

	return qcom_snd_sdw_hw_params(''')

rep('''	{.compatible = "qcom,sm8250-sndcard"},
	{.compatible = "qcom,qrb4210-rb2-sndcard"},
	{.compatible = "qcom,qrb5165-rb5-sndcard"},
''', '''	{.compatible = "lenovo,tb371fc-sndcard"},
''')
rep('.name = "snd-sm8250",', '.name = "snd-tb371fc",')
rep('MODULE_DESCRIPTION("SM8250 ASoC Machine Driver");', 'MODULE_DESCRIPTION("Lenovo TB371FC (SM8250) ASoC machine driver, PRI_TDM");')
open(dst, 'w').write(s)
