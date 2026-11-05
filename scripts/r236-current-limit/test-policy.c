/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <stdio.h>
#include "policy.h"
int main(void)
{
    assert(r236_icl_code(1500,5000,1500) == 30);
    assert(r236_icl_code(3000,5000,1500) == 30);
    assert(r236_icl_code(3000,5000,3000) == 30);
    assert(r236_icl_code(1500,5000,900) == 18);
    assert(r236_icl_code(500,5000,1500) == 10);
    assert(r236_icl_code(100,5000,1500) == 2);
    assert(r236_icl_code(499,5000,1500) == 9);
    assert(r236_icl_code(50,5000,1500) == 1);
    assert(r236_icl_code(49,5000,1500) == 0);
    assert(r236_icl_code(0,5000,1500) == 0);
    assert(r236_icl_code(500,9000,1500) == 0);
    assert(r236_icl_code(500,0,1500) == 0);
    assert(r236_icl_code(500,5000,0) == 0);
    puts("R236 limit policy:13 cases PASS, not hardware validation");
}
