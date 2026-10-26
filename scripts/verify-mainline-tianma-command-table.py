#!/usr/bin/env python3
"""Verify that the mainline Tianma init table matches the active stock DTB."""

from pathlib import Path
import re


PROJECT = Path(__file__).resolve().parent.parent
PATCH = PROJECT / "mainline-port/patches/0001-drm-panel-nt36523-add-lenovo-tb371fc-nt36532.patch"
RESET_PATCH = PROJECT / "mainline-port/patches/0010-drm-panel-tb371fc-match-stock-reset-sequence.patch"
TRANSPORT_PATCH = PROJECT / "mainline-port/patches/0012-drm-panel-tb371fc-match-stock-dcs-packet-types.patch"
STOCK = (
    PROJECT
    / "diagnostics/v24-live-panel-dt"
    / "qcom,mdss_dsi_panel_spinel_tianma_nt36532_dsc_3k_video"
    / "qcom,mdss-dsi-display-timings/timing@0/qcom,mdss-dsi-on-command"
)
STOCK_RESET = STOCK.parents[2] / "qcom,mdss-dsi-reset-sequence"
STOCK_STATE = STOCK.with_name("qcom,mdss-dsi-on-command-state")


def decode_stock(data: bytes) -> list[dict[str, int | bytes]]:
    commands = []
    offset = 0
    while offset < len(data):
        if offset + 7 > len(data):
            raise ValueError(f"short stock command header at {offset}")
        length = int.from_bytes(data[offset + 5 : offset + 7], "big")
        end = offset + 7 + length
        if end > len(data):
            raise ValueError(f"short stock command payload at {offset}")
        commands.append(
            {
                "dtype": data[offset],
                "last": data[offset + 1],
                "vc": data[offset + 2],
                "ack": data[offset + 3],
                "wait": data[offset + 4],
                "payload": data[offset + 7 : end],
            }
        )
        offset = end
    return commands


def decode_patch(text: str) -> list[bytes]:
    start = text.index("+static int tb371fc_nt36532_init_sequence")
    end = text.index("+static int tb371fc_boe_init_sequence", start)
    lines = [line[1:] for line in text[start:end].splitlines() if line.startswith("+")]
    commands = []
    in_boe = False
    boe_depth = 0
    symbols = {
        "MIPI_DCS_EXIT_SLEEP_MODE": 0x11,
        "MIPI_DCS_SET_DISPLAY_ON": 0x29,
    }

    for line in lines:
        stripped = line.strip()
        if stripped == "if (boe) {":
            in_boe = True
            boe_depth = 1
            continue
        if in_boe:
            boe_depth += line.count("{") - line.count("}")
            if boe_depth == 0:
                in_boe = False
            continue
        if "mipi_dsi_dual_dcs_write_seq_multi" not in line:
            continue
        match = re.search(r"dsi1,\s*(.*?)\);", line)
        if not match:
            raise ValueError(f"cannot parse mainline command: {line}")
        values = []
        for token in (part.strip() for part in match.group(1).split(",")):
            values.append(symbols[token] if token in symbols else int(token, 0))
        commands.append(bytes(values))
    return commands


def decode_stock_reset(data: bytes) -> list[tuple[int, int]]:
    if len(data) % 8:
        raise ValueError("stock reset sequence does not contain value/delay pairs")
    values = [int.from_bytes(data[offset : offset + 4], "big") for offset in range(0, len(data), 4)]
    return list(zip(values[0::2], values[1::2]))


def decode_patch_reset(text: str) -> list[tuple[int, int]]:
    start = text.index("+\tif (pinfo->desc == &tb371fc_boe_desc")
    end = text.index("+\t\treturn;", start)
    lines = [line[1:].strip() for line in text[start:end].splitlines() if line.startswith("+")]
    logical = []
    delays = []
    for line in lines:
        gpio = re.search(r"gpiod_set_value_cansleep\(pinfo->reset_gpio, ([01])\)", line)
        if gpio:
            # The DT describes an active-low GPIO. Convert Linux logical value
            # back to the raw physical level used by Lenovo's packed property.
            logical.append(1 - int(gpio.group(1)))
        delay = re.search(r"usleep_range\((\d+),", line)
        if delay:
            delays.append(int(delay.group(1)) // 1000)
    if len(logical) != len(delays):
        raise ValueError("mainline reset levels and delays are unbalanced")
    return list(zip(logical, delays))


def main() -> None:
    stock = decode_stock(STOCK.read_bytes())
    mainline = decode_patch(PATCH.read_text(encoding="utf-8"))
    transport = TRANSPORT_PATCH.read_text(encoding="utf-8")
    payloads = [record["payload"] for record in stock]
    # Qualcomm's packed DT represents no-parameter DCS 0x11/0x29 with a
    # trailing zero byte, while the mainline helper emits the canonical
    # one-byte DCS command. They are equivalent on the wire.
    canonical_stock = [
        payload[:1] if payload in (b"\x11\x00", b"\x29\x00") else payload
        for payload in payloads
    ]
    if mainline != canonical_stock:
        for index, (expected, actual) in enumerate(zip(canonical_stock, mainline)):
            if expected != actual:
                raise SystemExit(
                    f"command {index} differs: stock={expected.hex(' ')} "
                    f"mainline={actual.hex(' ')}"
                )
        raise SystemExit(
            f"command count differs: stock={len(stock)} mainline={len(mainline)}"
        )

    stock_reset = decode_stock_reset(STOCK_RESET.read_bytes())
    mainline_reset = decode_patch_reset(RESET_PATCH.read_text(encoding="utf-8"))
    if mainline_reset != stock_reset:
        raise SystemExit(
            f"reset sequence differs: stock={stock_reset} mainline={mainline_reset}"
        )

    data_headers = stock[:-2]
    if any(
        record["dtype"] != 0x39
        or record["last"] != 1
        or record["vc"] != 0
        or record["ack"] != 0
        or record["wait"] != 0
        for record in data_headers
    ):
        raise SystemExit("stock vendor command headers are not uniform DCS long-write packets")
    if [
        (record["dtype"], record["wait"], record["payload"])
        for record in stock[-2:]
    ] != [(0x05, 120, b"\x11\x00"), (0x05, 100, b"\x29\x00")]:
        raise SystemExit("stock sleep-out/display-on packet types or delays differ")
    if STOCK_STATE.read_bytes().rstrip(b"\0") != b"dsi_lp_mode":
        raise SystemExit("stock on-command state is not DSI low-power mode")

    removed_auto = sum(
        bool(re.match(r"^-\s+mipi_dsi_dual_dcs_write_seq_multi", line))
        for line in transport.splitlines()
    )
    added_long = sum(
        bool(re.match(r"^\+\s+tb371fc_dsi_dual_dcs_long_write_seq_multi", line))
        for line in transport.splitlines()
    )
    if "MIPI_DSI_DCS_LONG_WRITE" not in transport or removed_auto != added_long:
        raise SystemExit(
            f"mainline transport conversion is incomplete: removed={removed_auto} "
            f"added={added_long}"
        )
    if added_long < len(data_headers):
        raise SystemExit(
            f"mainline has only {added_long} forced long writes for "
            f"{len(data_headers)} active stock data commands"
        )
    print(
        f"Verified {len(stock)} Tianma commands ({len(stock) - 2} data commands "
        f"byte-for-byte as LP DCS long writes; DCS short sleep/display with "
        f"120/100-ms waits; "
        f"{STOCK.stat().st_size} packed stock bytes) and reset {stock_reset}."
    )


if __name__ == "__main__":
    main()
