#Requires -Version 5.1
<#
  TB371FC / Opus phase 3.
  Гипотеза: KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=60000 (renderloopfix)
  сорвал планировщик кадров KWin -> экран обновляется ~раз в 3 с.
  Действие: измерить -> снять ТОЛЬКО launcher -> перезагрузить -> измерить снова.
  Откат на планшете: /var/backups/tb371fc/opus-restore-<stamp>/rollback.sh
#>
[CmdletBinding()]
param(
    [string]$TabletIp     = '192.168.1.150',
    [string]$Subnet       = '192.168.1',
    [int]   $Port         = 2222,
    [string]$IdentityFile = '<repo>\artifacts\tb371fc-development-ssh\id_ed25519',
    [string]$ProjectRoot  = '<repo>',
    [int]   $BootWait     = 300
)
$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $ProjectRoot "diagnostics\$stamp-opus-phase3-restore"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$log = Join-Path $outDir 'session.log'
function W { param([string]$T,[string]$C='Gray') Write-Host $T -ForegroundColor $C; Add-Content -LiteralPath $log -Value $T -Encoding UTF8 }
function Q { param([string]$s) if ($s -match '\s') { '"' + $s + '"' } else { $s } }
function TestPort { param([string]$ip,[int]$pt,[int]$ms=2000)
    $c = New-Object System.Net.Sockets.TcpClient; $ok=$false
    try { $a=$c.BeginConnect($ip,$pt,$null,$null); $null=$a.AsyncWaitHandle.WaitOne($ms); $ok=$c.Connected } catch {}
    try { $c.Close() } catch {}; return $ok }

$khDir = Join-Path $env:LOCALAPPDATA 'tb371fc'; New-Item -ItemType Directory -Force -Path $khDir | Out-Null
$knownHosts = Join-Path $khDir 'known_hosts'
$sshOpts = @('-i',$IdentityFile,'-p',"$Port",'-o','IdentitiesOnly=yes','-o','BatchMode=yes',
             '-o','ConnectTimeout=10','-o','ServerAliveInterval=5','-o','ServerAliveCountMax=8',
             '-o','StrictHostKeyChecking=accept-new','-o',"UserKnownHostsFile=$knownHosts")

function RunRemote { param([string]$ip,[string]$scriptName,[string]$outName,[int]$timeoutMs=180000)
    $rs = Join-Path $ProjectRoot "scripts\$scriptName"
    if (-not (Test-Path -LiteralPath $rs)) { W "MISSING $rs" Red; return $false }
    $of = Join-Path $outDir $outName
    $ef = Join-Path $outDir ($outName -replace '\.txt$','.err.txt')
    $cl = (($sshOpts + @('-T', "root@$ip", 'sh -s')) | ForEach-Object { Q $_ }) -join ' '
    $p = Start-Process -FilePath 'ssh.exe' -ArgumentList $cl -RedirectStandardInput $rs `
            -RedirectStandardOutput $of -RedirectStandardError $ef -NoNewWindow -PassThru
    if (-not $p.WaitForExit($timeoutMs)) { try { $p.Kill() } catch {}; W "  TIMEOUT $scriptName" Red }
    if (Test-Path $of) { W ("  $outName : {0} bytes" -f (Get-Item $of).Length) Green }
    if ((Test-Path $ef) -and (Get-Item $ef).Length -gt 0) {
        Get-Content $ef | Select-Object -First 8 | ForEach-Object { W "    err: $_" Yellow } }
    return $true }

W "=== TB371FC Opus phase 3: restore stock KWin ===" Cyan
W "time   : $(Get-Date -Format 'u')"
W "outdir : $outDir"
W ""

if (-not (TestPort $TabletIp $Port)) {
    W "$TabletIp недоступен, сканирую $Subnet.0/24 ..." Yellow
    $hit = $null
    foreach ($i in 1..254) { if (TestPort "$Subnet.$i" $Port 200) { $hit = "$Subnet.$i"; break } }
    if (-not $hit) { W "планшет не найден" Red; return }
    $TabletIp = $hit
}
W "target : root@${TabletIp}:$Port" Green
W ""

W "--- ШАГ 1: измерение + снятие launcher + перезагрузка ---" Cyan
$null = RunRemote $TabletIp 'opus-phase3-pre.sh' 'pre.txt' 120000
W ""
W "--- фрагмент результата ---"
if (Test-Path (Join-Path $outDir 'pre.txt')) {
    Get-Content (Join-Path $outDir 'pre.txt') | Where-Object { $_ -match 'irq |printk|loadavg|md5|refreshRate|СНЯТ|выбран|откат' } |
        ForEach-Object { W "  $_" }
}
W ""

W "--- ШАГ 2: жду перезагрузку (до $BootWait c) ---" Cyan
Start-Sleep -Seconds 15
$down = $false
for ($t=0; $t -lt 60; $t++) { if (-not (TestPort $TabletIp $Port 500)) { $down = $true; break }; Start-Sleep -Seconds 1 }
if ($down) { W "  планшет ушёл в перезагрузку" Green } else { W "  порт не пропал - возможно reboot не начался" Yellow }

$found = $null
$deadline = (Get-Date).AddSeconds($BootWait)
while ((Get-Date) -lt $deadline) {
    if (TestPort $TabletIp $Port 800) { $found = $TabletIp; break }
    foreach ($i in 1..254) { $c="$Subnet.$i"; if ($c -ne $TabletIp -and (TestPort $c $Port 120)) { $found=$c; break } }
    if ($found) { break }
    Start-Sleep -Seconds 3
}
if (-not $found) {
    W "  планшет НЕ поднялся за $BootWait c." Red
    W "  Посмотри на экран. Откат: загрузить recovery V56.3 r3.3 (RELEASES.md)." Yellow
    W "  Либо, если SSH появится позже, запусти opus-01-run.cmd." Yellow
    return
}
W "  планшет вернулся: $found" Green
Start-Sleep -Seconds 25
W ""

W "--- ШАГ 3: контрольное измерение после перезагрузки ---" Cyan
$null = RunRemote $found 'opus-phase2.sh' 'post-measure.txt' 180000
$null = RunRemote $found 'opus-phase1.sh' 'post-state.txt' 180000
W ""
W "--- итог ---"
if (Test-Path (Join-Path $outDir 'post-measure.txt')) {
    Get-Content (Join-Path $outDir 'post-measure.txt') | Where-Object { $_ -match 'irq |сообщений/сек|kwin' } |
        ForEach-Object { W "  $_" }
}
if (Test-Path (Join-Path $outDir 'post-state.txt')) {
    Get-Content (Join-Path $outDir 'post-state.txt') | Where-Object { $_ -match 'exe=|kwin_wayland|СУЩЕСТВУЕТ|отсутствует|KWIN_DRM' } |
        Select-Object -First 12 | ForEach-Object { W "  $_" }
}
W ""
W "=== DONE ===" Cyan
W "files: $outDir"
W "Скажи Claude, что фаза 3 отработала."
