"""Mechanical, fail-closed transformation of a PRIVATE source copy only.

Compile prototype, NOT ready for installation: SMB5 sink-current coordination
and watchdog ownership handover remain required before a hardware test.
"""
from pathlib import Path
import re
import sys

work = Path(sys.argv[1]).resolve()
assert work.name.startswith("r233-sink-test.")


def replace_once(text, old, new):
    assert text.count(old) == 1, old[:90]
    return text.replace(old, new)


def function(text, name, body):
    pattern = rf"(static int {name}\([^{{]+\{{)"
    match = re.search(pattern, text)
    assert match, name
    level, pos = 1, match.end()
    while level:
        if text[pos] == "{":
            level += 1
        elif text[pos] == "}":
            level -= 1
        pos += 1
    return text[:match.end()] + "\n" + body + "\n}" + text[pos:]


p = work / "qcom_pmic_typec_port.c"
text = p.read_text()
# Leave the original source-VBUS routines out entirely, not merely unreachable.
begin = text.index("static int qcom_pmic_typec_port_vbus_toggle(")
end = text.index("static int qcom_pmic_typec_port_get_vbus(", begin)
text = text[:begin] + text[end:]
text = function(text, "qcom_pmic_typec_port_set_vbus", """
    /* Sink-only prototype. No regulator access, no VBUS sourcing. */
    return on ? -EPERM : 0;
""")
text = function(text, "qcom_pmic_typec_port_set_cc", """
    struct pmic_typec *tcpm = tcpc_to_tcpm(tcpc);
    struct pmic_typec_port *port = tcpm->pmic_typec_port;
    int ret;
    if (cc != TYPEC_CC_RD && cc != TYPEC_CC_OPEN)
        return -EPERM;
    ret = regmap_write(port->regmap, port->base + TYPEC_MODE_CFG_REG,
                       cc == TYPEC_CC_RD ? EN_SNK_ONLY : TYPEC_DISABLE_CMD);
    if (!ret)
        port->cc = cc;
    return ret;
""")
text = function(text, "qcom_pmic_typec_port_start_toggling", """
    struct pmic_typec *tcpm = tcpc_to_tcpm(tcpc);
    struct pmic_typec_port *port = tcpm->pmic_typec_port;
    if (port_type != TYPEC_PORT_SNK || cc != TYPEC_CC_RD)
        return -EPERM;
    return regmap_write(port->regmap, port->base + TYPEC_MODE_CFG_REG,
                        EN_SNK_ONLY);
""")
text = replace_once(text, "TYPEC_MODE_CFG_REG, EN_TRY_SNK);",
                    "TYPEC_MODE_CFG_REG, EN_SNK_ONLY);")
text = replace_once(text, '/* start in TRY_SNK mode */',
                    '/* R233 prototype starts in strict sink-only mode. */')
text = replace_once(text, '''\tpmic_typec_port->vdd_vbus = devm_regulator_get(dev, "vdd-vbus");
\tif (IS_ERR(pmic_typec_port->vdd_vbus))
\t\treturn PTR_ERR(pmic_typec_port->vdd_vbus);
''', '/* R233: never acquire the source-VBUS regulator. */\n')
assert "regulator_enable(" not in text
assert "EN_TRY_SNK);" not in text
p.write_text(text)

p = work / "qcom_pmic_typec_pdphy.c"
text = p.read_text()
start = text.index("static int qcom_pmic_typec_pdphy_set_roles(")
point = text.index("\tspin_lock_irqsave(&pmic_typec_pdphy->lock, flags);", start)
text = text[:point] + '''    /* No PD header may claim source power role in this prototype. */
    if (power_role != TYPEC_SINK)
        return -EPERM;

''' + text[point:]
p.write_text(text)

p = work / "qcom_pmic_typec.c"
text = p.read_text()
text = replace_once(text, '\tres = of_device_get_match_data(dev);', '''
    /* Explicit opt-in prevents this prototype probing the production DT. */
    if (!of_property_read_bool(np, "tb371fc,r233-sink-only-test"))
        return -EPERM;
    {
        struct device_node *conn = of_get_child_by_name(np, "connector");
        const char *role;
        u32 pdo;
        int err = !conn ? -EINVAL : 0;
        if (!err)
            err = of_property_read_string(conn, "power-role", &role);
        if (!err && strcmp(role, "sink"))
            err = -EPERM;
        if (!err && of_find_property(conn, "source-pdos", NULL))
            err = -EPERM;
        if (!err && of_property_count_u32_elems(conn, "sink-pdos") != 1)
            err = -EPERM;
        if (!err)
            err = of_property_read_u32(conn, "sink-pdos", &pdo);
        /* Fixed 5V PDO, no power-role swap, maximum 1.5A. */
        if (!err && ((pdo >> 30) || (pdo & BIT(29)) ||
                     ((pdo >> 10) & 0x3ff) != 100 ||
                     !(pdo & 0x3ff) || (pdo & 0x3ff) > 150))
            err = -EPERM;
        of_node_put(conn);
        if (err)
            return err;
    }
\tres = of_device_get_match_data(dev);''')
p.write_text(text)
print("R233 private-copy sink guards prepared; DO NOT LOAD before integration")
