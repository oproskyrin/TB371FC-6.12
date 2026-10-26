#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Replace one FDT in a concatenated Android boot-image DTB section."""

from __future__ import annotations

import argparse
from pathlib import Path
import struct


FDT_MAGIC = 0xD00DFEED


def split_fdt_blobs(data: bytes) -> list[bytes]:
    blobs: list[bytes] = []
    offset = 0
    while offset < len(data):
        if len(data) - offset < 8:
            raise ValueError(f"trailing {len(data) - offset} bytes at {offset}")
        magic, size = struct.unpack_from(">II", data, offset)
        if magic != FDT_MAGIC:
            raise ValueError(f"invalid FDT magic 0x{magic:08x} at {offset}")
        if size < 40 or offset + size > len(data):
            raise ValueError(f"invalid FDT size {size} at {offset}")
        blobs.append(data[offset : offset + size])
        offset += size
    return blobs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("index", type=int)
    parser.add_argument("replacement", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    if args.output.exists():
        raise FileExistsError(f"refusing to overwrite {args.output}")

    blobs = split_fdt_blobs(args.input.read_bytes())
    if not 0 <= args.index < len(blobs):
        raise IndexError(f"entry index {args.index} is outside 0..{len(blobs) - 1}")

    replacement = args.replacement.read_bytes()
    replacement_blobs = split_fdt_blobs(replacement)
    if len(replacement_blobs) != 1:
        raise ValueError("replacement must contain exactly one FDT blob")

    old_size = len(blobs[args.index])
    blobs[args.index] = replacement
    result = b"".join(blobs)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(result)
    print(
        f"replaced entry {args.index}: {old_size} -> {len(replacement)} bytes; "
        f"total {len(result)} bytes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
