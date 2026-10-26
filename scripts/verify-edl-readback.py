#!/usr/bin/env python3
"""Verify sizes and create a SHA-256 manifest for TB371FC EDL readback files."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("inventory", type=Path)
    parser.add_argument("readback_dir", type=Path)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()

    inventory = json.loads(args.inventory.read_text(encoding="utf-8-sig"))
    if isinstance(inventory, dict):
        inventory = [inventory]
    if not isinstance(inventory, list):
        raise SystemExit("inventory must be a JSON array or object")
    readback_dir = args.readback_dir.expanduser().resolve()
    errors: list[str] = []
    verified: list[dict[str, object]] = []

    for entry in inventory:
        path = readback_dir / entry["filename"]
        expected = int(entry["expected_bytes"])
        if not path.is_file():
            errors.append(f"missing: {entry['filename']}")
            continue
        actual = path.stat().st_size
        if actual != expected:
            errors.append(
                f"size mismatch: {entry['filename']}: expected {expected}, got {actual}"
            )
            continue
        result = dict(entry)
        result["sha256"] = sha256(path)
        verified.append(result)
        print(f"OK {entry['label']}: {actual} bytes {result['sha256']}")

    if errors:
        print("READBACK VERIFICATION FAILED")
        for error in errors:
            print(f"  - {error}")
        return 1

    manifest = {
        "format": "tb371fc-edl-readback-v1",
        "files": verified,
    }
    rendered = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    if args.manifest:
        args.manifest.write_text(rendered, encoding="utf-8")
        print(f"Wrote manifest: {args.manifest.resolve()}")
    else:
        print(rendered, end="")
    print(f"READBACK VERIFIED: {len(verified)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
