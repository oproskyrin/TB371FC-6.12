#!/bin/bash
# PRIVATE build; never install/load on running R226.
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
base=/root/tb371fc/build-6.12.114-r200
matched=/root/tb371fc/r233-sink-test.KMtL4j
work=$(mktemp -d /root/tb371fc/r239-pd-receiver.XXXXXX)
for file in tcpm.c qcom_pmic_typec.c qcom_pmic_typec_port.c qcom_pmic_typec_pdphy.c qcom_pmic_typec_pdphy_stub.c qcom_pmic_typec.h qcom_pmic_typec_port.h qcom_pmic_typec_pdphy.h callback.inc policy.h Makefile; do
    cp "$matched/$file" "$work/"
done
python3 "$p/scripts/r239-pd-receiver/prepare.py" "$work/qcom_pmic_typec_pdphy.c"
make -C "$base" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
dest=/mnt/d/TB371FC-builds/r239-pd-receiver
mkdir -p "$dest"
cp "$work/"*.ko "$dest/"
sha256sum "$dest/"*.ko
echo "PRIVATE BUILD $work"
