#!/bin/sh
mkdir -p /run/r129
{
    echo '=== R129 ARCH BOOT EVIDENCE ==='
    uname -a
    printf 'PID1: '
    cat /proc/1/comm
    printf 'root: '
    findmnt -n -o SOURCE,FSTYPE,OPTIONS /
    printf 'multi-user.target: '
    systemctl is-active multi-user.target
    systemctl --failed --no-pager
    echo 'R129: system changes are in RAM; USB/graphics not enabled'
    echo '=== R129 EVIDENCE END ==='
} 2>&1 | tee /run/r129/arch-evidence.txt
