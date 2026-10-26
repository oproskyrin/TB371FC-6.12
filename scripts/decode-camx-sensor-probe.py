#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Decode validated metadata from a CamX sensor module."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path


HEADER_TAG = b"QTI Chromatix Header"
SECTION_TABLE_OFFSET_FIELD = 0x98
SECTION_COUNT_FIELD = 0x9C
SECTION_RECORD = struct.Struct("<QQQ")
SYMBOL_RECORD = struct.Struct("<Q32sQQQQ")
EXPECTED_SECTION_TYPES = {0, 1, 2}
POWER_UP_COUNT_SLOT = 18
POWER_UP_SYMBOL_SLOT = 19
POWER_DOWN_COUNT_SLOT = 20
POWER_DOWN_SYMBOL_SLOT = 21
POWER_SEQUENCE_TYPES = {
    0: "SENSOR_MCLK",
    1: "SENSOR_VANA",
    2: "SENSOR_VDIG",
    3: "SENSOR_VIO",
    4: "SENSOR_VAF",
    5: "SENSOR_VAF_PWDM",
    6: "SENSOR_CUSTOM_REG1",
    7: "SENSOR_CUSTOM_REG2",
    8: "SENSOR_RESET",
    9: "SENSOR_STANDBY",
    10: "SENSOR_CUSTOM_GPIO1",
    11: "SENSOR_CUSTOM_GPIO2",
}
RESOLUTION_MODE_SLOTS = 36


def bounded_slice(blob: bytes, offset: int, size: int, description: str) -> bytes:
    if offset < 0 or size < 0 or offset + size > len(blob):
        raise ValueError(
            f"{description} exceeds file bounds: offset={offset:#x}, size={size:#x}"
        )
    return blob[offset : offset + size]


def parse_sections(blob: bytes) -> dict[int, tuple[int, int]]:
    if not blob.startswith(HEADER_TAG + b"\0"):
        raise ValueError("not a QTI Chromatix Header file")
    if len(blob) < SECTION_COUNT_FIELD + 4:
        raise ValueError("file is shorter than the CamX header")

    declared_size = struct.unpack_from("<I", blob, 0x1C)[0]
    if declared_size != len(blob):
        raise ValueError(
            f"declared size {declared_size:#x} does not match file size {len(blob):#x}"
        )

    table_offset = struct.unpack_from("<I", blob, SECTION_TABLE_OFFSET_FIELD)[0]
    section_count = struct.unpack_from("<I", blob, SECTION_COUNT_FIELD)[0]
    table = bounded_slice(
        blob,
        table_offset,
        section_count * SECTION_RECORD.size,
        "section table",
    )

    sections: dict[int, tuple[int, int]] = {}
    for index in range(section_count):
        section_type, offset, size = SECTION_RECORD.unpack_from(
            table, index * SECTION_RECORD.size
        )
        if section_type in sections:
            raise ValueError(f"duplicate CamX section type {section_type}")
        bounded_slice(blob, offset, size, f"section type {section_type}")
        sections[section_type] = (offset, size)

    if set(sections) != EXPECTED_SECTION_TYPES:
        raise ValueError(f"unexpected CamX section types: {sorted(sections)}")
    return sections


def parse_symbols(blob: bytes, sections: dict[int, tuple[int, int]]) -> list[dict]:
    symbol_offset, symbol_size = sections[0]
    if symbol_size % SYMBOL_RECORD.size:
        raise ValueError(
            f"symbol section size {symbol_size:#x} is not divisible by "
            f"{SYMBOL_RECORD.size:#x}"
        )
    data_offset, data_size = sections[1]
    symbols = []
    symbol_ids = set()

    for record_offset in range(
        symbol_offset, symbol_offset + symbol_size, SYMBOL_RECORD.size
    ):
        symbol_id, raw_name, metadata0, metadata1, offset, size = SYMBOL_RECORD.unpack_from(
            blob, record_offset
        )
        if symbol_id in symbol_ids:
            raise ValueError(f"duplicate CamX symbol ID {symbol_id}")
        symbol_ids.add(symbol_id)
        name = raw_name.split(b"\0", 1)[0].decode("ascii", errors="strict")
        if offset + size > data_size:
            raise ValueError(f"symbol {symbol_id} ({name}) exceeds the data section")
        data = bounded_slice(
            blob, data_offset + offset, size, f"symbol {symbol_id} ({name})"
        )
        symbols.append(
            {
                "id": symbol_id,
                "name": name,
                "metadata0": metadata0,
                "metadata1": metadata1,
                "offset": offset,
                "size": size,
                "sha256": hashlib.sha256(data).hexdigest(),
                "data": data,
            }
        )
    return symbols


def aligned_u32_values(data: bytes) -> list[int]:
    if len(data) % 8:
        raise ValueError("data is not aligned to eight-byte CamX slots")
    return [struct.unpack_from("<I", data, offset)[0] for offset in range(0, len(data), 8)]


def aligned_u64_values(data: bytes) -> list[int]:
    if len(data) % 8:
        raise ValueError("data is not aligned to eight-byte CamX slots")
    return [struct.unpack_from("<Q", data, offset)[0] for offset in range(0, len(data), 8)]


def referenced_u32_array(by_id: dict[int, dict], symbol_id: int, count: int) -> list[int]:
    if symbol_id not in by_id:
        raise ValueError(f"missing referenced symbol {symbol_id}")
    values = aligned_u32_values(by_id[symbol_id]["data"])
    if len(values) != count:
        raise ValueError(
            f"symbol {symbol_id} contains {len(values)} aligned values, expected {count}"
        )
    return values


def decode_stream_configurations(symbols: list[dict]) -> list[dict]:
    streams = []
    for symbol in symbols:
        if symbol["name"] != "streamConfiguration":
            continue
        values = aligned_u32_values(symbol["data"])
        if len(values) != 8:
            raise ValueError(
                f"streamConfiguration symbol {symbol['id']} has {len(values)} slots, expected 8"
            )
        streams.append(
            {
                "symbol_id": symbol["id"],
                "virtual_channel": values[0],
                "csi_data_type": values[1],
                "x_start": values[2],
                "y_start": values[3],
                "width": values[4],
                "height": values[5],
                "bit_width": values[6],
                "stream_type": values[7],
            }
        )
    return streams


def register_table_summaries(symbols: list[dict]) -> list[dict]:
    tables = []
    for symbol in symbols:
        if symbol["name"] != "regSetting":
            continue
        if symbol["size"] % 80:
            raise ValueError(
                f"regSetting symbol {symbol['id']} size is not divisible by 80 bytes"
            )
        tables.append(
            {
                "symbol_id": symbol["id"],
                "register_count": symbol["size"] // 80,
                "sha256": symbol["sha256"],
            }
        )
    return tables


def decode_register_table(symbols: list[dict], symbol_id: int) -> list[dict]:
    by_id = {symbol["id"]: symbol for symbol in symbols}
    if symbol_id not in by_id:
        raise ValueError(f"register table symbol {symbol_id} does not exist")
    table = by_id[symbol_id]
    if table["name"] != "regSetting":
        raise ValueError(f"symbol {symbol_id} is {table['name']}, not regSetting")
    values = aligned_u32_values(table["data"])
    if len(values) % 10:
        raise ValueError(f"regSetting symbol {symbol_id} has an incomplete record")

    registers = []
    for offset in range(0, len(values), 10):
        record = values[offset : offset + 10]
        registers.append(
            {
                "slave_addresses": referenced_u32_array(by_id, record[1], record[0]),
                "register_address": record[2],
                "register_data": referenced_u32_array(by_id, record[4], record[3]),
                "register_address_type": record[5],
                "register_data_type": record[6],
                "operation": record[7],
                "delay_us": referenced_u32_array(by_id, record[9], record[8]),
            }
        )
    return registers


def decode_power_sequence(
    by_id: dict[int, dict], symbol_id: int, count: int, description: str
) -> dict:
    if symbol_id not in by_id:
        raise ValueError(f"{description} references missing symbol {symbol_id}")
    symbol = by_id[symbol_id]
    if symbol["name"] != "powerSetting":
        raise ValueError(
            f"{description} symbol {symbol_id} is {symbol['name']}, not powerSetting"
        )

    values = aligned_u32_values(symbol["data"])
    if len(values) != count * 3:
        raise ValueError(
            f"{description} symbol {symbol_id} has {len(values)} slots, "
            f"expected {count * 3}"
        )

    settings = []
    for offset in range(0, len(values), 3):
        sequence_type, config_value, delay_ms = values[offset : offset + 3]
        if sequence_type not in POWER_SEQUENCE_TYPES:
            raise ValueError(
                f"{description} uses unknown power sequence type {sequence_type}"
            )
        settings.append(
            {
                "sequence_type": sequence_type,
                "sequence_type_name": POWER_SEQUENCE_TYPES[sequence_type],
                "config_value": config_value,
                "delay_ms": delay_ms,
            }
        )

    return {
        "symbol_id": symbol_id,
        "count": count,
        "settings": settings,
    }


def decode_power_sequences(symbols: list[dict]) -> dict:
    by_id = {symbol["id"]: symbol for symbol in symbols}
    roots = [symbol for symbol in symbols if symbol["name"] == "sensorDriverData"]
    if len(roots) != 1:
        raise ValueError(f"expected one sensorDriverData symbol, found {len(roots)}")
    values = aligned_u32_values(roots[0]["data"])
    if len(values) <= POWER_DOWN_SYMBOL_SLOT:
        raise ValueError("sensorDriverData is shorter than its power sequence references")

    return {
        "power_up": decode_power_sequence(
            by_id,
            values[POWER_UP_SYMBOL_SLOT],
            values[POWER_UP_COUNT_SLOT],
            "power-up sequence",
        ),
        "power_down": decode_power_sequence(
            by_id,
            values[POWER_DOWN_SYMBOL_SLOT],
            values[POWER_DOWN_COUNT_SLOT],
            "power-down sequence",
        ),
    }


def decode_lane_assignment(symbols: list[dict], lane_count: int) -> dict:
    candidates = [symbol for symbol in symbols if symbol["name"] == "laneAssign"]
    if len(candidates) != 1:
        raise ValueError(f"expected one laneAssign symbol, found {len(candidates)}")
    symbol = candidates[0]
    values = aligned_u64_values(symbol["data"])
    if len(values) != 1:
        raise ValueError(f"laneAssign symbol {symbol['id']} must contain one slot")

    packed = values[0]
    logical_to_physical = [(packed >> (index * 4)) & 0xF for index in range(lane_count)]
    if len(set(logical_to_physical)) != lane_count:
        raise ValueError("laneAssign contains duplicate physical data lanes")
    return {
        "symbol_id": symbol["id"],
        "packed": f"0x{packed:x}",
        "logical_to_physical_zero_based": logical_to_physical,
    }


def decode_resolution_modes(symbols: list[dict]) -> tuple[list[dict], dict]:
    by_id = {symbol["id"]: symbol for symbol in symbols}
    resolution_info = [symbol for symbol in symbols if symbol["name"] == "resolutionInfo"]
    if len(resolution_info) != 1:
        raise ValueError(f"expected one resolutionInfo symbol, found {len(resolution_info)}")
    info_values = aligned_u32_values(resolution_info[0]["data"])
    if len(info_values) != 4:
        raise ValueError("resolutionInfo must contain two count/reference pairs")

    mode_count, mode_symbol_id = info_values[2:4]
    if mode_symbol_id not in by_id:
        raise ValueError(f"resolutionInfo references missing symbol {mode_symbol_id}")
    mode_symbol = by_id[mode_symbol_id]
    if mode_symbol["name"] != "resolutionData":
        raise ValueError(
            f"resolutionInfo symbol {mode_symbol_id} is {mode_symbol['name']}, "
            "not resolutionData"
        )
    values = aligned_u64_values(mode_symbol["data"])
    if len(values) != mode_count * RESOLUTION_MODE_SLOTS:
        raise ValueError(
            f"resolutionData has {len(values)} slots, expected "
            f"{mode_count * RESOLUTION_MODE_SLOTS}"
        )

    modes = []
    lane_counts = set()
    for index in range(mode_count):
        mode = values[index * RESOLUTION_MODE_SLOTS : (index + 1) * RESOLUTION_MODE_SLOTS]
        stream_count, stream_symbol_id = mode[1:3]
        if stream_symbol_id not in by_id:
            raise ValueError(f"mode {index} references missing stream symbol {stream_symbol_id}")
        stream_symbol = by_id[stream_symbol_id]
        if stream_symbol["name"] != "streamConfiguration":
            raise ValueError(
                f"mode {index} stream symbol {stream_symbol_id} is "
                f"{stream_symbol['name']}"
            )
        if stream_count != 1:
            raise ValueError(
                f"mode {index} has {stream_count} streams; link-frequency derivation "
                "currently requires one"
            )
        stream_values = aligned_u32_values(stream_symbol["data"])
        if len(stream_values) != 8:
            raise ValueError(f"mode {index} streamConfiguration has an unexpected size")

        lane_count = mode[11]
        lane_counts.add(lane_count)
        is_3phase = bool(mode[15])
        output_pixel_clock_hz = mode[7]
        bit_width = stream_values[6]
        dphy_link_frequency_hz = None
        if not is_3phase:
            if lane_count == 0:
                raise ValueError(f"mode {index} has zero D-PHY lanes")
            denominator = 2 * lane_count
            numerator = output_pixel_clock_hz * bit_width
            if numerator % denominator:
                raise ValueError(f"mode {index} has a non-integral D-PHY link frequency")
            dphy_link_frequency_hz = numerator // denominator

        register_count, register_symbol_id = mode[18:20]
        if register_symbol_id not in by_id:
            raise ValueError(
                f"mode {index} references missing regSetting symbol {register_symbol_id}"
            )
        register_symbol = by_id[register_symbol_id]
        if register_symbol["name"] != "regSetting":
            raise ValueError(
                f"mode {index} register symbol {register_symbol_id} is "
                f"{register_symbol['name']}"
            )
        if register_symbol["size"] != register_count * 80:
            raise ValueError(f"mode {index} register count does not match its symbol size")

        modes.append(
            {
                "index": index,
                "color_filter_arrangement": mode[0],
                "stream_configuration_symbol_id": stream_symbol_id,
                "line_length_pixel_clock": mode[3],
                "frame_length_lines": mode[4],
                "min_horizontal_blanking": mode[5],
                "min_vertical_blanking": mode[6],
                "output_pixel_clock_hz": output_pixel_clock_hz,
                "horizontal_binning": mode[8],
                "vertical_binning": mode[9],
                "frame_rate": struct.unpack("<d", struct.pack("<Q", mode[10]))[0],
                "lane_count": lane_count,
                "settle_time_ns": mode[14],
                "is_3phase": is_3phase,
                "dphy_link_frequency_hz": dphy_link_frequency_hz,
                "register_setting_count": register_count,
                "register_setting_symbol_id": register_symbol_id,
            }
        )

    if len(lane_counts) != 1:
        raise ValueError(f"modes use inconsistent lane counts: {sorted(lane_counts)}")
    return modes, decode_lane_assignment(symbols, lane_counts.pop())


def decode_probe(symbols: list[dict]) -> dict:
    by_id = {symbol["id"]: symbol for symbol in symbols}
    roots = [symbol for symbol in symbols if symbol["name"] == "sensorDriverData"]
    if len(roots) != 1:
        raise ValueError(f"expected one sensorDriverData symbol, found {len(roots)}")

    values = aligned_u32_values(roots[0]["data"])
    if len(values) < 11:
        raise ValueError("sensorDriverData is shorter than its documented probe prefix")
    name_length = values[3]
    name_symbol_id = values[4]
    if name_symbol_id not in by_id:
        raise ValueError(f"sensor name references missing symbol {name_symbol_id}")
    name_data = by_id[name_symbol_id]["data"]
    if name_length > len(name_data):
        raise ValueError("sensor name length exceeds referenced symbol data")
    sensor_name = name_data[:name_length].split(b"\0", 1)[0].decode("ascii")

    return {
        "format_version": {
            "major": values[0],
            "minor": values[1],
            "patch": values[2],
        },
        "sensor_name": sensor_name,
        "sensor_name_symbol_id": name_symbol_id,
        "slave_address_8bit": values[5],
        "slave_address_7bit": values[5] >> 1,
        "register_address_type": values[6],
        "register_data_type": values[7],
        "sensor_id_register": values[8],
        "sensor_id": values[9],
        "sensor_id_mask": values[10],
        "remaining_root_slots": values[11:],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("module", type=Path, help="CamX com.qti.sensormodule.*.bin")
    parser.add_argument(
        "--symbols",
        action="store_true",
        help="include the complete symbol directory without proprietary payload bytes",
    )
    parser.add_argument(
        "--raw-root",
        action="store_true",
        help="include undecoded aligned sensorDriverData slots after the probe prefix",
    )
    parser.add_argument(
        "--register-table",
        action="append",
        default=[],
        type=lambda value: int(value, 0),
        metavar="SYMBOL_ID",
        help="decode one local regSetting symbol; may be specified repeatedly",
    )
    args = parser.parse_args()

    blob = args.module.read_bytes()
    sections = parse_sections(blob)
    symbols = parse_symbols(blob, sections)
    probe = decode_probe(symbols)
    resolution_modes, lane_assignment = decode_resolution_modes(symbols)
    if not args.raw_root:
        remaining_slots = probe.pop("remaining_root_slots")
        remaining_bytes = b"".join(struct.pack("<I", value) for value in remaining_slots)
        probe["remaining_root_slot_count"] = len(remaining_slots)
        probe["remaining_root_slots_sha256"] = hashlib.sha256(remaining_bytes).hexdigest()

    result = {
        "file": str(args.module.resolve()),
        "file_size": len(blob),
        "file_sha256": hashlib.sha256(blob).hexdigest(),
        "sections": {
            str(section_type): {"offset": offset, "size": size}
            for section_type, (offset, size) in sorted(sections.items())
        },
        "symbol_count": len(symbols),
        "probe": probe,
        "power_sequences": decode_power_sequences(symbols),
        "resolution_modes": resolution_modes,
        "lane_assignment": lane_assignment,
        "stream_configurations": decode_stream_configurations(symbols),
        "register_tables": register_table_summaries(symbols),
    }
    if args.symbols:
        result["symbols"] = [
            {key: value for key, value in symbol.items() if key != "data"}
            for symbol in symbols
        ]
    if args.register_table:
        result["decoded_register_tables"] = {
            str(symbol_id): decode_register_table(symbols, symbol_id)
            for symbol_id in args.register_table
        }
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, UnicodeError, ValueError, struct.error) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
