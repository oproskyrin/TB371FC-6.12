#!/usr/bin/env bash
# R160 live test only: q6asm-dai that registers MultiMedia1 (dai 0) when DT has no dai@N
# children. The proper fix is dai@N nodes in DT (R160b); this module just avoids a blind reboot.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r160-sound
m=/root/tb371fc/r160-q6asm-dai; rm -rf "$m"; mkdir -p "$m"
cp "$src/sound/soc/qcom/qdsp6/q6asm-dai.c" "$m/"
python3 - "$m/q6asm-dai.c" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old=r'''	if (!pdata->num_dais) {
		dev_err(dev, "No dais found in DT\n");
		return -EINVAL;
	}
'''
new=r'''	if (!pdata->num_dais) {
		dev_warn(dev, "No dais in DT, test fallback: MultiMedia1 only\n");
		pdata->dais = devm_kcalloc(dev, 1, sizeof(*dai_drv), GFP_KERNEL);
		if (!pdata->dais)
			return -ENOMEM;
		pdata->num_dais = 1;
		pdata->dais[0] = q6asm_fe_dais_template[0];
		return 0;
	}
'''
assert s.count(old)==1; open(p,'w').write(s.replace(old,new))
PY
printf 'obj-m += q6asm-dai.o\nccflags-y += -I$(srctree)/sound/soc/qcom/qdsp6 -I$(srctree)/sound/soc/qcom\n' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/q6asm-dai-build.log" 2>&1 || { grep -E "error" "$pkg/q6asm-dai-build.log" | head; exit 1; }
modinfo -F vermagic "$m/q6asm-dai.ko"; modinfo -F depends "$m/q6asm-dai.ko"
cp "$m/q6asm-dai.ko" "$pkg/q6asm-dai-fallback.ko"; sha256sum "$pkg/q6asm-dai-fallback.ko"
