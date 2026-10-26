#!/usr/bin/env python3
"""Reproduce Linux MSM DSC 1.1 pre-SCR PPS for the TB371FC panel."""

from __future__ import annotations


STOCK_PPS = bytes.fromhex(
    "11 00 00 89 30 80 07 30 0b 80 00 14 02 e0 02 e0 "
    "02 00 02 71 00 20 02 33 00 0a 00 0c 05 0e 03 ac "
    "18 00 10 d0 03 0c 20 00 06 0b 0b 33 0e 1c 2a 38 "
    "46 54 62 69 70 77 79 7b 7d 7e 01 02 01 00 09 40 "
    "09 be 19 fc 19 fa 19 f8 1a 38 1a 78 1a b6 2a f6 "
    "2b 34 2b 74 3b 74 6b f4 00 00 00 00 00 00 00 00 "
    "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "
    "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
)


def div_round_up(value: int, divisor: int) -> int:
    return (value + divisor - 1) // divisor


def put_be16(payload: bytearray, offset: int, value: int) -> None:
    payload[offset : offset + 2] = value.to_bytes(2, "big")


def build_pps() -> tuple[bytes, dict[str, int]]:
    # panel-novatek-nt36523.c plus dsi_populate_dsc_params() in Linux 7.1.7.
    pic_width, pic_height = 2944, 1840
    slice_width, slice_height = 736, 20
    bits_per_component, bits_per_pixel = 8, 8 << 4
    rc_model_size, initial_xmit_delay, initial_offset = 8192, 512, 6144
    first_line_bpg_offset = 12
    mux_word_size = 48

    groups_per_line = div_round_up(slice_width, 3)
    chunk_size = div_round_up(slice_width * bits_per_pixel, 8 * 16)
    num_extra_mux_bits = 3 * (mux_word_size + (4 * bits_per_component + 4) - 2)
    slice_bits = 8 * chunk_size * slice_height
    while num_extra_mux_bits and (slice_bits - num_extra_mux_bits) % mux_word_size:
        num_extra_mux_bits -= 1

    initial_scale_value = 8 * rc_model_size // (rc_model_size - initial_offset)
    scale_decrement_interval = groups_per_line // (initial_scale_value - 8)
    final_offset = (
        rc_model_size
        - (initial_xmit_delay * bits_per_pixel + 8) // 16
        + num_extra_mux_bits
    )
    final_scale = rc_model_size * 8 // (rc_model_size - final_offset)
    nfl_bpg_offset = div_round_up(first_line_bpg_offset << 11, slice_height - 1)
    groups_total = groups_per_line * slice_height
    slice_bpg_offset = div_round_up(
        (rc_model_size - initial_offset + num_extra_mux_bits) << 11,
        groups_total,
    )
    scale_increment_interval = (
        final_offset
        * (1 << 11)
        // ((nfl_bpg_offset + slice_bpg_offset) * (final_scale - 9))
    )
    rbs_min = (
        rc_model_size
        - initial_offset
        + div_round_up(initial_xmit_delay * bits_per_pixel, 16)
        + groups_per_line * first_line_bpg_offset
    )
    hrd_delay = div_round_up(rbs_min * 16, bits_per_pixel)
    initial_dec_delay = hrd_delay - initial_xmit_delay

    payload = bytearray(128)
    payload[0] = 0x11
    payload[3] = 0x89  # 8 bpc, line-buffer depth 9
    payload[4] = 0x30 | ((bits_per_pixel >> 8) & 0x03)  # block prediction + RGB
    payload[5] = bits_per_pixel & 0xFF
    put_be16(payload, 6, pic_height)
    put_be16(payload, 8, pic_width)
    put_be16(payload, 10, slice_height)
    put_be16(payload, 12, slice_width)
    put_be16(payload, 14, chunk_size)
    payload[16] = (initial_xmit_delay >> 8) & 0x03
    payload[17] = initial_xmit_delay & 0xFF
    put_be16(payload, 18, initial_dec_delay)
    payload[21] = initial_scale_value
    put_be16(payload, 22, scale_increment_interval)
    put_be16(payload, 24, scale_decrement_interval)
    payload[27] = first_line_bpg_offset
    put_be16(payload, 28, nfl_bpg_offset)
    put_be16(payload, 30, slice_bpg_offset)
    put_be16(payload, 32, initial_offset)
    put_be16(payload, 34, final_offset)
    payload[36:44] = bytes((3, 12, 0x20, 0, 6, 11, 11, 0x33))
    payload[44:58] = bytes((14, 28, 42, 56, 70, 84, 98, 105, 112, 119, 121, 123, 125, 126))

    rc_ranges = (
        (0, 4, 2), (0, 4, 0), (1, 5, 0), (1, 6, -2), (3, 7, -4),
        (3, 7, -6), (3, 7, -8), (3, 8, -8), (3, 9, -8), (3, 10, -10),
        (5, 11, -10), (5, 12, -12), (5, 13, -12), (7, 13, -12), (13, 15, -12),
    )
    for index, (minimum, maximum, offset) in enumerate(rc_ranges):
        packed = (minimum << 11) | (maximum << 6) | (offset & 0x3F)
        put_be16(payload, 58 + index * 2, packed)

    values = {
        "chunk_size": chunk_size,
        "initial_dec_delay": initial_dec_delay,
        "scale_increment_interval": scale_increment_interval,
        "scale_decrement_interval": scale_decrement_interval,
        "nfl_bpg_offset": nfl_bpg_offset,
        "slice_bpg_offset": slice_bpg_offset,
        "final_offset": final_offset,
        "num_extra_mux_bits": num_extra_mux_bits,
    }
    return bytes(payload), values


def main() -> int:
    generated, values = build_pps()
    if generated != STOCK_PPS:
        for offset, (actual, expected) in enumerate(zip(generated, STOCK_PPS)):
            if actual != expected:
                print(f"PPS mismatch at 0x{offset:02x}: mainline={actual:02x} stock={expected:02x}")
        return 1

    print("TB371FC mainline DSC PPS matches all 128 bytes of the captured Lenovo PPS.")
    print(" ".join(f"{name}={value}" for name, value in values.items()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
