# Wait for the first-stage 4.19 console (COM9) after a reboot and keep it from autobooting
# (R169+ recovery: 60 s window while the PC is attached; /run/tb371fc-autoboot-hold cancels).
param([int]$WaitSeconds = 300)
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$end = (Get-Date).AddSeconds($WaitSeconds)
do { if ([System.IO.Ports.SerialPort]::GetPortNames() -contains 'COM9') { break } } while ((Get-Date) -lt $end)
if (-not ([System.IO.Ports.SerialPort]::GetPortNames() -contains 'COM9')) { 'NO_COM9'; exit 1 }
py -3.14 scripts/recover-tb371fc-serial-gate.py COM9 | Out-Null
& .\scripts\serial-step.ps1 -Step run -Runner scripts/r169-hold.sh -Log diagnostics/hold-console.log | Out-Null
Get-Content diagnostics\hold-console.log
if (Select-String -Path diagnostics\hold-console.log -Pattern 'hold requested|cancelled' -Quiet) { 'CONSOLE_HELD' } else { 'HOLD_NOT_CONFIRMED' }
