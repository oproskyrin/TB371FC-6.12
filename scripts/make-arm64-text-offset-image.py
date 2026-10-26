#!/usr/bin/env python3
"""Create an isolated ARM64 Image with a legacy boot-protocol text offset."""

from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path


ARM64_MAGIC_OFFSET = 56
ARM64_MAGIC = b"ARM\x64"
TEXT_OFFSET_FIELD = 8


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_int(value: str) -> int:
    return int(value, 0)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Copy an uncompressed ARM64 Image and change only its 64-bit "
            "text_offset header field."
        )
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--text-offset", type=parse_int, default=0x80000)
    args = parser.parse_args()

    if args.output.exists():
        raise SystemExit(f"refusing to overwrite existing output: {args.output}")
    if not 0 < args.text_offset < 2**64:
        raise SystemExit("text offset must be a positive unsigned 64-bit value")
    if args.text_offset >= 2 * 1024 * 1024:
        raise SystemExit("text offset must be below the ARM64 2 MiB placement boundary")

    source = args.input.read_bytes()
    if len(source) < 64:
        raise SystemExit("input is too short to contain an ARM64 Image header")
    if source[ARM64_MAGIC_OFFSET : ARM64_MAGIC_OFFSET + 4] != ARM64_MAGIC:
        raise SystemExit("input does not contain ARM64 Image magic at offset 0x38")

    old_offset = struct.unpack_from("<Q", source, TEXT_OFFSET_FIELD)[0]
    image_size = struct.unpack_from("<Q", source, 16)[0]
    flags = struct.unpack_from("<Q", source, 24)[0]
    reserved = struct.unpack_from("<QQQ", source, 32)
    if old_offset != 0:
        raise SystemExit(f"expected source text_offset 0, found {old_offset:#x}")
    if image_size == 0:
        raise SystemExit("ARM64 Image header reports an invalid zero image_size")
    if any(reserved):
        raise SystemExit(f"ARM64 Image reserved header fields are non-zero: {reserved!r}")

    output = bytearray(source)
    struct.pack_into("<Q", output, TEXT_OFFSET_FIELD, args.text_offset)
    changed = [index for index, pair in enumerate(zip(source, output)) if pair[0] != pair[1]]
    expected = [
        TEXT_OFFSET_FIELD + index
        for index, byte in enumerate(struct.pack("<Q", args.text_offset))
        if byte
    ]
    if changed != expected:
        raise SystemExit(f"unexpected byte changes: {changed!r}; expected {expected!r}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    reread = args.output.read_bytes()
    if reread != output:
        raise SystemExit("output verification failed after writing")

    print(f"input:       {args.input}")
    print(f"output:      {args.output}")
    print(f"size:        {len(source)}")
    print(f"image_size:  {image_size:#x}")
    print(f"flags:       {flags:#x}")
    print(f"text_offset: {old_offset:#x} -> {args.text_offset:#x}")
    print(f"changed:     {', '.join(hex(index) for index in changed)}")
    print(f"input sha256:  {sha256(source)}")
    print(f"output sha256: {sha256(reread)}")


if __name__ == "__main__":
    main()
