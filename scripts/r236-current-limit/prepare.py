"""Mechanical changes only to a fresh private R233-derived build directory."""
from pathlib import Path
import sys

work = Path(sys.argv[1]).resolve()
assert work.name.startswith("r233-sink-test.")
p = work / "qcom_pmic_typec_port.c"
s = p.read_text()

def once(old, new):
    global s
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)

once('struct pmic_typec_port {', '''struct pmic_typec_port {
    unsigned int r236_cap_ma;
    bool r236_owned_suspend;''')
once('static int qcom_pmic_typec_port_get_vbus(',
     '#include "callback.inc"\n\nstatic int qcom_pmic_typec_port_get_vbus(')
once('\tint i, ret, irq;', '\tint i, ret, irq;\n\tunsigned int inherited_icl;')
once('\tirq = platform_get_irq(pdev, 0);', '''
    /* Establish conservative 100mA before TCPM starts touching CC/PD. */
    ret = regmap_read(regmap, 0x1370, &inherited_icl);
    if (ret)
        return ret;
    pmic_typec_port->r236_cap_ma = min(inherited_icl * 50, 1500U);
    if (pmic_typec_port->r236_cap_ma < 100)
        return -EPERM;
    ret = r236_apply_icl(pmic_typec_port, 100, 5000);
    if (ret) {
        return ret;
    }
\tirq = platform_get_irq(pdev, 0);''')
once('\ttcpm->tcpc.get_vbus = qcom_pmic_typec_port_get_vbus;',
     '\ttcpm->tcpc.set_current_limit = r236_set_current_limit;\n'
     '\ttcpm->tcpc.get_vbus = qcom_pmic_typec_port_get_vbus;')
p.write_text(s)
# Separate marker: this callback must NEVER probe a plain R233 profile.
p = work / "qcom_pmic_typec.c"
s = p.read_text()
assert s.count('tb371fc,r233-sink-only-test') == 1
p.write_text(s.replace('tb371fc,r233-sink-only-test', 'tb371fc,r236-current-limit-test'))
