import pathlib
import subprocess
root=pathlib.Path(__file__).resolve().parents[1]
bundle=root/'artifacts/r108-control-20260907/payload.tar.gz'
remote="set -e; test ! -e /run/r108-control; mkdir /run/r108-control; tar -xzf - -C /run/r108-control; uname -r; cat /proc/sys/kernel/random/boot_id; sha256sum /run/r108-control/opt/tb371fc-linux-6.12-r38/*; sh /run/r108-control/bin/load-linux-6.12-r38; /run/tb371fc-rescue/execute-linux-6.12-r38"
with bundle.open('rb') as data, (bundle.parent/'dispatch.log').open('w',encoding='utf-8') as log:
    proc=subprocess.Popen(['ssh','-i',str(root/'artifacts/tb371fc-development-ssh/id_ed25519'),'-p','22222','-o','ConnectTimeout=20','-o','ServerAliveInterval=10','-o','ServerAliveCountMax=2','root@127.0.0.1',remote],stdin=data,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    for line in proc.stdout:
        print(line,end='',flush=True); log.write(line); log.flush()
    rc=proc.wait()
    print(f'SSH_EXIT={rc} (disconnect alone does not prove kernel boot)',flush=True)
