"""R180: panel-novatek-nt36523 'keep_splash' parameter: leave the panel as the bootloader initialised
it (no reset GPIO toggling at probe/prepare/unprepare, no init sequence, no display off/sleep)."""
import sys, re
p = sys.argv[1]; s = open(p).read()
def rep(a, b, cnt=1):
    global s
    assert s.count(a) == cnt, (a, s.count(a))
    s = s.replace(a, b)
rep('static int nt36523_prepare(struct drm_panel *panel)\n{\n\tstruct panel_info *pinfo = to_panel_info(panel);\n\tint ret;\n',
    'static bool keep_splash;\nmodule_param(keep_splash, bool, 0644);\nMODULE_PARM_DESC(keep_splash, "TB371FC: keep the bootloader-initialised panel (no reset, no init sequence)");\n\n'
    'static int nt36523_prepare(struct drm_panel *panel)\n{\n\tstruct panel_info *pinfo = to_panel_info(panel);\n\tint ret;\n\n\tif (keep_splash) {\n\t\tdev_info(panel->dev, "TB371FC keep_splash: panel left as initialised by the bootloader\\n");\n\t\treturn 0;\n\t}\n')
rep('static int nt36523_disable(struct drm_panel *panel)\n{\n\tstruct panel_info *pinfo = to_panel_info(panel);\n\tint i;\n',
    'static int nt36523_disable(struct drm_panel *panel)\n{\n\tstruct panel_info *pinfo = to_panel_info(panel);\n\tint i;\n\n\tif (keep_splash)\n\t\treturn 0;\n')
rep('static int nt36523_unprepare(struct drm_panel *panel)\n{\n\tstruct panel_info *pinfo = to_panel_info(panel);\n',
    'static int nt36523_unprepare(struct drm_panel *panel)\n{\n\tstruct panel_info *pinfo = to_panel_info(panel);\n\n\tif (keep_splash)\n\t\treturn 0;\n')
m = re.search(r'pinfo->reset_gpio = devm_gpiod_get\(dev, "reset", (GPIOD_[A-Z_]+)\)', s)
print('reset flag at probe:', m.group(1) if m else None)
if m:
    s = s.replace(m.group(0), 'pinfo->reset_gpio = devm_gpiod_get(dev, "reset", keep_splash ? GPIOD_ASIS : %s)' % m.group(1))
open(p, 'w').write(s)
print('keep_splash patch applied')

# R182: TB371FC NT36532 DSI mode like the vendor (non-burst sync events) and Xiaomi pipa mainline:
# video mode with non-continuous clock, no burst.
old = '.mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_BURST | MIPI_DSI_MODE_LPM,'
if s.count(old) == 1:
    s = s.replace(old, '.mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_CLOCK_NON_CONTINUOUS | MIPI_DSI_MODE_LPM,')
    open(p, 'w').write(s)
    print('R182 tb371fc mode_flags: non-burst, non-continuous clock')
else:
    print('R182 mode_flags pattern count', s.count(old))
