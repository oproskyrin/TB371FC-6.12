#!/usr/bin/env python3
"""Verify TB371FC mode timing and derived dual-DSI bit clock against stock."""

from pathlib import Path


PROJECT = Path(__file__).resolve().parent.parent
PANEL = (
    PROJECT
    / "diagnostics/v24-live-panel-dt"
    / "qcom,mdss_dsi_panel_spinel_tianma_nt36532_dsc_3k_video"
)
TIMING = PANEL / "qcom,mdss-dsi-display-timings/timing@0"
PATCHES = (
    PROJECT / "mainline-port/patches/0001-drm-panel-nt36523-add-lenovo-tb371fc-nt36532.patch",
    PROJECT / "mainline-port/patches/0007-drm-panel-tb371fc-send-dual-dsi-dsc-pps.patch",
)


def u32(path: Path) -> int:
    data = path.read_bytes()
    if len(data) != 4:
        raise ValueError(f"expected one big-endian u32 in {path}, got {len(data)} bytes")
    return int.from_bytes(data, "big")


def main() -> int:
    stock = {
        "width": u32(TIMING / "qcom,mdss-dsi-panel-width"),
        "height": u32(TIMING / "qcom,mdss-dsi-panel-height"),
        "hfp": u32(TIMING / "qcom,mdss-dsi-h-front-porch"),
        "hsa": u32(TIMING / "qcom,mdss-dsi-h-pulse-width"),
        "hbp": u32(TIMING / "qcom,mdss-dsi-h-back-porch"),
        "vfp": u32(TIMING / "qcom,mdss-dsi-v-front-porch"),
        "vsa": u32(TIMING / "qcom,mdss-dsi-v-pulse-width"),
        "vbp": u32(TIMING / "qcom,mdss-dsi-v-back-porch"),
        "refresh": u32(TIMING / "qcom,mdss-dsi-panel-framerate"),
        "bit_clock": u32(TIMING / "qcom,mdss-dsi-panel-clockrate"),
    }
    expected = {
        "width": 1472,
        "height": 1840,
        "hfp": 201,
        "hsa": 12,
        "hbp": 60,
        "vfp": 26,
        "vsa": 2,
        "vbp": 182,
        "refresh": 120,
    }
    for name, value in expected.items():
        if stock[name] != value:
            raise SystemExit(f"stock {name} changed: expected {value}, got {stock[name]}")

    patch = "\n".join(path.read_text(encoding="utf-8") for path in PATCHES)
    required_source = (
        "(1472 + 201 + 12 + 60) * 2",
        "(1840 + (_vfp) + 2 + 182)",
        "TB371FC_MODE(120, 26)",
        ".slice_width = 736",
        ".slice_count = 2",
        ".bits_per_pixel = 8 << 4",
    )
    for snippet in required_source:
        if snippet not in patch:
            raise SystemExit(f"mainline timing contract missing: {snippet}")

    full_width = stock["width"] * 2
    htotal = (stock["width"] + stock["hfp"] + stock["hsa"] + stock["hbp"]) * 2
    vtotal = stock["height"] + stock["vfp"] + stock["vsa"] + stock["vbp"]
    mode_clock = htotal * vtotal * stock["refresh"]

    # Linux dsi_adjust_pclk_for_compression(), dsi_get_pclk_rate() and
    # dsi_byte_clk_get_rate() for RGB888, four lanes and bonded dual DSI.
    compressed_half = (stock["width"] * 8 + 24 - 1) // 24
    compressed_full = compressed_half * 2
    adjusted_htotal = htotal - full_width + compressed_full
    adjusted_pclk = mode_clock * adjusted_htotal // htotal
    per_link_pclk = adjusted_pclk // 2
    byte_clock = per_link_pclk * 24 // (8 * 4)
    derived_bit_clock = byte_clock * 8
    error_ppm = abs(derived_bit_clock - stock["bit_clock"]) * 1_000_000 // stock["bit_clock"]
    if error_ppm > 5000:
        raise SystemExit(
            f"derived DSI bit clock {derived_bit_clock} differs from stock "
            f"{stock['bit_clock']} by {error_ppm} ppm"
        )

    print(
        "Verified TB371FC 2944x1840@120 timing and dual-DSI clock: "
        f"mainline={derived_bit_clock} stock={stock['bit_clock']} "
        f"difference={error_ppm} ppm."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
