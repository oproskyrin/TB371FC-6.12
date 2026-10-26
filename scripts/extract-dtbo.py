#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Extract FDT blobs from an Android DT table image."""

from __future__ import annotations

import argparse
from pathlib import Path
import struct


DT_TABLE_MAGIC = 0xD7B7AB1E
FDT_MAGIC = 0xD00DFEED


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path, help="Android DT table image")
    parser.add_argument("output", type=Path, help="empty output directory")
    args = parser.parse_args()

    data = args.image.read_bytes()
    if len(data) < 32:
        raise ValueError("DT table image is shorter than its header")

    (magic, total_size, header_size, entry_size, entry_count,
     entries_offset, page_size, version) = struct.unpack_from(">8I", data)
    if magic != DT_TABLE_MAGIC:
        raise ValueError(f"invalid DT table magic: 0x{magic:08x}")
    if header_size < 32 or entry_size < 32:
        raise ValueError("unsupported DT table header or entry size")
    if total_size > len(data):
        raise ValueError("declared DT table size exceeds the input file")
    if entries_offset + entry_count * entry_size > total_size:
        raise ValueError("DT table entries exceed the declared image size")
    if args.output.exists() and any(args.output.iterdir()):
        raise FileExistsError(f"refusing to use non-empty {args.output}")
    args.output.mkdir(parents=True, exist_ok=True)

    print(
        f"entries={entry_count} total_size={total_size} "
        f"page_size={page_size} version={version}"
    )
    for index in range(entry_count):
        entry_at = entries_offset + index * entry_size
        size, offset, entry_id, revision, *custom = struct.unpack_from(
            ">8I", data, entry_at
        )
        if offset + size > total_size:
            raise ValueError(f"entry {index} exceeds the declared image size")
        blob = data[offset:offset + size]
        if len(blob) < 8 or struct.unpack_from(">I", blob)[0] != FDT_MAGIC:
            raise ValueError(f"entry {index} is not an FDT blob")
        fdt_size = struct.unpack_from(">I", blob, 4)[0]
        if fdt_size != size:
            raise ValueError(
                f"entry {index} size mismatch: table={size}, FDT={fdt_size}"
            )
        output = args.output / f"entry-{index:02d}.dtbo"
        output.write_bytes(blob)
        print(
            f"{output.name}: offset={offset} size={size} "
            f"id=0x{entry_id:08x} rev=0x{revision:08x} "
            f"custom={','.join(f'0x{x:08x}' for x in custom)}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
