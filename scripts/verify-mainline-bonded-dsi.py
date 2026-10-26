#!/usr/bin/env python3
"""Verify the TB371FC bonded dual-DSI/DSC contract without hardware access."""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess


DISPLAY_WIDTH = 2944
DISPLAY_HEIGHT = 1840
LINK_WIDTH = DISPLAY_WIDTH // 2
SLICE_WIDTH = 736
SLICES_PER_LINK = 2

MDSS = "/soc@0/display-subsystem@ae00000"
DSI0 = f"{MDSS}/dsi@ae94000"
DSI1 = f"{MDSS}/dsi@ae96000"
PANEL = f"{DSI0}/panel@0"
DSI0_OUT = f"{DSI0}/ports/port@1/endpoint"
DSI1_OUT = f"{DSI1}/ports/port@1/endpoint"
PANEL_IN0 = f"{PANEL}/ports/port@0/endpoint"
PANEL_IN1 = f"{PANEL}/ports/port@1/endpoint"


def require(pattern: str, text: str, description: str) -> None:
    if not re.search(pattern, text, re.MULTILINE | re.DOTALL):
        raise SystemExit(f"missing {description}")


def fdtget(dtb: pathlib.Path, node: str, prop: str, value_type: str = "x") -> list[str]:
    result = subprocess.run(
        ["fdtget", "-t", value_type, str(dtb), node, prop],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        raise SystemExit(
            f"missing DT property {node}:{prop}: {result.stderr.strip()}"
        )
    return result.stdout.split()


def has_property(dtb: pathlib.Path, node: str, prop: str) -> bool:
    result = subprocess.run(
        ["fdtget", str(dtb), node, prop],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def expect_words(
    dtb: pathlib.Path,
    node: str,
    prop: str,
    expected: list[str],
    value_type: str = "x",
) -> None:
    actual = fdtget(dtb, node, prop, value_type)
    if actual != expected:
        raise SystemExit(
            f"unexpected DT property {node}:{prop}: expected {expected}, got {actual}"
        )


def expect_reciprocal_endpoints(
    dtb: pathlib.Path, left: str, right: str, description: str
) -> None:
    left_remote = fdtget(dtb, left, "remote-endpoint")
    right_handle = fdtget(dtb, right, "phandle")
    right_remote = fdtget(dtb, right, "remote-endpoint")
    left_handle = fdtget(dtb, left, "phandle")
    if left_remote != right_handle or right_remote != left_handle:
        raise SystemExit(f"non-reciprocal {description} graph endpoints")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kernel-dir", type=pathlib.Path, required=True)
    parser.add_argument("--out-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()

    manager = (
        args.kernel_dir / "drivers/gpu/drm/msm/dsi/dsi_manager.c"
    ).read_text(encoding="utf-8")
    host = (
        args.kernel_dir / "drivers/gpu/drm/msm/dsi/dsi_host.c"
    ).read_text(encoding="utf-8")
    encoder = (
        args.kernel_dir / "drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
    ).read_text(encoding="utf-8")
    panel = (
        args.kernel_dir / "drivers/gpu/drm/panel/panel-novatek-nt36523.c"
    ).read_text(encoding="utf-8")

    dtb = (
        args.out_dir
        / "arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-display-test.dtb"
    )
    vmlinux = args.out_dir / "vmlinux"
    if not dtb.is_file() or not vmlinux.is_file():
        raise SystemExit("compiled display-test DTB or vmlinux is missing")

    # One panel command is prepared for both hosts and triggered by DSI1.
    require(
        r"if\s*\(need_sync\s*&&\s*\(id\s*==\s*DSI_0\)\)\s*"
        r"return\s+is_read\s*\?\s*msg->rx_len\s*:\s*msg->tx_len;",
        manager,
        "DSI0 synchronized-transfer deferral",
    )
    require(
        r"if\s*\(IS_SYNC_NEEDED\(\)\s*&&\s*msm_dsi0\)\s*"
        r"msm_dsi_host_cmd_xfer_commit\(msm_dsi0->host,\s*dma_base,\s*len\);"
        r".*?msm_dsi_host_cmd_xfer_commit\(host,\s*dma_base,\s*len\);",
        manager,
        "simultaneous DSI0/DSI1 command trigger",
    )

    # Each link receives half the horizontal timing while DSC keeps full-panel geometry.
    require(
        r"if\s*\(is_bonded_dsi\)\s*\{.*?h_total\s*/=\s*2;.*?"
        r"hs_end\s*/=\s*2;.*?ha_start\s*/=\s*2;.*?ha_end\s*/=\s*2;.*?"
        r"hdisplay\s*/=\s*2;.*?\}",
        host,
        "per-link bonded DSI timing split",
    )
    require(
        r"dsc->pic_width\s*=\s*mode->hdisplay;.*?"
        r"dsc->pic_height\s*=\s*mode->vdisplay;",
        host,
        "full-mode DSC picture geometry",
    )
    require(
        r"this_frame_slices\s*=\s*pic_width\s*/\s*dsc->slice_width;.*?"
        r"enc_ip_w\s*=\s*intf_ip_w\s*/\s*num_dsc;",
        encoder,
        "DPU per-DSC encoder-width split",
    )

    panel_contract = {
        r"\.hdisplay\s*=\s*1472\s*\*\s*2": "2944-pixel mode width",
        r"\.vdisplay\s*=\s*1840": "1840-pixel mode height",
        r"\.pic_width\s*=\s*2944": "2944-pixel DSC picture width",
        r"\.pic_height\s*=\s*1840": "1840-pixel DSC picture height",
        r"\.slice_width\s*=\s*736": "736-pixel DSC slice width",
        r"\.slice_height\s*=\s*20": "20-line DSC slice height",
        r"\.slice_count\s*=\s*2": "two DSC slices per link",
        r"\.is_dual_dsi\s*=\s*true": "dual-DSI panel descriptor",
        r"of_graph_get_remote_node\(dsi->dev\.of_node,\s*1,\s*-1\)":
            "secondary DSI graph lookup",
        r"devm_mipi_dsi_attach\(dev,\s*pinfo->dsi\[i\]\)":
            "attachment of both DSI devices",
    }
    for pattern, description in panel_contract.items():
        require(pattern, panel, description)

    if DISPLAY_WIDTH != 2 * LINK_WIDTH:
        raise SystemExit("display width is not evenly split across two DSI links")
    if LINK_WIDTH != SLICE_WIDTH * SLICES_PER_LINK:
        raise SystemExit("DSC slices do not exactly fill one DSI link")

    for node in (DSI0, DSI1):
        expect_words(dtb, node, "status", ["okay"], "s")
        if not has_property(dtb, node, "qcom,dual-dsi-mode"):
            raise SystemExit(f"{node} lacks qcom,dual-dsi-mode")
        if not has_property(dtb, node, "qcom,sync-dual-dsi"):
            raise SystemExit(f"{node} lacks qcom,sync-dual-dsi")

    if not has_property(dtb, DSI0, "qcom,master-dsi"):
        raise SystemExit("DSI0 is not marked as the bonded master")
    if has_property(dtb, DSI1, "qcom,master-dsi"):
        raise SystemExit("DSI1 is incorrectly marked as a second master")

    expect_words(dtb, DSI0_OUT, "data-lanes", ["0", "1", "2", "3"])
    expect_words(dtb, DSI1_OUT, "data-lanes", ["0", "1", "2", "3"])
    if len(fdtget(dtb, DSI1, "assigned-clock-parents")) != 4:
        raise SystemExit("DSI1 does not inherit both byte/pixel PLL parents from DSI0")

    expect_words(dtb, PANEL, "status", ["okay"], "s")
    compatible = fdtget(dtb, PANEL, "compatible", "s")
    if compatible[:2] != ["lenovo,tb371fc-tianma-nt36532", "novatek,nt36523"]:
        raise SystemExit(f"unexpected panel compatible: {compatible}")
    expect_reciprocal_endpoints(dtb, DSI0_OUT, PANEL_IN0, "DSI0-to-panel")
    expect_reciprocal_endpoints(dtb, DSI1_OUT, PANEL_IN1, "DSI1-to-panel")

    strings = subprocess.check_output(["strings", str(vmlinux)], text=True)
    if "lenovo,tb371fc-tianma-nt36532" not in strings:
        raise SystemExit("linked vmlinux lacks the TB371FC Tianma panel match")

    print("TB371FC bonded dual-DSI/DSC contract verified (offline):")
    print("  topology:     one physical panel, DSI0 master + synchronized DSI1")
    print(f"  panel:        {DISPLAY_WIDTH}x{DISPLAY_HEIGHT}")
    print(f"  link width:   {LINK_WIDTH} + {LINK_WIDTH}")
    print(
        f"  DSC slices:   {SLICES_PER_LINK} x {SLICE_WIDTH} per link "
        f"({SLICES_PER_LINK * 2} total)"
    )
    print("  command path: DSI0 defers; DSI1 commits both hosts once")


if __name__ == "__main__":
    main()
