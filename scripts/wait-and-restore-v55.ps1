#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(1, 1440)]
    [int]$MaxWaitMinutes = 720,

    [ValidateRange(1, 30)]
    [int]$PollSeconds = 2,

    [string]$Serial = $env:TB371FC_SERIAL
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Controller = Join-Path $ScriptDir 'temporary-vbmeta-recovery-test.ps1'
$V55 = 'D:\TB371FC-builds\arch-development-loader-v55-community-simplefb-arch-loopback-ssh\tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img'
$V55Sha256 = 'c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5'
$Fastboot = (Get-Command fastboot.exe -ErrorAction Stop).Source
$PlatformToolsDir = Split-Path -Parent $Fastboot
$PowerShellExe = (Get-Process -Id $PID).Path

if ((Get-FileHash -Algorithm SHA256 -LiteralPath $V55).Hash.ToLowerInvariant() -ne $V55Sha256) {
    throw 'V55 SHA-256 mismatch; refusing to monitor or write'
}

& $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Controller `
    -Action ValidateOnly `
    -PlatformToolsDir $PlatformToolsDir `
    -RecoveryImage $V55 `
    '-Confirm:$false'
if ($LASTEXITCODE -ne 0) {
    throw 'V55 controller validation failed'
}

$deadline = [DateTime]::UtcNow.AddMinutes($MaxWaitMinutes)
Write-Output "[$([DateTime]::UtcNow.ToString('o'))] Waiting for exact Lenovo fastboot serial $Serial"
while ([DateTime]::UtcNow -lt $deadline) {
    $matches = @(& $Fastboot devices 2>$null | Where-Object {
        $_ -match "^$([regex]::Escape($Serial))\s+fastboot$"
    })
    if ($matches.Count -eq 1) {
        Write-Output "[$([DateTime]::UtcNow.ToString('o'))] Exact tablet fastboot detected; restoring unchanged V55"
        & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Controller `
            -Action LaunchFastboot `
            -PlatformToolsDir $PlatformToolsDir `
            -RecoveryImage $V55 `
            -TwoPartitionWriteApproved `
            -BootObserveSeconds 120 `
            '-Confirm:$false'
        if ($LASTEXITCODE -ne 0) {
            throw "V55 launch controller failed with exit code $LASTEXITCODE"
        }
        Write-Output "[$([DateTime]::UtcNow.ToString('o'))] V55 USB observer passed"
        exit 0
    }
    Start-Sleep -Seconds $PollSeconds
}

throw "Timed out after $MaxWaitMinutes minutes without exact tablet fastboot serial $Serial"
