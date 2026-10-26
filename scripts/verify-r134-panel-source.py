#!/usr/bin/env python3
"""Compare the actual 6.12 backport command/reset source with captured stock."""
from pathlib import Path
import importlib.util

project = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location(
    'stock_verify', project / 'scripts/verify-mainline-tianma-command-table.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
source = (project / 'mainline-port/backports/linux-6.12/panel-novatek-nt36523.c').read_text()
normalized = source.replace('tb371fc_dsi_dual_dcs_long_write_seq_multi',
                            'mipi_dsi_dual_dcs_write_seq_multi')
plus = '\n'.join('+' + line for line in normalized.splitlines())
stock = v.decode_stock(v.STOCK.read_bytes())
payloads = [r['payload'][:1] if r['payload'] in (b'\x11\x00', b'\x29\x00')
            else r['payload'] for r in stock]
assert v.decode_patch(plus) == payloads, 'Backport commands differ from stock'
assert v.decode_patch_reset(plus) == v.decode_stock_reset(v.STOCK_RESET.read_bytes())
for token in ('.type = MIPI_DSI_DCS_LONG_WRITE',
              'msg.flags |= MIPI_DSI_MSG_USE_LPM',
              '.slice_width = 736', '.slice_count = 2',
              '.bits_per_pixel = 8 << 4',
              'mipi_dsi_msleep(&dsi_ctx, 120)',
              'mipi_dsi_msleep(&dsi_ctx, 100)',
              'TB371FC DSC parameters were not populated before prepare',
              'pinfo->panel.prepare_prev_first = true'):
    assert token in source, token
assert 'devm_drm_panel_alloc' not in source
assert 'drm_panel_init(&pinfo->panel' in source
print(f'PASS: actual 6.12 source matches {len(stock)} stock Tianma payloads and reset; transport/DSC/order/API guards present')
