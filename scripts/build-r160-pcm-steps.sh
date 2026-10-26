#!/usr/bin/env bash
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"; pkg=/mnt/d/TB371FC-builds/r160-sound
aarch64-linux-gnu-gcc -O2 -static -Wall -o "$pkg/pcm-steps" "$p/scripts/r160-sound/pcm-steps.c"
file "$pkg/pcm-steps"; sha256sum "$pkg/pcm-steps"
