# One serial-bridge session per call against the first-stage 4.19 console.
# Usage: r140-serial-step.ps1 -Step preflight|upload|run
param([Parameter(Mandatory)][ValidateSet('preflight','upload','run')][string]$Step)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$key = 'artifacts/tb371fc-development-ssh/id_ed25519'
$opts = @('-i', $key, '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-o', 'ConnectTimeout=12')
$blog = Join-Path $root "diagnostics/r140-bridge-$Step.log"
$bridge = Start-Process -FilePath py -ArgumentList @('-3.14', 'scripts/tb371fc-serial-ssh-bridge.py', '--serial-port', 'COM9', '--listen-port', '22222', '--mode', 'ssh') -RedirectStandardOutput $blog -RedirectStandardError "$blog.err" -PassThru -NoNewWindow
$deadline = (Get-Date).AddSeconds(40)
while (-not ((Test-Path $blog) -and (Select-String -Path $blog, "$blog.err" -Pattern 'READY' -Quiet))) {
    if ($bridge.HasExited -or (Get-Date) -gt $deadline) { Get-Content $blog, "$blog.err" -ErrorAction SilentlyContinue; throw 'bridge not READY' }
    Start-Sleep -Milliseconds 300
}
switch ($Step) {
    'preflight' {
        & ssh -p22222 @opts root@127.0.0.1 'uname -r; cat /proc/sys/kernel/random/boot_id /proc/uptime; ls /run/tb371fc-rescue/; df -h /run | tail -1'
    }
    'upload' {
        & scp -O -P22222 @opts 'D:/TB371FC-builds/linux-6.12.30-tb371fc-r140-mmcx-simplefb/r140-payload.tar.gz' root@127.0.0.1:/run/tb371fc-r140.tar.gz
        "scp exit $LASTEXITCODE"
    }
    'run' {
        $ErrorActionPreference = 'Continue'
        $cmd = 'type scripts\test-r121-r140-mmcx-simplefb.sh | ssh -p22222 -i artifacts/tb371fc-development-ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=12 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 root@127.0.0.1 "sh -s" > diagnostics\r140-launch-20261024.log 2>&1'
        cmd.exe /c $cmd
        Get-Content diagnostics/r140-launch-20261024.log
    }
}
"ssh exit $LASTEXITCODE"
$null = $bridge.WaitForExit(30000)
if (-not $bridge.HasExited) { Stop-Process -Id $bridge.Id -Force; 'bridge stopped' } else { 'bridge closed' }
Get-Content $blog -Tail 3
