#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Verify the S5K4H7 driver tables against a validated TB371FC CamX module."""

from __future__ import annotations

import argparse
import importlib.util
import re
from pathlib import Path


ARRAYS = {
    "s5k4h7_common_regs": 369,
    "s5k4h7_3264x2448_regs": 24,
    "s5k4h7_3264x1836_regs": 184,
}
NAMED_REGISTERS = {
    "S5K4H7_REG_MODE_SELECT": 0x0100,
    "S5K4H7_REG_ORIENTATION": 0x0101,
}
ENTRY_RE = re.compile(
    r"\{\s*(?:(?:CCI_REG8\(0x([0-9a-fA-F]+)\))|"
    r"(S5K4H7_REG_MODE_SELECT|S5K4H7_REG_ORIENTATION))\s*,\s*"
    r"(0x[0-9a-fA-F]+)\s*\}"
)


def load_decoder(path: Path):
    spec = importlib.util.spec_from_file_location("tb371fc_camx_decoder", path)
    if spec is None or spec.loader is None:
        raise ValueError(f"cannot load decoder from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_driver_array(source: str, name: str) -> list[tuple[int, int]]:
    match = re.search(
        rf"static const struct cci_reg_sequence {re.escape(name)}\[\] = \{{"
        rf"(.*?)\n\}};",
        source,
        re.DOTALL,
    )
    if not match:
        raise ValueError(f"driver array {name} is absent")

    entries = []
    for entry in ENTRY_RE.finditer(match.group(1)):
        address = int(entry.group(1), 16) if entry.group(1) else NAMED_REGISTERS[entry.group(2)]
        entries.append((address, int(entry.group(3), 16)))
    return entries


def decode_stock_table(decoder, module: Path, symbol_id: int) -> list[tuple[int, int]]:
    blob = module.read_bytes()
    sections = decoder.parse_sections(blob)
    symbols = decoder.parse_symbols(blob, sections)
    records = decoder.decode_register_table(symbols, symbol_id)
    result = []
    for index, record in enumerate(records):
        if record["operation"] != 0 or record["register_data_type"] != 1:
            raise ValueError(
                f"stock symbol {symbol_id} record {index} is not a one-byte write"
            )
        data = record["register_data"]
        if len(data) != 1:
            raise ValueError(f"stock symbol {symbol_id} record {index} has {len(data)} bytes")
        result.append((record["register_address"], data[0]))
    return result


def first_difference(
    expected: list[tuple[int, int]], actual: list[tuple[int, int]]
) -> str:
    for index, (left, right) in enumerate(zip(expected, actual, strict=False)):
        if left != right:
            return f"record {index}: stock={left!r}, driver={right!r}"
    return f"record count: stock={len(expected)}, driver={len(actual)}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("module", type=Path, help="stock S5K4H7 CamX module")
    parser.add_argument("driver", type=Path, help="s5k4h7.c")
    parser.add_argument(
        "--decoder",
        type=Path,
        default=Path(__file__).with_name("decode-camx-sensor-probe.py"),
    )
    args = parser.parse_args()

    decoder = load_decoder(args.decoder.resolve())
    source = args.driver.read_text(encoding="utf-8")

    for array_name, symbol_id in ARRAYS.items():
        stock = decode_stock_table(decoder, args.module, symbol_id)
        if array_name == "s5k4h7_common_regs":
            # CamX serializes two writes to read-only chip-ID address 0x0000.
            # The published S5K4H7 driver omits them, so the V4L2 driver does too.
            stock = [entry for entry in stock if entry[0] != 0x0000]
        driver = parse_driver_array(source, array_name)
        if stock != driver:
            raise SystemExit(
                f"FAIL {array_name}: {first_difference(stock, driver)}"
            )
        print(f"PASS {array_name}: {len(driver)} exact writes")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
