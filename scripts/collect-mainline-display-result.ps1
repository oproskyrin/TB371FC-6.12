#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$InterfaceIndex = 46,
    [string]$TabletAddress = '169.254.77.2',
    [int]$ShellPort = 2323,
    [int]$WaitSeconds = 150
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path $project "diagnostics\mainline-display-hardware-$stamp.txt"
$deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)

Write-Host "Waiting for TB371FC mainline NCM shell at ${TabletAddress}:$ShellPort..."
while ([DateTime]::UtcNow -lt $deadline) {
    try {
        $probe = & "$PSScriptRoot\invoke-diagnostic-ncm.ps1" `
            -InterfaceIndex $InterfaceIndex `
            -TabletAddress $TabletAddress `
            -Port $ShellPort `
            -Command 'echo TB371FC_MAINLINE_READY; echo TB371FC_COMMAND_DONE' `
            -TimeoutMilliseconds 1500
        if (($probe -join "`n") -match 'TB371FC_MAINLINE_READY') {
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if ([DateTime]::UtcNow -ge $deadline) {
    throw "Mainline NCM shell did not appear within $WaitSeconds seconds"
}

$command = @'
echo '== mainline display report =='
cat /run/tb371fc-display-report.txt 2>/dev/null || echo 'report not ready'
echo '== current DRM debugfs =='
find /sys/kernel/debug/dri -maxdepth 3 -type f -print -exec cat {} \; 2>/dev/null || true
echo '== complete dmesg =='
dmesg
echo TB371FC_COMMAND_DONE
'@

& "$PSScriptRoot\invoke-diagnostic-ncm.ps1" `
    -InterfaceIndex $InterfaceIndex `
    -TabletAddress $TabletAddress `
    -Port $ShellPort `
    -Command $command `
    -TimeoutMilliseconds 120000 `
    -OutputFile $output | Out-Host

Write-Host "Mainline display evidence saved: $output"
