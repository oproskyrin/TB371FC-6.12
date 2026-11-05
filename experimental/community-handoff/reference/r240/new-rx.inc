// SPDX-License-Identifier: GPL-2.0-only
static void qcom_pmic_typec_pdphy_pd_receive(struct pmic_typec_pdphy *phy)
{
    struct device *dev = phy->dev;
    struct pd_message msg = {0};
    unsigned int size = 0xff, status = 0xff;
    unsigned long flags;
    int ret, ack_ret;
    spin_lock_irqsave(&phy->lock, flags);
    ret = regmap_read(phy->regmap, phy->base + USB_PDPHY_RX_SIZE_REG, &size);
    if (ret)
        goto release_buffer;
    if (size < 1 || size > sizeof(msg) - 1) {
        ret = -EMSGSIZE;
        goto release_buffer;
    }
    ret = regmap_read(phy->regmap, phy->base + USB_PDPHY_RX_STATUS_REG, &status);
    if (ret)
        goto release_buffer;
    if ((status & RX_FRAME_TYPE) != TCPC_TX_SOP) {
        ret = -EOPNOTSUPP;
        goto release_buffer;
    }
    ret = regmap_bulk_read(phy->regmap, phy->base + USB_PDPHY_RX_BUFFER_REG,
                           (u8 *)&msg, size + 1);
    if (ret)
        goto release_buffer;
    if (size + 1 != sizeof(msg.header) + 4 * pd_header_cnt_le(msg.header))
        ret = -EMSGSIZE;
release_buffer:
    /* An RX IRQ transfers ownership to host. Always attempt to return it,
     * including invalid-size and I/O-error paths; never deliver a failed read. */
    ack_ret = regmap_write(phy->regmap, phy->base + USB_PDPHY_RX_ACKNOWLEDGE_REG, 0);
    spin_unlock_irqrestore(&phy->lock, flags);
    dev_info_ratelimited(dev, "R240 RX raw-size=%u status=%02x ret=%d ack-ret=%d\n",
                         size, status, ret, ack_ret);
    if (!ret && !ack_ret)
        tcpm_pd_receive(phy->tcpm_port, &msg, TCPC_TX_SOP);
}
