#!/bin/bash
# Host-only unit/model tests. No insmod, device I/O, flashing or credentials.
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
repo=$(cd -- "$here/../.." && pwd)
cc=${CC:-clang-18}
work=$(mktemp -d)
echo "Host-only test outputs: $work"
"$cc" -Wall -Wextra -Werror "$repo/scripts/r235-watchdog-only/test-policy.c" -o "$work/r235-policy"
"$work/r235-policy"
for test in policy transaction; do
    "$cc" -Wall -Wextra -Werror "$repo/scripts/r236-current-limit/test-$test.c" -o "$work/r236-$test"
    "$work/r236-$test"
done
"$cc" -Wall -Wextra -Werror -I"$here/reference/r240" -DOLD_BEHAVIOR -DRX_IMPL='"old-rx.inc"' \
    "$repo/scripts/r240-rx-cleanup/test-rx.c" -o "$work/r240-old"
"$work/r240-old"
"$cc" -Wall -Wextra -Werror -I"$here/reference/r240" -DRX_IMPL='"new-rx.inc"' \
    "$repo/scripts/r240-rx-cleanup/test-rx.c" -o "$work/r240-new"
"$work/r240-new"
cd "$here"
sha256sum -c SOURCE_SHA256SUMS
echo 'OFFLINE_MODELS_PASS (not hardware certification)'
