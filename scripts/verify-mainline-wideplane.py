#!/usr/bin/env python3
"""Verify the TB371FC Linux 7 wide-plane contract without touching hardware."""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess


DISPLAY_WIDTH = 2944
TB371FC_MAX_LINEWIDTH = 0x758


def require(pattern: str, text: str, description: str) -> None:
    if not re.search(pattern, text, re.MULTILINE | re.DOTALL):
        raise SystemExit(f"missing {description}")


def output(*command: str) -> str:
    return subprocess.check_output(command, text=True).strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kernel-dir", type=pathlib.Path, required=True)
    parser.add_argument("--out-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()

    catalog = (args.kernel_dir / "drivers/gpu/drm/msm/disp/dpu1/catalog/dpu_6_0_sm8250.h").read_text()
    kms = (args.kernel_dir / "drivers/gpu/drm/msm/disp/dpu1/dpu_kms.c").read_text()
    plane = (args.kernel_dir / "drivers/gpu/drm/msm/disp/dpu1/dpu_plane.c").read_text()
    dtb = args.out_dir / "arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-display-test.dtb"
    vmlinux = args.out_dir / "vmlinux"

    require(r"tb371fc_dpu_caps\s*=\s*\{.*?\.max_linewidth\s*=\s*1880,", catalog,
            "TB371FC 1880-pixel DPU catalog limit")
    require(r"bool\s+dpu_use_virtual_planes\s*=\s*true;", kms,
            "default virtual-plane resource allocation")
    require(r'\.compatible\s*=\s*"lenovo,tb371fc-dpu".*?&dpu_tb371fc_cfg', kms,
            "TB371FC DPU compatible match")
    require(r"drm_rect_width\(&pipe_cfg->src_rect\)\s*>\s*max_linewidth", plane,
            "wide-source split condition")
    require(r"r_pipe->sspp\s*=\s*dpu_rm_reserve_sspp", plane,
            "second SSPP reservation")

    compatible = output(
        "fdtget", "-t", "s", str(dtb),
        "/soc@0/display-subsystem@ae00000/display-controller@ae01000", "compatible"
    )
    if compatible != "lenovo,tb371fc-dpu":
        raise SystemExit(f"unexpected display-controller compatible: {compatible}")

    symbols = output("aarch64-linux-gnu-nm", str(vmlinux))
    if not re.search(r"\bD\s+dpu_tb371fc_cfg$", symbols, re.MULTILINE):
        raise SystemExit("linked vmlinux lacks dpu_tb371fc_cfg")

    if not DISPLAY_WIDTH > TB371FC_MAX_LINEWIDTH:
        raise SystemExit("display width would not trigger a split")
    left = DISPLAY_WIDTH // 2
    right = DISPLAY_WIDTH - left
    if max(left, right) > TB371FC_MAX_LINEWIDTH:
        raise SystemExit("split rectangles still exceed one SSPP")

    print("TB371FC wide-plane contract verified (offline):")
    print(f"  source width: {DISPLAY_WIDTH}")
    print(f"  SSPP limit:   {TB371FC_MAX_LINEWIDTH}")
    print(f"  split:        {left} + {right}")
    print("  resources:    virtual-plane path with second SSPP reservation")
    print("  DT compatible: lenovo,tb371fc-dpu")


if __name__ == "__main__":
    main()

