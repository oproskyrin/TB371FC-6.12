#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/audit-r82-transport-r2.sh"
template_sha=de42e1fc113f95b18480018a7530466679cd42a7a017f86105f477329000fa84
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT

printf '%s  %s\n' "$template_sha" "$template" | sha256sum -c -
python3 - "$template" "$generated" <<'PYEOF'
import sys

src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r82') == 1, 'unexpected r82 audit template'
text = text.replace('r82', 'r83')
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
