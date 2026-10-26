# One serial-bridge session per call against the first-stage 4.19 console (COM9).
#   serial-step.ps1 -Step preflight
#   serial-step.ps1 -Step upload -Payload D:/.../x.tar.gz -Remote /run/tb371fc-rXXX.tar.gz
#   serial-step.ps1 -Step run -Runner scripts/test-....sh -Log diagnostics/....log
param(
    [Parameter(Mandatory)][ValidateSet('preflight','upload','run')][string]$Step,
    [string]$Payload, [string]$Remote, [string]$Runner, [string]$Log = 'diagnostics/serial-run.log'
)
$root = Split-Path -Parent $PSScriptRoot
if ($Runner) { $Runner = $Runner -replace '/', '\'; if (-not (Test-Path (Join-Path $root $Runner))) { throw "runner not found: $Runner" } }
if ($Log) { $Log = $Log -replace '/', '\' }
Set-Location $root
$o = '-i artifacts/tb371fc-development-ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=12'
$blog = Join-Path $root "diagnostics/bridge-$Step.log"
Remove-Item $blog, "$blog.err" -ErrorAction SilentlyContinue
$bridge = Start-Process -FilePath py -ArgumentList @('-3.14', 'scripts/tb371fc-serial-ssh-bridge.py', '--serial-port', 'COM9', '--listen-port', '22222', '--mode', 'ssh') -RedirectStandardOutput $blog -RedirectStandardError "$blog.err" -PassThru -NoNewWindow
$deadline = (Get-Date).AddSeconds(40)
while (-not ((Test-Path $blog) -and (Select-String -Path $blog, "$blog.err" -Pattern 'READY' -Quiet -ErrorAction SilentlyContinue))) {
    if ($bridge.HasExited -or (Get-Date) -gt $deadline) { Get-Content $blog, "$blog.err" -ErrorAction SilentlyContinue; Stop-Process -Id $bridge.Id -Force -ErrorAction SilentlyContinue; throw 'bridge not READY' }
    Start-Sleep -Milliseconds 300
}
switch ($Step) {
    'preflight' { cmd.exe /c "ssh -p22222 $o root@127.0.0.1 `"uname -r; cat /proc/sys/kernel/random/boot_id /proc/uptime; ls /run/*.tar.gz`" 2>&1" }
    'upload'    { cmd.exe /c "scp -O -P22222 $o `"$Payload`" root@127.0.0.1:$Remote 2>&1"; "scp exit $LASTEXITCODE" }
    'run'       { cmd.exe /c "type `"$Runner`" | ssh -p22222 $o -o ServerAliveInterval=10 -o ServerAliveCountMax=3 root@127.0.0.1 `"sh -s`" > `"$Log`" 2>&1"; Get-Content $Log }
}
"exit $LASTEXITCODE"
$null = $bridge.WaitForExit(30000)
if (-not $bridge.HasExited) { Get-CimInstance Win32_Process -Filter "ParentProcessId=$($bridge.Id)" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; Stop-Process -Id $bridge.Id -Force; 'bridge stopped' } else { 'bridge closed' }
