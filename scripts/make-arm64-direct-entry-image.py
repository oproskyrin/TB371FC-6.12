#!/usr/bin/env python3
"""Convert an ARM64 NOP+branch Image entry to Lenovo's branch+zero form."""

from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path


NOP = 0xD503201F
BRANCH_OPCODE = 0x14000000
BRANCH_MASK = 0xFC000000
IMM26_MASK = 0x03FFFFFF
ARM64_MAGIC = b"ARM\x64"


def sign_extend_26(value: int) -> int:
    return value - (1 << 26) if value & (1 << 25) else value


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Move the ARM64 entry branch from code1 to code0 without changing its target."
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    if args.output.exists():
        raise SystemExit(f"refusing to overwrite existing output: {args.output}")
    source = args.input.read_bytes()
    if len(source) < 64 or source[56:60] != ARM64_MAGIC:
        raise SystemExit("input is not an uncompressed ARM64 Image")

    code0, code1 = struct.unpack_from("<II", source, 0)
    if code0 != NOP:
        raise SystemExit(f"expected code0 NOP {NOP:#010x}, found {code0:#010x}")
    if code1 & BRANCH_MASK != BRANCH_OPCODE:
        raise SystemExit(f"expected an unconditional branch in code1, found {code1:#010x}")

    old_imm = code1 & IMM26_MASK
    if old_imm == IMM26_MASK:
        raise SystemExit("branch immediate cannot be advanced without wrapping")
    new_imm = old_imm + 1
    new_code0 = BRANCH_OPCODE | new_imm
    old_target = 4 + (sign_extend_26(old_imm) << 2)
    new_target = sign_extend_26(new_imm) << 2
    if old_target != new_target:
        raise SystemExit(f"branch target changed: {old_target:#x} != {new_target:#x}")

    output = bytearray(source)
    struct.pack_into("<II", output, 0, new_code0, 0)
    if output[8:] != source[8:]:
        raise SystemExit("unexpected change after the first two instructions")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    if args.output.read_bytes() != output:
        raise SystemExit("output verification failed")

    print(f"code0:  {code0:#010x} -> {new_code0:#010x}")
    print(f"code1:  {code1:#010x} -> 0x00000000")
    print(f"target: {old_target:#x}")
    print(f"size:   {len(source)}")
    print(f"input sha256:  {sha256(source)}")
    print(f"output sha256: {sha256(output)}")


if __name__ == "__main__":
    main()
