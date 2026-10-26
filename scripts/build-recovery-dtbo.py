#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Pack one compiled overlay into an Android DT table image."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import struct
import tempfile


DT_TABLE_MAGIC = 0xD7B7AB1E
FDT_MAGIC = 0xD00DFEED
HEADER_SIZE = 32
ENTRY_SIZE = 32
PAGE_SIZE = 4096


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("overlay", type=Path, help="compiled DTBO")
    parser.add_argument("output", type=Path, help="new Android DT table image")
    args = parser.parse_args()

    overlay = args.overlay.read_bytes()
    if len(overlay) < 40:
        raise ValueError("overlay is shorter than an FDT header")
    magic, total_size = struct.unpack_from(">II", overlay)
    if magic != FDT_MAGIC:
        raise ValueError(f"invalid FDT magic: 0x{magic:08x}")
    if total_size != len(overlay):
        raise ValueError(
            f"FDT total size mismatch: header={total_size}, file={len(overlay)}"
        )
    if args.output.exists():
        raise FileExistsError(f"refusing to overwrite {args.output}")

    entry_offset = HEADER_SIZE
    dt_offset = HEADER_SIZE + ENTRY_SIZE
    image_size = dt_offset + len(overlay)
    header = struct.pack(
        ">8I",
        DT_TABLE_MAGIC,
        image_size,
        HEADER_SIZE,
        ENTRY_SIZE,
        1,
        entry_offset,
        PAGE_SIZE,
        0,
    )
    # Match Lenovo's table entries: selection metadata lives in the overlay
    # root and all legacy table ID/revision/custom fields are zero.
    entry = struct.pack(">8I", len(overlay), dt_offset, 0, 0, 0, 0, 0, 0)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=args.output.parent, prefix=f".{args.output.name}.", delete=False
    ) as temporary:
        temporary.write(header)
        temporary.write(entry)
        temporary.write(overlay)
        temporary_name = temporary.name
    os.replace(temporary_name, args.output)
    print(f"Recovery DTBO image: {args.output.resolve()} ({image_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
