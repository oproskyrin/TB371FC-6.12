#Requires -Version 5.1
<#
  TB371FC / Opus phase 0 - discovery + READ-ONLY baseline snapshot.
  Ничего не пишет на планшет и не меняет разделы.
  v2: исправлено квотирование путей с пробелами + UTF-8 BOM.
#>
[CmdletBinding()]
param(
    [string]  $TabletIp       = '',
    [string]  $Subnet         = '192.168.1',
    [int]     $Port           = 2222,
    [string[]]$ExtraHosts     = @('169.254.77.2'),
    [string]  $IdentityFile   = '<repo>\artifacts\tb371fc-development-ssh\id_ed25519',
    [string]  $ProjectRoot    = '<repo>',
    [switch]  $InsecureHostKey
)

$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $ProjectRoot "diagnostics\$stamp-opus-baseline"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$log = Join-Path $outDir 'session.log'

function W {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
    Add-Content -LiteralPath $log -Value $Text -Encoding UTF8
}
function Q { param([string]$s) if ($s -match '\s') { '"' + $s + '"' } else { $s } }

W "=== TB371FC Opus phase 0 (v2) ===" Cyan
W "time   : $(Get-Date -Format 'u')"
W "outdir : $outDir"
W ""

W "--- host IPv4 ---" Cyan
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -ne '127.0.0.1' } |
    ForEach-Object { W ("  {0,-38} {1}/{2}" -f $_.InterfaceAlias, $_.IPAddress, $_.PrefixLength) }
W ""

W "--- ARP: USB Ethernet 00-03-7f ---" Cyan
$arpHits = (arp -a 2>&1 | Out-String) -split "`r?`n" | Where-Object { $_ -match '00-03-7f' }
if ($arpHits) { $arpHits | ForEach-Object { W "  $_" Green } } else { W "  (no 00-03-7f entries)" }
W ""

$found = @()
if ($TabletIp) {
    W "--- using given address $TabletIp ---" Cyan
    $c = New-Object System.Net.Sockets.TcpClient
    $ok = $false
    try { $a = $c.BeginConnect($TabletIp, $Port, $null, $null); $null = $a.AsyncWaitHandle.WaitOne(4000); $ok = $c.Connected } catch {}
    try { $c.Close() } catch {}
    if ($ok) { W "  OPEN ${TabletIp}:$Port" Green; $found = @($TabletIp) }
    else     { W "  ${TabletIp}:$Port closed" Yellow }
} else {
    W "--- scan $Subnet.0/24 port $Port ---" Cyan
    $targets = @(); 1..254 | ForEach-Object { $targets += "$Subnet.$_" }; $targets += $ExtraHosts
    $probes = foreach ($ip in $targets) {
        $c = New-Object System.Net.Sockets.TcpClient
        try { [pscustomobject]@{ IP=$ip; Client=$c; Async=$c.BeginConnect($ip,$Port,$null,$null) } } catch { $c.Close() }
    }
    Start-Sleep -Seconds 5
    foreach ($p in $probes) {
        try { if ($p.Client.Connected) { $found += $p.IP } } catch {}
        try { $p.Client.Close() } catch {}
    }
    if ($found) { $found | ForEach-Object { W "  OPEN ${_}:$Port" Green } } else { W "  port $Port not open anywhere" Yellow }
}
W ""

$pt  = '<platform-tools>'
$fb  = Join-Path $pt 'fastboot.exe'
W "--- fastboot (read-only) ---" Cyan
if (Test-Path $fb) { W ("  devices: " + ((& $fb devices 2>&1 | Out-String).Trim())) } else { W "  fastboot.exe not found" Yellow }
W ""

if (-not $found)                                { W "SSH unreachable. Stop." Yellow; W "log: $log" Cyan; return }
if (-not (Test-Path -LiteralPath $IdentityFile)){ W "MISSING key: $IdentityFile" Red; return }
$remote = Join-Path $ProjectRoot 'scripts\opus-snapshot.sh'
if (-not (Test-Path -LiteralPath $remote))      { W "MISSING scripts\opus-snapshot.sh" Red; return }

$knownHosts = Join-Path (Split-Path -Parent $IdentityFile) 'known_hosts'
$sshOpts = @('-i', $IdentityFile, '-p', "$Port",
             '-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','ConnectTimeout=10',
             '-o','ServerAliveInterval=5','-o','ServerAliveCountMax=6')
if ($InsecureHostKey) { $sshOpts += @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL') }
else                  { $sshOpts += @('-o','StrictHostKeyChecking=accept-new','-o',"UserKnownHostsFile=$knownHosts") }

foreach ($ip in $found) {
    W "=== SSH root@${ip}:$Port ===" Cyan
    $snapFile = Join-Path $outDir "snapshot-$ip.txt"
    $errFile  = Join-Path $outDir "snapshot-$ip.err.txt"
    $cmdline  = (($sshOpts + @('-T', "root@$ip", 'sh -s')) | ForEach-Object { Q $_ }) -join ' '
    W "  read-only snapshot, timeout 120s ..."
    $p = Start-Process -FilePath 'ssh.exe' -ArgumentList $cmdline `
            -RedirectStandardInput $remote -RedirectStandardOutput $snapFile `
            -RedirectStandardError $errFile -NoNewWindow -PassThru
    if (-not $p.WaitForExit(120000)) {
        try { $p.Kill() } catch {}
        W "  TIMEOUT: TCP up but no shell (symptom from opus/CURRENT_STATE.md)" Red
    } else { W "  ssh exit code $($p.ExitCode)" }
    if (Test-Path $snapFile) { W ("  snapshot: {0} bytes" -f (Get-Item $snapFile).Length) Green }
    if ((Test-Path $errFile) -and (Get-Item $errFile).Length -gt 0) {
        W "  --- stderr ---" Yellow
        Get-Content $errFile | Select-Object -First 20 | ForEach-Object { W "    $_" }
    }
    W "  copying journal/dmesg ..."
    $scpOpts = $sshOpts -replace '^-p$','-P'
    & scp.exe @scpOpts "root@${ip}:/var/tmp/journal-current-boot.txt" (Join-Path $outDir "journal-$ip.txt") 2>&1 | Out-Null
    & scp.exe @scpOpts "root@${ip}:/var/tmp/dmesg-current-boot.txt"   (Join-Path $outDir "dmesg-$ip.txt")   2>&1 | Out-Null
    foreach ($f in @("journal-$ip.txt","dmesg-$ip.txt")) {
        $fp = Join-Path $outDir $f
        if (Test-Path $fp) { W ("  {0}: {1} bytes" -f $f, (Get-Item $fp).Length) Green }
    }
    W ""
}
W "=== DONE ===" Cyan
W "files: $outDir"
