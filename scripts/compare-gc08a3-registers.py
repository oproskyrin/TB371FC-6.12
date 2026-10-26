#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Compare stock TB371FC GC08A3 tables with an upstream Linux driver."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path


def load_camx_decoder(script_dir: Path):
    decoder_path = script_dir / "decode-camx-sensor-probe.py"
    spec = importlib.util.spec_from_file_location("tb371fc_camx_decoder", decoder_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load decoder: {decoder_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_cci_table(source: str, name: str) -> list[tuple[int, int]]:
    declaration = re.compile(
        rf"static\s+const\s+struct\s+cci_reg_sequence\s+{re.escape(name)}"
        rf"\s*\[\s*\]\s*=\s*\{{(.*?)\n\}};",
        re.DOTALL,
    )
    match = declaration.search(source)
    if match is None:
        raise ValueError(f"could not find upstream CCI table {name}")
    rows = [
        (int(address, 16), int(value, 16))
        for address, value in re.findall(
            r"CCI_REG8\((0x[0-9a-fA-F]+)\)\s*,\s*(0x[0-9a-fA-F]+)",
            match.group(1),
        )
    ]
    if not rows:
        raise ValueError(f"upstream CCI table {name} contains no CCI_REG8 rows")
    return rows


def flatten_stock_table(decoder, symbols: list[dict], symbol_id: int) -> list[tuple[int, int]]:
    writes = []
    for record in decoder.decode_register_table(symbols, symbol_id):
        if record["slave_addresses"]:
            raise ValueError(f"stock table {symbol_id} changes I2C slave address")
        if record["operation"] != 0:
            raise ValueError(f"stock table {symbol_id} uses operation {record['operation']}")
        if record["delay_us"] not in ([], [0]):
            raise ValueError(f"stock table {symbol_id} contains a non-zero delay")
        if len(record["register_data"]) != 1:
            raise ValueError(f"stock table {symbol_id} has a multi-value write")
        writes.append((record["register_address"], record["register_data"][0]))
    return writes


def final_map(writes: list[tuple[int, int]]) -> dict[int, int]:
    result = {}
    for address, value in writes:
        result[address] = value
    return result


def hex_value(value: int | None) -> str | None:
    return None if value is None else f"0x{value:x}"


def compare_maps(left: dict[int, int], right: dict[int, int]) -> dict:
    shared = set(left) & set(right)
    differences = [
        {
            "address": hex_value(address),
            "stock": hex_value(left[address]),
            "upstream": hex_value(right[address]),
        }
        for address in sorted(shared)
        if left[address] != right[address]
    ]
    return {
        "stock_final_address_count": len(left),
        "upstream_final_address_count": len(right),
        "shared_final_address_count": len(shared),
        "different_final_values": differences,
        "stock_only_addresses": [hex_value(value) for value in sorted(set(left) - set(right))],
        "upstream_only_addresses": [
            hex_value(value) for value in sorted(set(right) - set(left))
        ],
    }


def stock_mode_delta(full: dict[int, int], crop: dict[int, int]) -> list[dict]:
    return [
        {
            "address": hex_value(address),
            "full": hex_value(full.get(address)),
            "crop": hex_value(crop.get(address)),
        }
        for address in sorted(set(full) | set(crop))
        if full.get(address) != crop.get(address)
    ]


def verify_tb371fc(result: dict) -> None:
    expected_full_differences = [
        {"address": "0x9a", "stock": "0x0", "upstream": "0x66"},
        {"address": "0x336", "stock": "0x72", "upstream": "0x70"},
    ]
    expected_crop_delta = [
        {"address": "0x336", "full": "0x72", "crop": "0x70"},
        {"address": "0x34e", "full": "0x9", "crop": "0x7"},
        {"address": "0x34f", "full": "0x90", "crop": "0x2c"},
        {"address": "0x351", "full": "0x0", "crop": "0x1"},
        {"address": "0x352", "full": "0x6", "crop": "0x38"},
    ]
    full = result["combined_full_comparison"]
    checks = {
        "stock final register count": full["stock_final_address_count"] == 275,
        "upstream final register count": full["upstream_final_address_count"] == 275,
        "shared final register count": full["shared_final_address_count"] == 275,
        "no stock-only addresses": not full["stock_only_addresses"],
        "no upstream-only addresses": not full["upstream_only_addresses"],
        "expected full-mode differences": (
            full["different_final_values"] == expected_full_differences
        ),
        "expected crop delta": result["stock_full_to_crop_delta"] == expected_crop_delta,
    }
    failed = [description for description, passed in checks.items() if not passed]
    if failed:
        raise ValueError("TB371FC GC08A3 verification failed: " + "; ".join(failed))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stock_module", type=Path, help="stock GC08A3 CamX sensor module")
    parser.add_argument("upstream_driver", type=Path, help="Linux drivers/media/i2c/gc08a3.c")
    parser.add_argument(
        "--verify-tb371fc",
        action="store_true",
        help="fail unless the known ZUI 16.0.474 versus Linux 7.1 result matches",
    )
    args = parser.parse_args()

    decoder = load_camx_decoder(Path(__file__).resolve().parent)
    stock_blob = args.stock_module.read_bytes()
    sections = decoder.parse_sections(stock_blob)
    symbols = decoder.parse_symbols(stock_blob, sections)
    probe = decoder.decode_probe(symbols)
    if probe["sensor_id"] != 0x08A3:
        raise ValueError(f"stock module sensor ID is {probe['sensor_id']:#x}, not GC08A3")

    init_settings = [symbol for symbol in symbols if symbol["name"] == "initSettings"]
    if len(init_settings) != 1:
        raise ValueError(f"expected one initSettings symbol, found {len(init_settings)}")
    init_values = decoder.aligned_u32_values(init_settings[0]["data"])
    if len(init_values) != 3:
        raise ValueError("initSettings must contain operation, count and symbol reference")
    init_count, init_symbol_id = init_values[1:3]

    modes, _lane_assignment = decoder.decode_resolution_modes(symbols)
    if len(modes) != 2:
        raise ValueError(f"expected two stock GC08A3 modes, found {len(modes)}")
    stock_init = flatten_stock_table(decoder, symbols, init_symbol_id)
    if len(stock_init) != init_count:
        raise ValueError("stock initSettings count does not match decoded table")
    stock_full = flatten_stock_table(
        decoder, symbols, modes[0]["register_setting_symbol_id"]
    )
    stock_crop = flatten_stock_table(
        decoder, symbols, modes[1]["register_setting_symbol_id"]
    )

    upstream_blob = args.upstream_driver.read_bytes()
    upstream_source = upstream_blob.decode("utf-8")
    upstream_common = parse_cci_table(upstream_source, "mode_table_common")
    upstream_full = parse_cci_table(upstream_source, "mode_3264x2448")

    result = {
        "stock_module_sha256": hashlib.sha256(stock_blob).hexdigest(),
        "upstream_driver_sha256": hashlib.sha256(upstream_blob).hexdigest(),
        "record_counts": {
            "stock_init": len(stock_init),
            "upstream_common": len(upstream_common),
            "stock_full": len(stock_full),
            "upstream_full": len(upstream_full),
            "stock_crop": len(stock_crop),
        },
        "init_comparison": compare_maps(final_map(stock_init), final_map(upstream_common)),
        "combined_full_comparison": compare_maps(
            final_map(stock_init + stock_full),
            final_map(upstream_common + upstream_full),
        ),
        "stock_full_to_crop_delta": stock_mode_delta(
            final_map(stock_init + stock_full),
            final_map(stock_init + stock_crop),
        ),
    }
    if args.verify_tb371fc:
        verify_tb371fc(result)
        result["tb371fc_verification"] = "passed"

    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, UnicodeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
