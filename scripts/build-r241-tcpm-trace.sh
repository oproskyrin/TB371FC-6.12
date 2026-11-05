#!/bin/bash
# Pure diagnostics over R240; no tablet modifications.
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
src=/root/tb371fc/r240-rx-cleanup.zIoztT
out=/root/tb371fc/build-6.12.114-r200
work=$(mktemp -d /root/tb371fc/r241-tcpm-trace.XXXXXX)
for file in tcpm.c qcom_pmic_typec.c qcom_pmic_typec_port.c qcom_pmic_typec_pdphy.c qcom_pmic_typec_pdphy_stub.c qcom_pmic_typec.h qcom_pmic_typec_port.h qcom_pmic_typec_pdphy.h callback.inc policy.h Makefile; do
    cp "$src/$file" "$work/"
done
python3 "$p/scripts/r241-tcpm-trace/prepare.py" "$work/tcpm.c"
make -C "$out" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
dest=/mnt/d/TB371FC-builds/r241-tcpm-trace
mkdir -p "$dest"
cp "$work/"*.ko "$dest/"
python3 "$p/scripts/r241-tcpm-trace/prepare-probe.py" "$dest/probe-r238.sh"
cp "$p/scripts/r241-tcpm-trace/collect-tcpm.sh" "$dest/"
sh -n "$dest/probe-r238.sh"
sh -n "$dest/collect-tcpm.sh"
sha256sum "$dest/"*.ko
echo "PRIVATE BUILD $work"
