#Requires -Version 5.1
<#
  TB371FC / Opus phase 1 - READ-ONLY targeted diagnostics.
  Ничего не меняет на планшете.
#>
[CmdletBinding()]
param(
    [string]$TabletIp     = '192.168.1.150',
    [int]   $Port         = 2222,
    [string]$IdentityFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\tb371fc-development-ssh\id_ed25519'),
    [string]$ProjectRoot  = (Split-Path -Parent $PSScriptRoot),
    [string]$RemoteScript = 'opus-phase1.sh'
)
$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $ProjectRoot "diagnostics\$stamp-opus-phase1"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$log = Join-Path $outDir 'session.log'
function W { param([string]$T,[string]$C='Gray') Write-Host $T -ForegroundColor $C; Add-Content -LiteralPath $log -Value $T -Encoding UTF8 }
function Q { param([string]$s) if ($s -match '\s') { '"' + $s + '"' } else { $s } }

W "=== TB371FC Opus phase 1 (read-only) ===" Cyan
W "time   : $(Get-Date -Format 'u')"
W "target : root@${TabletIp}:$Port"
W "outdir : $outDir"
W ""

# known_hosts в пути без пробелов (ssh не умеет пробелы в UserKnownHostsFile)
$khDir = Join-Path $env:LOCALAPPDATA 'tb371fc'
New-Item -ItemType Directory -Force -Path $khDir | Out-Null
$knownHosts = Join-Path $khDir 'known_hosts'
$srcKh = Join-Path (Split-Path -Parent $IdentityFile) 'known_hosts'
if ((Test-Path $srcKh) -and -not (Test-Path $knownHosts)) { Copy-Item $srcKh $knownHosts -Force }

$remote = Join-Path $ProjectRoot "scripts\$RemoteScript"
if (-not (Test-Path -LiteralPath $remote))      { W "MISSING $remote" Red; return }
if (-not (Test-Path -LiteralPath $IdentityFile)){ W "MISSING key $IdentityFile" Red; return }

$sshOpts = @('-i',$IdentityFile,'-p',"$Port",
             '-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','ConnectTimeout=10',
             '-o','ServerAliveInterval=5','-o','ServerAliveCountMax=8',
             '-o','StrictHostKeyChecking=accept-new','-o',"UserKnownHostsFile=$knownHosts")

$outFile = Join-Path $outDir 'phase1.txt'
$errFile = Join-Path $outDir 'phase1.err.txt'
$cmdline = (($sshOpts + @('-T', "root@$TabletIp", 'sh -s')) | ForEach-Object { Q $_ }) -join ' '
W "running phase1 (timeout 180s) ..." Cyan
$p = Start-Process -FilePath 'ssh.exe' -ArgumentList $cmdline `
        -RedirectStandardInput $remote -RedirectStandardOutput $outFile `
        -RedirectStandardError $errFile -NoNewWindow -PassThru
if (-not $p.WaitForExit(180000)) { try { $p.Kill() } catch {}; W "TIMEOUT" Red }
else { W "ssh exit code $($p.ExitCode)" }
if (Test-Path $outFile) { W ("phase1.txt: {0} bytes" -f (Get-Item $outFile).Length) Green }
if ((Test-Path $errFile) -and (Get-Item $errFile).Length -gt 0) {
    W "--- stderr ---" Yellow; Get-Content $errFile | Select-Object -First 15 | ForEach-Object { W "  $_" }
}

# свежий dmesg (кольцевой буфер переполняется за ~35 мин)
W "copying fresh dmesg ..." Cyan
$scpOpts = $sshOpts -replace '^-p$','-P'
& scp.exe @scpOpts "root@${TabletIp}:/var/tmp/dmesg-current-boot.txt" (Join-Path $outDir 'dmesg.txt') 2>&1 | Out-Null
$dm = Join-Path $outDir 'dmesg.txt'
if (Test-Path $dm) { W ("dmesg.txt: {0} bytes" -f (Get-Item $dm).Length) Green }

W ""
W "=== DONE ===" Cyan
W "files: $outDir"
