"""Replace only RX handler in a PRIVATE R239-derived source; export exact tests."""
from pathlib import Path
import sys
p = Path(sys.argv[1])
assert p.parent.name.startswith('r240-rx-cleanup.')
s = p.read_text()
start = s.index('static void qcom_pmic_typec_pdphy_pd_receive(')
brace = s.index('{', start)
pos, level = brace + 1, 1
while level:
    if s[pos] == '{': level += 1
    elif s[pos] == '}': level -= 1
    pos += 1
old = s[start:pos]
new = Path(__file__).with_name('receive.inc').read_text()
(p.parent/'old-rx.inc').write_text(old+'\n')
(p.parent/'new-rx.inc').write_text(new)
s = s[:start] + new + s[pos:]
anchor = '\tdev_dbg(pmic_typec_pdphy->dev, "set_pd_rx: %s\\n", str_on_off(on));'
assert s.count(anchor) == 1
s = s.replace(anchor, '\tdev_info_ratelimited(pmic_typec_pdphy->dev, "R240 set_pd_rx on=%d ret=%d\\n", on, ret);')
p.write_text(s)
