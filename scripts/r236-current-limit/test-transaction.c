/* SPDX-License-Identifier: GPL-2.0-only */
/* Fault-injected REGISTER MODEL only, NOT a model of charger electrical behavior. */
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef unsigned int u32;
struct regmap { unsigned int reg[0x1700]; int calls, fail_at; };
struct pmic_typec_port {
    unsigned int r236_cap_ma;
    bool r236_owned_suspend;
    struct regmap *regmap;
    int vbus_lock;
};
struct pmic_typec { struct pmic_typec_port *pmic_typec_port; };
struct tcpc_dev { struct pmic_typec *parent; };
#define tcpc_to_tcpm(c) ((c)->parent)
static void mutex_lock(int *m) { (void)m; }
static void mutex_unlock(int *m) { (void)m; }
static int fail(struct regmap *m) { return ++m->calls == m->fail_at; }
static int regmap_read(struct regmap *m, unsigned int r, unsigned int *v)
{
    if (fail(m)) return -EIO;
    *v = m->reg[r]; return 0;
}
static int regmap_write(struct regmap *m, unsigned int r, unsigned int v)
{
    if (fail(m)) return -EIO;
    m->reg[r] = v; return 0;
}
static int regmap_update_bits(struct regmap *m, unsigned int r,
                              unsigned int mask, unsigned int v)
{
    if (fail(m)) return -EIO;
    m->reg[r] = (m->reg[r] & ~mask) | (v & mask); return 0;
}
#include "callback.inc"
int main(void)
{
    struct regmap m = {0};
    struct pmic_typec_port p = { .r236_cap_ma=1500, .regmap=&m };
    struct pmic_typec parent = { .pmic_typec_port=&p };
    struct tcpc_dev tcpc = { .parent=&parent };
    int calls, i;
    assert(r236_set_current_limit(&tcpc,500,5000) == 0);
    assert(m.reg[0x1370] == 10 && !(m.reg[0x1340] & 1));
    calls = m.calls;
    for (i=1; i<=calls; ++i) {
        memset(&m,0,sizeof(m)); p.r236_owned_suspend=false; m.fail_at=i;
        assert(r236_set_current_limit(&tcpc,500,5000) == -EIO);
        /* Before successful suspend, no limit/mode changes are attempted. */
        if (i>3) assert(m.reg[0x1340] & 1);
        else assert(m.reg[0x1370] == 0);
    }
    memset(&m,0,sizeof(m)); p.r236_owned_suspend=false;
    m.reg[0x1340]=1;
    assert(r236_set_current_limit(&tcpc,500,5000) == -EBUSY);
    assert(m.reg[0x1340] == 1 && m.reg[0x1370] == 0);
    memset(&m,0,sizeof(m)); p.r236_owned_suspend=false;
    m.reg[0x1140]=1;
    assert(r236_set_current_limit(&tcpc,500,5000) == -EPERM);
    memset(&m,0,sizeof(m)); p.r236_owned_suspend=false;
    assert(r236_set_current_limit(&tcpc,500,9000) == -EINVAL);
    assert(m.reg[0x1340] & 1);
    assert(r236_set_current_limit(&tcpc,0,0) == 0);
    assert(m.reg[0x1340] & 1);
    assert(r236_set_current_limit(&tcpc,3000,5000) == 0);
    assert(m.reg[0x1370] == 30 && !(m.reg[0x1340] & 1));
    printf("R236 register model: success, %d injected faults, source/suspend/voltage/zero/cap PASS\n",calls);
}
