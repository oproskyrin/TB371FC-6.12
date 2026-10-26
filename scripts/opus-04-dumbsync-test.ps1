#Requires -Version 5.1
<#
  TB371FC / Opus phase 4.
  Гипотеза: CPU-записи KWin в DRM dumb buffer не сбрасываются из кэша,
  дисплей читает устаревшее содержимое DRAM. Отсюда и "дрожание",
  и обновление htop раз в ~3 секунды при физических стабильных 120 Гц.
  Тест: /opt/tb371fc-kwin-dumbsync + DMA_BUF_IOCTL_SYNC + pacing 120000.
  One-shot: launcher самоудаляется через 300 c, следующая загрузка - штатный KWin.
#>
[CmdletBinding()]
param(
    [string]$TabletIp     = '',
    [string]$Subnet       = '192.168.1',
    [int]   $Port         = 2222,
    [string]$IdentityFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\tb371fc-development-ssh\id_ed25519'),
    [string]$ProjectRoot  = (Split-Path -Parent $PSScriptRoot),
    [int]   $BootWait     = 360
)
$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $ProjectRoot "diagnostics\$stamp-opus-dumbsync-visual"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$log = Join-Path $outDir 'session.log'
function W { param([string]$T,[string]$C='Gray') Write-Host $T -ForegroundColor $C; Add-Content -LiteralPath $log -Value $T -Encoding UTF8 }
function Q { param([string]$s) if ($s -match '\s') { '"' + $s + '"' } else { $s } }
function TestPort { param([string]$ip,[int]$pt,[int]$ms=1500)
    $c = New-Object System.Net.Sockets.TcpClient; $ok=$false
    try { $a=$c.BeginConnect($ip,$pt,$null,$null); $null=$a.AsyncWaitHandle.WaitOne($ms); $ok=$c.Connected } catch {}
    try { $c.Close() } catch {}; return $ok }
function FindTablet { param([string]$pref)
    if ($pref -and (TestPort $pref $Port)) { return $pref }
    foreach ($i in 1..254) { $c="$Subnet.$i"; if (TestPort $c $Port 150) { return $c } }
    return $null }

$khDir = Join-Path $env:LOCALAPPDATA 'tb371fc'; New-Item -ItemType Directory -Force -Path $khDir | Out-Null
$kh = Join-Path $khDir 'known_hosts'
$sshOpts = @('-i',$IdentityFile,'-p',"$Port",'-o','IdentitiesOnly=yes','-o','BatchMode=yes',
             '-o','ConnectTimeout=10','-o','ServerAliveInterval=5','-o','ServerAliveCountMax=8',
             '-o','StrictHostKeyChecking=no','-o',"UserKnownHostsFile=$kh")
function RunRemote { param([string]$ip,[string]$script,[string]$outName,[int]$ms=180000)
    $rs = Join-Path $ProjectRoot "scripts\$script"
    if (-not (Test-Path -LiteralPath $rs)) { W "MISSING $rs" Red; return }
    $of = Join-Path $outDir $outName
    $ef = Join-Path $outDir ($outName -replace '\.txt$','.err.txt')
    $cl = (($sshOpts + @('-T',"root@$ip",'sh -s')) | ForEach-Object { Q $_ }) -join ' '
    $p = Start-Process ssh.exe -ArgumentList $cl -RedirectStandardInput $rs `
            -RedirectStandardOutput $of -RedirectStandardError $ef -NoNewWindow -PassThru
    if (-not $p.WaitForExit($ms)) { try { $p.Kill() } catch {}; W "  TIMEOUT $script" Red }
    if (Test-Path $of) { Get-Content $of | ForEach-Object { W "  $_" } }
    if ((Test-Path $ef) -and (Get-Item $ef).Length -gt 0) {
        Get-Content $ef | Select-Object -First 6 | ForEach-Object { W "  err: $_" Yellow } } }

W "=== TB371FC Opus phase 4: dumbsync + 120Hz (one-shot) ===" Cyan
W "time   : $(Get-Date -Format 'u')"
W "outdir : $outDir"
W ""
$ip = FindTablet $TabletIp
if (-not $ip) { W "планшет не найден в $Subnet.0/24 на порту $Port" Red; return }
W "target : root@${ip}:$Port" Green
W ""

W "--- ШАГ 1: копирую one-shot скрипт на планшет ---" Cyan
$scpOpts = $sshOpts -replace '^-p$','-P'
$src = Join-Path $ProjectRoot 'scripts\tb371fc-kwin-dumbsync-120hz-oneshot.sh'
if (-not (Test-Path -LiteralPath $src)) { W "НЕТ $src" Red; return }
& scp.exe @scpOpts $src "root@${ip}:/var/tmp/tb371fc-kwin-dumbsync-120hz-oneshot.sh" 2>&1 | ForEach-Object { W "  $_" }
W ""

W "--- ШАГ 2: установка + перезагрузка ---" Cyan
$bootIdBefore = $null
RunRemote $ip 'opus-phase4-install.sh' 'install.txt' 90000
$it = Join-Path $outDir 'install.txt'
if (Test-Path $it) {
    $m = (Get-Content $it | Select-String 'boot_id ДО:') -join ''
    if ($m -match '([0-9a-f-]{36})') { $bootIdBefore = $Matches[1] }
    if ((Get-Content $it -Raw) -match 'ПРЕРВАНО') { W "" ; W "Установка отменена, планшет не тронут." Red; return }
}
W "  boot_id до перезагрузки: $bootIdBefore"
W ""

W "--- ШАГ 3: жду реальную перезагрузку (до $BootWait c) ---" Cyan
Start-Sleep -Seconds 20
$new = $null
$deadline = (Get-Date).AddSeconds($BootWait)
while ((Get-Date) -lt $deadline) {
    $cand = FindTablet $ip
    if ($cand) {
        $cl = (($sshOpts + @('-T',"root@$cand",'cat /proc/sys/kernel/random/boot_id; cut -d" " -f1 /proc/uptime')) | ForEach-Object { Q $_ }) -join ' '
        $tmp = Join-Path $outDir 'bootid.txt'
        $p = Start-Process ssh.exe -ArgumentList $cl -RedirectStandardOutput $tmp -RedirectStandardError (Join-Path $outDir 'bootid.err.txt') -NoNewWindow -PassThru
        if ($p.WaitForExit(20000)) {
            $t = (Get-Content $tmp -Raw)
            if ($t -match '([0-9a-f-]{36})') {
                $bid = $Matches[1]
                if ($bid -ne $bootIdBefore) { $new = $cand; W "  ПЕРЕЗАГРУЗИЛСЯ. новый boot_id=$bid, адрес $cand" Green; break }
                else { W "  ещё старый boot_id, жду..." }
            }
        } else { try { $p.Kill() } catch {} }
    }
    Start-Sleep -Seconds 5
}
if (-not $new) {
    W "  перезагрузка НЕ подтверждена за $BootWait c." Red
    W "  Посмотри на экран планшета и скажи Claude, что видишь." Yellow
    return
}
W "  жду 30 c пока поднимется KDE ..."
Start-Sleep -Seconds 30
W ""

W "--- ШАГ 4: проверка что тест реально активен ---" Cyan
RunRemote $new 'opus-phase4-verify.sh' 'verify.txt' 120000
W ""
W "=== ЧТО СДЕЛАТЬ ГЛАЗАМИ ===" Cyan
W "  1. На планшете открой htop (или konsole и введи htop)." Yellow
W "  2. Смотри на секунды в строке Uptime." Yellow
W "  3. Они идут ровно, или по-прежнему прыгают через 3 секунды?" Yellow
W "  4. Открой и закрой launcher, вызови экранную клавиатуру - дрожит?" Yellow
W ""
W "  Тестовый KWin работает до следующей перезагрузки." Gray
W "  Launcher самоудаляется через 300 c: следующая загрузка = штатный KWin." Gray
W ""
W "=== DONE ===" Cyan
W "files: $outDir"
