#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
bash -n "$project/scripts/build-r135-rpmh-clock.sh"
bash -n "$project/scripts/package-r135-clock-gated.sh"
for file in test-r121-r135-clock-gated.sh r135-display-stage.sh r135-clock-only.sh; do
    sh -n "$project/scripts/$file"
done
pkg=/mnt/d/TB371FC-builds/r135-clock-gated
(cd "$pkg"; sha256sum -c SHA256SUMS)
stage=$(cat "$pkg/staging-path.txt")
test "$(grep -c 'display-stage.sh rpmh' "$stage/r134-config/late-display-deps.sh")" = 1
! grep -Eq 'insmod|display-stage.sh (dispcc|icc|mdss)' "$stage/r134-config/late-display-deps.sh"
cmp "$project/scripts/r135-display-stage.sh" "$stage/r134-config/r135-display-stage.sh"
printf 'PASS: syntax, package hashes, RPMh-only boot gate\n'
