#!/usr/bin/env python3
from pathlib import Path
import subprocess

project = Path(__file__).resolve().parent.parent
pkg = Path('/mnt/d/TB371FC-builds/r139-panel-gates')
base = Path('/mnt/d/TB371FC-builds/r138-power-closure')
source = (pkg / 'r139_panel.c').read_text()
original = (project / 'mainline-port/backports/linux-6.12/panel-novatek-nt36523.c').read_text()
# All mode/reset/vendor/PPS/transport code before remove callback unchanged.
normalized = source.replace('#include <linux/pinctrl/consumer.h>\n', '')
assert normalized.split('static void nt36523_remove')[0] == original.split('static void nt36523_remove')[0]
probe = source.split('static int nt36523_probe')[1].split('static const struct of_device_id')[0]
assert probe.index('if (r139_stage == 0)') < probe.index('pinctrl_select_state')
assert probe.index('if (r139_stage == 1)') < probe.index('devm_regulator_get')
assert probe.index('if (r139_stage == 2)') < probe.index('devm_gpiod_get')
assert probe.index('if (r139_stage == 3)') < probe.index('gpiod_direction_output')
assert probe.index('if (r139_stage == 4)') < probe.index('devm_mipi_dsi_device_register_full')
assert probe.index('if (r139_stage == 5)') < probe.index('\tdrm_panel_add(&pinfo->panel);')
assert 'GPIOD_ASIS' in probe and 'GPIOD_OUT_HIGH' not in probe
assert 'module_param_named(probe_stage, r139_stage, uint, 0644)' in source
assert 'msleep(250)' in source
assert 'drm_panel_remove' not in source.split('static void nt36523_remove')[1].split('static int nt36523_get_modes')[0]
assert (pkg / 'Image').read_bytes() == (base / 'Image').read_bytes()
status = subprocess.check_output(['fdtget', '-t', 's', str(pkg/'board.dtb'), '/soc/display-subsystem@ae00000/dsi@ae94000/panel@0', 'pinctrl-names'], text=True).strip()
assert status == 'r139-display'
subprocess.run(['sha256sum', '-c', 'SHA256SUMS'], cwd=pkg, check=True)
print('PASS: original panel commands/PPS/reset/modes untouched; diagnostic gates ordered; stage0 before IO; no automatic default pin state')
