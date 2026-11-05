"""Private-copy PD RX startup variant; based on matched vendor pd_phy_open."""
from pathlib import Path
import sys
p = Path(sys.argv[1])
assert p.parent.name.startswith('r239-pd-receiver.')
s = p.read_text()
def once(old, new):
    global s
    assert s.count(old) == 1, old[:100]
    s = s.replace(old, new)
once('MSG_CONFIG_SPEC_REV_MASK, PD_REV20);',
     'MSG_CONFIG_SPEC_REV_MASK | MSG_CONFIG_PORT_DATA_ROLE |\n'
     '\t\t\t\t MSG_CONFIG_PORT_POWER_ROLE, PD_REV20);')
# Scope the enable() callsite, not reset_work(): leave genuine resets untouched.
a = s.index('static int qcom_pmic_typec_pdphy_enable(')
b = s.index('static int qcom_pmic_typec_pdphy_disable(', a)
part = s[a:b]
anchor = '\tqcom_pmic_typec_pdphy_reset_off(pmic_typec_pdphy);'
assert part.count(anchor) == 1
part = part.replace(anchor, '''
    /* Match vendor pd_phy_open: HW owns the initial RX buffer BEFORE IRQs. */
    ret = regmap_write(pmic_typec_pdphy->regmap,
                       pmic_typec_pdphy->base + USB_PDPHY_RX_ACKNOWLEDGE_REG, 0);
    if (ret) {
        goto done;
    }
''' + anchor)
s = s[:a] + part + s[b:]
diag = '''/* Read-only diagnostics: no FIFO read, ACK, clear or policy changes. */
static void r239_rx_snapshot(struct pmic_typec_pdphy *phy, const char *event)
{
    unsigned int role = 0, ack = 0, filter = 0, status = 0;
    int ret;
    ret = regmap_read(phy->regmap, phy->base + USB_PDPHY_MSG_CONFIG_REG, &role);
    ret = ret ?: regmap_read(phy->regmap, phy->base + USB_PDPHY_RX_ACKNOWLEDGE_REG, &ack);
    ret = ret ?: regmap_read(phy->regmap, phy->base + USB_PDPHY_FRAME_FILTER_REG, &filter);
    ret = ret ?: regmap_read(phy->regmap, phy->base + USB_PDPHY_RX_STATUS_REG, &status);
    dev_info_ratelimited(phy->dev, "R239 %s role=%02x ack=%02x filter=%02x rxstatus=%02x rc=%d\\n",
                         event, role, ack, filter, status, ret);
}

'''
once('static irqreturn_t qcom_pmic_typec_pdphy_isr(',
     diag + 'static irqreturn_t qcom_pmic_typec_pdphy_isr(')
once('\tcase PMIC_PDPHY_SIG_RX_IRQ:\n',
     '\tcase PMIC_PDPHY_SIG_RX_IRQ:\n\t\tr239_rx_snapshot(pmic_typec_pdphy, "signal-rx");\n')
once('\tcase PMIC_PDPHY_MSG_RX_IRQ:\n',
     '\tcase PMIC_PDPHY_MSG_RX_IRQ:\n\t\tr239_rx_snapshot(pmic_typec_pdphy, "message-rx");\n')
once('\tcase PMIC_PDPHY_MSG_TX_DISCARD_IRQ:\n',
     '\tcase PMIC_PDPHY_MSG_RX_DISCARD_IRQ:\n'
     '\t\tr239_rx_snapshot(pmic_typec_pdphy, "message-discard");\n\t\tbreak;\n'
     '\tcase PMIC_PDPHY_MSG_TX_DISCARD_IRQ:\n')
once('\tfor (i = 0; i < pmic_typec_pdphy->nr_irqs; i++)\n\t\tenable_irq',
     '\tr239_rx_snapshot(pmic_typec_pdphy, "before-irqs");\n'
     '\tfor (i = 0; i < pmic_typec_pdphy->nr_irqs; i++)\n\t\tenable_irq')
p.write_text(s)
print('R239 startup sink/GoodCRC + initial HW RX ownership + read-only IRQ diagnostics prepared')
