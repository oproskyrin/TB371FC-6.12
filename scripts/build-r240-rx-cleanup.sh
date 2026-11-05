#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
src=/root/tb371fc/r239-pd-receiver.XO7GPm
out=/root/tb371fc/build-6.12.114-r200
work=$(mktemp -d /root/tb371fc/r240-rx-cleanup.XXXXXX)
for file in tcpm.c qcom_pmic_typec.c qcom_pmic_typec_port.c qcom_pmic_typec_pdphy.c qcom_pmic_typec_pdphy_stub.c qcom_pmic_typec.h qcom_pmic_typec_port.h qcom_pmic_typec_pdphy.h callback.inc policy.h Makefile; do
    cp "$src/$file" "$work/"
done
python3 "$p/scripts/r240-rx-cleanup/prepare.py" "$work/qcom_pmic_typec_pdphy.c"
clang-18 -Wall -Wextra -Werror -I"$work" -DOLD_BEHAVIOR -DRX_IMPL='"old-rx.inc"' "$p/scripts/r240-rx-cleanup/test-rx.c" -o "$work/test-old"
"$work/test-old"
clang-18 -Wall -Wextra -Werror -I"$work" -DRX_IMPL='"new-rx.inc"' "$p/scripts/r240-rx-cleanup/test-rx.c" -o "$work/test-new"
"$work/test-new"
make -C "$out" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
dest=/mnt/d/TB371FC-builds/r240-rx-cleanup
mkdir -p "$dest"
cp "$work/"*.ko "$dest/"
sha256sum "$dest/"*.ko
echo "PRIVATE BUILD $work"
