#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
source=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r108-transport-r2
stage=$(mktemp -d /tmp/tb371fc-r108-control-XXXXXX)
cd "$source"
sha256sum -c SHA256SUMS
gzip -dc tb371fc-v56.6-controlled-linux-6.12-r108-transport-r2.cpio.gz | (cd "$stage"; cpio -idmu 2>/dev/null)
cmp "$stage/opt/tb371fc-linux-6.12-r38/Image" /mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool/Image
sed -i 's@payload=/run/tb371fc-rescue/linux-6.12-r38@payload=/run/r108-control/opt/tb371fc-linux-6.12-r38@; s/panic=-1/panic=0/' "$stage/bin/load-linux-6.12-r38"
sh -n "$stage/bin/load-linux-6.12-r38"
mkdir -p "$project/artifacts/r108-control-20260907"
tar -C "$stage" -czf "$project/artifacts/r108-control-20260907/payload.tar.gz" opt/tb371fc-linux-6.12-r38 bin/load-linux-6.12-r38
sha256sum "$stage/opt/tb371fc-linux-6.12-r38/"* "$project/artifacts/r108-control-20260907/payload.tar.gz"
