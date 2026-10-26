# Full remote release cycle (no button): reboot running 6.12 -> hold the 4.19 console -> upload the
# payload -> write it to microSD (verified) -> bootloader -> flash recovery_b/vbmeta_b -> wait for SSH.
#   tb371fc-flash-release.ps1 -Rel r170 -Payload D:/.../r170-payload.tar.gz -Recovery D:\...\r170.img -Rollback D:\...\r169.img
param(
    [Parameter(Mandatory)][string]$Rel, [Parameter(Mandatory)][string]$Payload,
    [Parameter(Mandatory)][string]$Recovery, [Parameter(Mandatory)][string]$Rollback,
    [switch]$AlreadyInConsole,
    # extra files to place in the 4.19 console before the SD install, as 'local=remote'
    [string[]]$Upload = @()
)
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$d = Get-Date -Format yyyyMMdd
function Step($m) { "[{0:HH:mm:ss}] {1}" -f (Get-Date), $m }
if (-not $AlreadyInConsole) {
    Step 'reboot to the 4.19 console'
    $r = & .\scripts\tb371fc-reboot-to-console.ps1 2>&1 | Select-Object -Last 1
    if ($r -ne 'CONSOLE_HELD') { Step "hold failed: $r"; exit 1 }
}
Step "upload $Payload"
py -3.14 scripts/recover-tb371fc-serial-gate.py COM9 | Out-Null
& .\scripts\serial-step.ps1 -Step upload -Payload $Payload -Remote "/run/tb371fc-$Rel.tar.gz" | Out-Null
foreach ($u in $Upload) {
    $l, $r = $u -split '=', 2
    Step "upload $l -> $r"
    py -3.14 scripts/recover-tb371fc-serial-gate.py COM9 | Out-Null
    & .\scripts\serial-step.ps1 -Step upload -Payload $l -Remote $r | Out-Null
}
Step 'write payload to microSD'
py -3.14 scripts/recover-tb371fc-serial-gate.py COM9 | Out-Null
& .\scripts\serial-step.ps1 -Step run -Runner "scripts/$Rel-sd-install-419.sh" -Log "diagnostics/$Rel-sd-install-$d.log" | Out-Null
if (-not (Select-String -Path "diagnostics\$Rel-sd-install-$d.log" -Pattern 'SD_INSTALL_OK' -Quiet)) { Step 'SD install FAILED'; exit 1 }
Step 'reboot to bootloader'
py -3.14 scripts/recover-tb371fc-serial-gate.py COM9 | Out-Null
& .\scripts\serial-step.ps1 -Step run -Runner scripts/r150-to-bootloader.sh -Log "diagnostics/$Rel-to-bootloader-$d.log" | Out-Null
$pt = (Get-Command fastboot).Source | Split-Path
$end = (Get-Date).AddSeconds(90); do { $fd = & "$pt\fastboot.exe" devices 2>$null; if ($fd) { break } } while ((Get-Date) -lt $end)
if (-not $fd) { Step 'no fastboot device'; exit 1 }
Step 'flash recovery_b + vbmeta_b'
# The controller must run in its OWN PowerShell process: any stderr redirection in the caller turns
# fastboot's progress output into terminating errors mid-flash and wedges the fastboot endpoint
# (happened twice: R165, R170). The child writes its own transcript; nothing is redirected here.
$flog = Join-Path $root "diagnostics\$Rel-flash-$d.log"
$inner = "Set-Location '$root'; Start-Transcript -Path '$flog' -Force | Out-Null; try { & '.\scripts\temporary-vbmeta-recovery-test.ps1' -Action LaunchFastboot -PlatformToolsDir '$pt' -RecoveryImage '$Recovery' -RollbackRecoveryImage '$Rollback' -TwoPartitionWriteApproved -BootObserveSeconds 180 -Confirm:`$false } finally { Stop-Transcript | Out-Null }"
$p = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $inner) -Wait -PassThru -WindowStyle Hidden
Step "controller exit $($p.ExitCode)"
Select-String -Path $flog -Pattern 'OKAY|recovery test:|FAIL' | ForEach-Object { $_.Line }
if (-not (Select-String -Path "diagnostics\$Rel-flash-$d.log" -Pattern "Writing 'vbmeta_b'.*OKAY" -Quiet)) { Step 'flash not confirmed'; exit 1 }
Step 'wait for autoboot (PC attached: 60 s window) and SSH'
$end = (Get-Date).AddSeconds(420); $ok = $false
do { if (Test-NetConnection 172.31.77.2 -Port 2222 -InformationLevel Quiet -WarningAction SilentlyContinue) { $ok = $true; break } } while ((Get-Date) -lt $end)
Step "SSH reachable=$ok"
if ($ok) { 'RELEASE_OK' } else { 'RELEASE_NO_SSH' }
