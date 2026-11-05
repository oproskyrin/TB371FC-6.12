/* SPDX-License-Identifier: GPL-2.0-only */
/* Exact handler, fake register I/O. No electrical/hardware claims. */
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <stdio.h>
typedef uint8_t u8;
struct device { int dummy; };
struct pd_message { uint16_t header; uint32_t payload[7]; } __attribute__((packed));
struct regmap { unsigned int size,status,objects,calls,fail_at,acks,delivered; };
struct pmic_typec_pdphy { struct device *dev; struct regmap *regmap; unsigned int base; int lock; struct regmap *tcpm_port; };
#define USB_PDPHY_RX_SIZE_REG 0x48
#define USB_PDPHY_RX_STATUS_REG 0x4a
#define USB_PDPHY_RX_BUFFER_REG 0x80
#define USB_PDPHY_RX_ACKNOWLEDGE_REG 0x4b
#define RX_FRAME_TYPE 7
#define TCPC_TX_SOP 0
#define spin_lock_irqsave(lock,flags) do { (void)(lock); (flags)=0; } while(0)
#define spin_unlock_irqrestore(lock,flags) do { (void)(lock); (void)(flags); } while(0)
#define dev_dbg(dev,...) do { (void)(dev); } while(0)
#define dev_vdbg(dev,...) do { (void)(dev); } while(0)
#define dev_info_ratelimited(dev,...) do { (void)(dev); } while(0)
#ifndef OLD_BEHAVIOR
static unsigned int pd_header_cnt_le(uint16_t h) { return (h>>12)&7; }
#endif
static int fail(struct regmap *m) { return ++m->calls == m->fail_at; }
static int regmap_read(struct regmap *m,unsigned int r,unsigned int *v)
{
    if (fail(m)) return -EIO;
    *v = r == USB_PDPHY_RX_SIZE_REG ? m->size : m->status; return 0;
}
static int regmap_bulk_read(struct regmap *m,unsigned int r,void *data,unsigned int size)
{
    uint16_t header = m->objects<<12;
    (void)r;
    if (fail(m)) return -EIO;
    assert(size<=sizeof(struct pd_message));
    memset(data,0,size); memcpy(data,&header,2); return 0;
}
static int regmap_write(struct regmap *m,unsigned int r,unsigned int v)
{
    assert(r == USB_PDPHY_RX_ACKNOWLEDGE_REG && v == 0);
    m->acks++;
    return fail(m) ? -EIO : 0;
}
static void tcpm_pd_receive(struct regmap *m,const struct pd_message *msg,int type)
{
    (void)msg; (void)type; m->delivered++;
}
#include RX_IMPL
int main(void)
{
    struct device dev={0}; struct regmap m={0};
    struct pmic_typec_pdphy phy={ .dev=&dev,.regmap=&m,.tcpm_port=&m };
#ifdef OLD_BEHAVIOR
    qcom_pmic_typec_pdphy_pd_receive(&phy);
    assert(m.delivered == 1 && m.acks == 0);
    puts("REPRODUCED original zero-size bug: uninitialized handoff, RX not released");
#else
    unsigned int i;
    for(i=0;i<=7;i++) {
        memset(&m,0,sizeof(m)); m.objects=i; m.size=1+4*i;
        qcom_pmic_typec_pdphy_pd_receive(&phy);
        assert(m.delivered==1 && m.acks==1);
    }
    for(i=1;i<=4;i++) {
        memset(&m,0,sizeof(m)); m.size=1; m.fail_at=i;
        qcom_pmic_typec_pdphy_pd_receive(&phy);
        assert(m.delivered==0 && m.acks==1);
    }
    memset(&m,0,sizeof(m));
    qcom_pmic_typec_pdphy_pd_receive(&phy);
    assert(m.delivered==0 && m.acks==1);
    memset(&m,0,sizeof(m)); m.size=31;
    qcom_pmic_typec_pdphy_pd_receive(&phy);
    assert(m.delivered==0 && m.acks==1);
    memset(&m,0,sizeof(m)); m.size=~0U;
    qcom_pmic_typec_pdphy_pd_receive(&phy);
    assert(m.delivered==0 && m.acks==1);
    memset(&m,0,sizeof(m)); m.size=1; m.status=1;
    qcom_pmic_typec_pdphy_pd_receive(&phy);
    assert(m.delivered==0 && m.acks==1);
    memset(&m,0,sizeof(m)); m.size=5; m.objects=2;
    qcom_pmic_typec_pdphy_pd_receive(&phy);
    assert(m.delivered==0 && m.acks==1);
    puts("R240 RX model:8 valid lengths,4 I/O faults,5 malformed cases PASS");
#endif
}
