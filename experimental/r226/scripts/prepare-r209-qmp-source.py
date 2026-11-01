#!/usr/bin/env python3
"""Mechanical isolated port: matched QMP driver + stock TB371FC USB init tables."""
import pathlib
import re
import subprocess
import sys

source_dir = pathlib.Path('/root/tb371fc/linux-6.12.114-r200/drivers/phy/qualcomm')
src = (source_dir / 'phy-qcom-qmp-combo.c').read_text()
defines = {}
for path in source_dir.glob('phy-qcom-qmp*.h'):
    for name, value in re.findall(r'^#define\s+(\w+)\s+(0x[0-9a-fA-F]+|\d+)\s*$', path.read_text(), re.M):
        defines[name] = int(value, 0)
dtb = '/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo/diagnostics/r202-android-venus-camera/tb371fc-venus/static/running-fdt.dtb'
nums = [int(x, 16) for x in subprocess.check_output(['fdtget', '-t', 'x', dtb, '/soc/ssphy@88e8000', 'qcom,qmp-phy-init-seq'], text=True).split()]
stock = {nums[i]: nums[i+1] for i in range(0, len(nums), 3) if nums[i] != 0xffffffff}
changes = []
for table, base in [('sm8250_usb3_tx_tbl', 0x1200), ('sm8250_usb3_rx_tbl', 0x1400)]:
    pattern = r'(static const struct qmp_phy_init_tbl ' + table + r'\[\] = \{)(.*?)(\n\};)'
    match = re.search(pattern, src, re.S)
    assert match
    body = match[2]
    seen = set()
    def entry(m):
        macro, reg, old, lane = m.groups()
        offset = base + defines[reg] + (0x400 if lane == '2' else 0)
        seen.add(offset)
        if not lane:
            seen.add(offset + 0x400)
            if stock[offset] != stock[offset+0x400]:
                changes.append(f'{offset:04x}/{offset+0x400:04x} {reg} split lanes: {stock[offset]:02x}/{stock[offset+0x400]:02x}')
                return (f'QMP_PHY_INIT_CFG_LANE({reg}, 0x{stock[offset]:02x}, 1),\n\t'
                        f'QMP_PHY_INIT_CFG_LANE({reg}, 0x{stock[offset+0x400]:02x}, 2)')
        val = stock[offset]
        if val != int(old, 0): changes.append(f'{offset:04x} {reg} {old}->{val:02x}')
        return f'{macro}({reg}, 0x{val:02x}' + (f', {lane}' if lane else '') + ')'
    body = re.sub(r'(QMP_PHY_INIT_CFG(?:_LANE)?)\((\w+),\s*(0x[0-9a-fA-F]+|\d+)(?:,\s*(\d+))?\)', entry, body)
    missing = sorted(o for o in stock if base <= o < base+0x200 and o not in seen)
    extra = ''
    for o in missing:
        assert stock[o] == stock[o+0x400]
        changes.append(f'{o:04x}/{o+0x400:04x} stock-only={stock[o]:02x}')
        extra += f'\n\tQMP_PHY_INIT_CFG(0x{o-base:03x}, 0x{stock[o]:02x}), /* R209 stock offset{o:04x} */'
    src = src[:match.start()] + match[1] + extra + body + match[3] + src[match.end():]

anchor = 'static struct platform_driver qmp_combo_driver = {'
assert src.count(anchor) == 1
wrapper = '''static int r209_probe(struct platform_device *pdev)
{
 struct device_node *chosen = of_find_node_by_path("/chosen");
 bool allowed = chosen && of_property_match_string(chosen,
  "tb371fc,experiment", "r207-ps5169-usb3") >= 0;
 of_node_put(chosen);
 if (!allowed || !of_device_is_compatible(pdev->dev.of_node,
     "qcom,sm8250-qmp-usb3-dp-phy")) return -EPERM;
 dev_info(&pdev->dev, "R209 stock TB371FC USB PHY table candidate\\n");
 return qmp_combo_probe(pdev);
}

'''
src = src.replace(anchor, wrapper + anchor)
src = src.replace('.probe\t\t= qmp_combo_probe,', '.probe\t\t= r209_probe,')
src = src.replace('.name\t= "qcom-qmp-combo-phy",', '.name\t= "r209-qmp-combo-phy",')
assert 'r209_probe,' in src and '"r209-qmp-combo-phy"' in src
dest = pathlib.Path(sys.argv[1])
(dest / 'r209-qmp.c').write_text(src)
(dest / 'stock-table-changes.txt').write_text('\n'.join(changes) + '\n')
print('\n'.join(changes))
