#!/usr/bin/env python3
"""Verify the TB371FC panel/DSI ordering in an applied Linux source tree."""

from pathlib import Path
import argparse


def ordered(text: str, needles: list[str], label: str) -> None:
    cursor = 0
    for needle in needles:
        index = text.find(needle, cursor)
        if index < 0:
            raise SystemExit(f"{label}: missing or out-of-order token: {needle}")
        cursor = index + len(needle)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("kernel_dir", type=Path)
    args = parser.parse_args()

    panel_path = (
        args.kernel_dir
        / "drivers/gpu/drm/panel/panel-novatek-nt36523.c"
    )
    host_path = args.kernel_dir / "drivers/gpu/drm/msm/dsi/dsi_host.c"
    bridge_path = args.kernel_dir / "drivers/gpu/drm/bridge/panel.c"
    panel = panel_path.read_text(encoding="utf-8")
    host = host_path.read_text(encoding="utf-8")
    bridge = bridge_path.read_text(encoding="utf-8")

    start = panel.index("static int tb371fc_nt36532_init_sequence")
    end = panel.index("static int tb371fc_boe_init_sequence", start)
    init = panel[start:end]

    ordered(
        init,
        [
            "TB371FC DSC parameters were not populated before prepare",
            "tb371fc_dsi_dual_dcs_long_write_seq_multi(&dsi_ctx, dsi0, dsi1, 0xff, 0x20)",
            "tb371fc_dsi_dual_dcs_long_write_seq_multi(&dsi_ctx, dsi0, dsi1, 0x55, 0x01)",
            "drm_dsc_pps_payload_pack",
            "mipi_dsi_picture_parameter_set_multi",
            "MIPI_DCS_EXIT_SLEEP_MODE",
            "mipi_dsi_msleep(&dsi_ctx, 120)",
            "MIPI_DCS_SET_DISPLAY_ON",
            "mipi_dsi_msleep(&dsi_ctx, 100)",
        ],
        "TB371FC panel sequence",
    )
    if "tb371fc_dsi_dual_dcs_long_write_seq_multi" in init[
        init.index("drm_dsc_pps_payload_pack") :
    ]:
        raise SystemExit("vendor long writes unexpectedly occur after PPS packing")

    for token in (
        ".type = MIPI_DSI_DCS_LONG_WRITE",
        "msg.flags |= MIPI_DSI_MSG_USE_LPM",
        "ret = ops->transfer(dsi->host, &msg)",
        '.dsi_info = { .type = "TB371FC-NT36532", .channel = 0',
        "MIPI_DSI_MODE_VIDEO_BURST | MIPI_DSI_MODE_LPM",
        "pinfo->panel.prepare_prev_first = true",
    ):
        if token not in panel:
            raise SystemExit(f"panel transport/lifecycle contract missing: {token}")
    helper = panel[
        panel.index("static void tb371fc_dsi_dcs_long_write_multi") :
        panel.index("static inline struct panel_info *to_panel_info")
    ]
    if "MIPI_DSI_MSG_REQ_ACK" in helper:
        raise SystemExit("TB371FC vendor writes unexpectedly request acknowledgements")

    ordered(
        host[host.index("int msm_dsi_host_power_on") :],
        ["dsi_timing_setup(msm_host, is_bonded_dsi)", "dsi_sw_reset(msm_host)", "dsi_ctrl_enable"],
        "MSM DSI host power-on",
    )
    if (
        "panel_bridge->bridge.pre_enable_prev_first = panel->prepare_prev_first"
        not in bridge
    ):
        raise SystemExit("DRM panel bridge does not propagate prepare_prev_first")

    print(
        "Verified host timing/DSC population before panel prepare and panel "
        "order: vendor LP long writes -> dual PPS -> sleep-out 120 ms -> "
        "display-on 100 ms."
    )


if __name__ == "__main__":
    main()
