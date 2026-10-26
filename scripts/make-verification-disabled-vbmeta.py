#!/usr/bin/env python3
"""Create a TB371FC test vbmeta_b by changing only the AVB flags field."""

from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path


EXPECTED_SOURCE_SHA256 = (
    "58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05"
)
EXPECTED_SIZE = 65536
FLAGS_OFFSET = 120
FLAGS_SIZE = 4
VERIFICATION_DISABLED_FLAGS = 0x3


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Patch only AVB hashtree/verification flags in exact vbmeta_b"
    )
    parser.add_argument("source", type=Path, help="Exact EDL vbmeta_b backup")
    parser.add_argument("output", type=Path, help="Generated test vbmeta image")
    args = parser.parse_args()

    source = args.source.read_bytes()
    if len(source) != EXPECTED_SIZE:
        raise SystemExit(f"unexpected vbmeta_b size: {len(source)}")
    source_hash = sha256(source)
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise SystemExit(
            f"source SHA-256 mismatch: expected {EXPECTED_SOURCE_SHA256}, got {source_hash}"
        )
    if source[:4] != b"AVB0":
        raise SystemExit("source does not begin with AVB0")

    original_flags = struct.unpack_from(">I", source, FLAGS_OFFSET)[0]
    if original_flags != 0:
        raise SystemExit(f"source AVB flags are already non-zero: {original_flags:#x}")

    output = bytearray(source)
    struct.pack_into(">I", output, FLAGS_OFFSET, VERIFICATION_DISABLED_FLAGS)
    changed_offsets = [i for i, (before, after) in enumerate(zip(source, output)) if before != after]
    expected_changed_offsets = [FLAGS_OFFSET + FLAGS_SIZE - 1]
    if changed_offsets != expected_changed_offsets:
        raise SystemExit(f"unexpected changed byte offsets: {changed_offsets}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    output_hash = sha256(output)
    print(f"source: {args.source} ({len(source)} bytes) SHA-256 {source_hash}")
    print(f"output: {args.output} ({len(output)} bytes) SHA-256 {output_hash}")
    print("AVB flags: 0x00000000 -> 0x00000003")
    print(f"Only changed byte offset: {changed_offsets[0]} (inside flags field 120..123)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
