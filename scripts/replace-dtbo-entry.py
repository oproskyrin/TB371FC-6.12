#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Replace one FDT in an Android DT table while preserving entry metadata."""

from __future__ import annotations

import argparse
from pathlib import Path
import struct


DT_TABLE_MAGIC = 0xD7B7AB1E
FDT_MAGIC = 0xD00DFEED


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("index", type=int)
    parser.add_argument("replacement", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    source = args.input.read_bytes()
    replacement = args.replacement.read_bytes()
    if args.output.exists():
        raise FileExistsError(f"refusing to overwrite {args.output}")
    if len(source) < 32:
        raise ValueError("input is shorter than the DT table header")
    header = list(struct.unpack_from(">8I", source))
    magic, total_size, header_size, entry_size, entry_count, entries_offset, _, _ = header
    if magic != DT_TABLE_MAGIC:
        raise ValueError(f"invalid DT table magic 0x{magic:08x}")
    if total_size != len(source):
        raise ValueError(f"input has trailing or missing bytes: {len(source)} != {total_size}")
    if header_size < 32 or entry_size < 32:
        raise ValueError("unsupported header or entry size")
    if not 0 <= args.index < entry_count:
        raise IndexError(f"entry index {args.index} is outside 0..{entry_count - 1}")
    if len(replacement) < 8 or struct.unpack_from(">I", replacement)[0] != FDT_MAGIC:
        raise ValueError("replacement is not an FDT blob")
    if struct.unpack_from(">I", replacement, 4)[0] != len(replacement):
        raise ValueError("replacement FDT totalsize does not match its file size")

    entry_table_end = entries_offset + entry_count * entry_size
    if entry_table_end > total_size:
        raise ValueError("entry table exceeds declared image size")

    records: list[bytearray] = []
    blobs: list[bytes] = []
    first_blob_offset: int | None = None
    for entry_index in range(entry_count):
        at = entries_offset + entry_index * entry_size
        record = bytearray(source[at:at + entry_size])
        size, offset = struct.unpack_from(">2I", record)
        if offset + size > total_size:
            raise ValueError(f"entry {entry_index} exceeds image")
        blob = source[offset:offset + size]
        if len(blob) < 8 or struct.unpack_from(">I", blob)[0] != FDT_MAGIC:
            raise ValueError(f"entry {entry_index} is not an FDT")
        if struct.unpack_from(">I", blob, 4)[0] != size:
            raise ValueError(f"entry {entry_index} table/FDT size mismatch")
        records.append(record)
        blobs.append(replacement if entry_index == args.index else blob)
        first_blob_offset = offset if first_blob_offset is None else min(first_blob_offset, offset)

    if first_blob_offset is None or first_blob_offset < entry_table_end:
        raise ValueError("invalid first blob offset")

    output = bytearray(source[:first_blob_offset])
    cursor = first_blob_offset
    for entry_index, (record, blob) in enumerate(zip(records, blobs)):
        struct.pack_into(">2I", record, 0, len(blob), cursor)
        record_at = entries_offset + entry_index * entry_size
        output[record_at:record_at + entry_size] = record
        output.extend(blob)
        cursor += len(blob)

    header[1] = len(output)
    struct.pack_into(">8I", output, 0, *header)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    print(
        f"replaced entry {args.index}: {len(source)} -> {len(output)} bytes; "
        f"entry {args.index}: {len(blobs[args.index])} bytes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
