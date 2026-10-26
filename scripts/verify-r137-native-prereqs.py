#!/usr/bin/env python3
"""Check actual6.12 board-only PHY/catalog code; no hardware access."""
import argparse
import re
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('kernel', type=Path)
args = p.parse_args()
msm = args.kernel / 'drivers/gpu/drm/msm'
phy = (msm / 'dsi/phy/dsi_phy_7nm.c').read_text()
match = (msm / 'dsi/phy/dsi_phy.c').read_text()
catalog = (msm / 'disp/dpu1/catalog/dpu_6_0_sm8250.h').read_text()
plane = (msm / 'disp/dpu1/dpu_plane.c').read_text()
kms = (msm / 'disp/dpu1/dpu_kms.c').read_text()

def block(text, name):
    return re.search(r'\b' + re.escape(name) + r'\s*=\s*\{(.*?)\n\};', text, re.S).group(1)

board = block(phy, 'dsi_phy_7nm_tb371fc_cfgs')
assert 'DSI_PHY_7NM_QUIRK_V4_1' in board and 'DSI_PHY_7NM_QUIRK_PRE_V4_1' not in board
assert 'DSI_PHY_7NM_QUIRK_TB371FC_CLK_CFG0' in board
assert '.io_start = { 0xae94400, 0xae96400 }' in board
assert '.min_pll_rate = 600000000UL' in board
assert '.max_pll_rate = 5000000000ULL' in board
for assignment in ('vreg_ctrl_0 = 0x51;', 'glbl_rescode_top_ctrl = 0x3d;',
                   'glbl_rescode_bot_ctrl = 0x39;', 'glbl_str_swi_cal_sel_ctrl = 0x01;',
                   'glbl_hstx_str_ctrl_0 = 0xff;'):
    assert assignment in phy
assert '#define DSI_PHY_7NM_QUIRK_TB371FC_CLK_CFG0\tBIT(5)' in phy
assert 'DSI_PHY_7NM_QUIRK_V4_1' in block(phy, 'dsi_phy_7nm_cfgs')
assert re.search(r'i == 4 && \(phy->cfg->quirks &\s*DSI_PHY_7NM_QUIRK_TB371FC_CLK_CFG0\) \? 0x20 : 0x0', phy)
assert '{ 0x00, 0x00, 0x00, 0x04, 0x01 }' in phy
assert '"lenovo,tb371fc-dsi-phy-7nm"' in match

def fields(body):
    return dict(re.findall(r'\.(\w+)\s*=\s*([^\n]+),', body))

base_caps = fields(block(catalog, 'sm8250_dpu_caps'))
board_caps = fields(block(catalog, 'tb371fc_dpu_caps'))
assert base_caps['max_linewidth'] == '4096'
assert board_caps['max_linewidth'] == '1880'
base_caps['max_linewidth'] = '1880'
assert board_caps == base_caps, 'unexpected caps changes'
base_cfg = fields(block(catalog, 'dpu_sm8250_cfg'))
board_cfg = fields(block(catalog, 'dpu_tb371fc_cfg'))
base_cfg['caps'] = '&tb371fc_dpu_caps'
assert board_cfg == base_cfg, 'catalog resources changed'
assert '"lenovo,tb371fc-dpu", .data = &dpu_tb371fc_cfg' in kms
assert 'r_pipe->sspp = pipe->sspp;' in plane
assert 'DPU_SSPP_MULTIRECT_PARALLEL' in plane
assert 'DPU_SSPP_SMART_DMA_V1' in plane and 'DPU_SSPP_SMART_DMA_V2' in plane
assert 2944 > 1880 and 2944 // 2 == 1472 and 1472 <= 1880
print('PASS: isolated board PHY V4_1/clock CFG0=0x20, working V56 analog overrides, generic profile unchanged')
print('PASS: exact6.12 catalog; only linewidth differs4096->1880; 2944->1472+1472 linear multirect path')
print('NOT VERIFIED: actual native panel, clocks under load, GPIO/power and physical scanout')
