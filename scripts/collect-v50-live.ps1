#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TabletAddress = '169.254.77.2',
    [int]$RescuePort = 2323,
    [int]$SshPort = 2222,
    [ValidateRange(10, 180)]
    [int]$WaitSeconds = 120,
    [string]$IdentityFile = (Join-Path $PSScriptRoot '..\artifacts\tb371fc-development-ssh\id_ed25519'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\diagnostics')
)

$ErrorActionPreference = 'Stop'
$identity = (Resolve-Path -LiteralPath $IdentityFile).Path
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
$session = Join-Path $outputRoot ("v50-live-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
[void](New-Item -ItemType Directory -Path $session)

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$adapter = $null
while ((Get-Date) -lt $deadline) {
    $adapter = Get-NetAdapter -IncludeHidden | Where-Object {
        $_.Status -eq 'Up' -and
        ($_.InterfaceDescription -match 'NCM|UsbNcm' -or $_.Name -match 'NCM')
    } | Sort-Object ifIndex | Select-Object -First 1
    if ($adapter) { break }
    Start-Sleep -Seconds 1
}
if (-not $adapter) {
    throw 'V50 USB NCM adapter did not appear.'
}

$source = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '0.*' } | Select-Object -First 1
if (-not $source) {
    throw "NCM interface $($adapter.ifIndex) has no IPv4 address."
}

$rescueCommand = @'
echo '=== V50 rescue ==='
uname -a
cat /run/tb371fc-v50/status 2>/dev/null
cat /run/tb371fc-v50/usb-status 2>/dev/null
cat /run/tb371fc-v50/framebuffer-pattern.exit 2>/dev/null
cat /proc/fb
ls -l /dev/fb0 /dev/dri/card0 2>&1
dmesg | grep -E 'simple-framebuffer|simplefb|fb0:|ioremap|cont_splash|no-map' | tail -n 100
ps | grep -E 'drm-kms|weston|Xorg' | grep -v grep || true
echo TB371FC_COMMAND_DONE
'@
& (Join-Path $PSScriptRoot 'invoke-diagnostic-ncm.ps1') `
    -InterfaceIndex $adapter.ifIndex `
    -TabletAddress $TabletAddress `
    -Port $RescuePort `
    -Command $rescueCommand `
    -TimeoutMilliseconds 15000 `
    -OutputFile (Join-Path $session 'rescue.txt') | Out-Host

$sshReady = $false
while ((Get-Date) -lt $deadline) {
    $sshReady = Test-NetConnection -ComputerName $TabletAddress -Port $SshPort `
        -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($sshReady) { break }
    Start-Sleep -Seconds 1
}
if (-not $sshReady) {
    Write-Warning "Rescue is reachable, but Arch SSH did not appear before timeout. Logs: $session"
    exit 2
}

$knownHosts = Join-Path (Split-Path -Parent $identity) 'known_hosts'
$sshCommand = @'
echo '=== V50 Arch SSH ==='
uname -a
cat /run/tb371fc-v50/status 2>/dev/null
cat /proc/fb
ls -l /dev/fb0 /dev/dri/card0 2>&1
findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS
pgrep -af 'drm-kms|weston|Xorg' || true
cat /var/log/tb371fc-development-init.log 2>/dev/null
cat /var/log/tb371fc-sshd.log 2>/dev/null | tail -n 80
test -x /run/tb371fc-rescue/return-to-bootloader && echo REMOTE_BOOTLOADER_HELPER_READY
echo TB371FC_COMMAND_DONE
'@
$sshOutput = & ssh.exe -b $source.IPAddress -i $identity -p $SshPort `
    -o IdentitiesOnly=yes `
    -o BatchMode=yes `
    -o ConnectTimeout=10 `
    -o StrictHostKeyChecking=accept-new `
    -o "UserKnownHostsFile=$knownHosts" `
    "root@$TabletAddress" $sshCommand 2>&1
$sshOutput | Set-Content -LiteralPath (Join-Path $session 'ssh.txt') -Encoding utf8
$sshOutput | Out-Host
if ($LASTEXITCODE -ne 0 -or $sshOutput -notmatch 'TB371FC_COMMAND_DONE') {
    throw "V50 SSH verification failed. Logs: $session"
}

Write-Host "V50 live evidence saved: $session"
