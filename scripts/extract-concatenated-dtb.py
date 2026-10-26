#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Extract sequential FDT blobs from an Android boot image DTB section."""

from __future__ import annotations

import argparse
from pathlib import Path
import struct


FDT_MAGIC = 0xD00DFEED


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path, help="concatenated DTB section")
    parser.add_argument("output", type=Path, help="empty output directory")
    args = parser.parse_args()

    data = args.image.read_bytes()
    if args.output.exists() and any(args.output.iterdir()):
        raise FileExistsError(f"refusing to use non-empty {args.output}")
    args.output.mkdir(parents=True, exist_ok=True)

    offset = 0
    index = 0
    while offset < len(data):
        if len(data) - offset < 8:
            raise ValueError(f"trailing {len(data) - offset} bytes at {offset}")
        magic, size = struct.unpack_from(">II", data, offset)
        if magic != FDT_MAGIC:
            raise ValueError(f"invalid FDT magic 0x{magic:08x} at {offset}")
        if size < 40 or offset + size > len(data):
            raise ValueError(f"invalid FDT size {size} at {offset}")
        output = args.output / f"entry-{index:02d}.dtb"
        output.write_bytes(data[offset:offset + size])
        print(f"{output.name}: offset={offset} size={size}")
        offset += size
        index += 1

    print(f"entries={index} total_size={len(data)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
