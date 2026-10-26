#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Preflight', 'Launch', 'Restore')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$PlatformToolsDir,

    [string]$Serial = $env:TB371FC_SERIAL,

    [string]$RecoveryImage,

    [string]$RecoveryBackup
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RecoveryImage) {
    $RecoveryImage = Join-Path $ScriptDir '..\artifacts\tb371fc-touch-test-recovery.img'
}
if (-not $RecoveryBackup) {
    $RecoveryBackup = Join-Path $ScriptDir '..\artifacts\device-backup\lun0-recovery_b.bin'
}

$AllowedImageHashes = @{
    '7b0b9d3fcceae0a0acc5b2a71b17622c23c925c3443cec9ec0a1aebf2c26cd66' = 'Linux 7.1.7 touch diagnostic'
    '7f5d22a3300a585b4f3f4fccff41615f158879f5fec7ed173b704cd8fa529825' = 'Linux 7.1.8 touch and dock diagnostic'
}
$ExpectedBackupSha256 = '94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668'
$RecoveryPartitionSize = 100MB
$Adb = Join-Path $PlatformToolsDir 'adb.exe'
$Fastboot = Join-Path $PlatformToolsDir 'fastboot.exe'

function Assert-FileHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolved).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256) {
        throw "$Label SHA-256 mismatch. Expected $ExpectedSha256, got $actual"
    }
    return $resolved
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Program,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )

    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

function Get-AdbProperty {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = & $Adb -s $Serial shell getprop $Name
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read Android property $Name"
    }
    return ($value | Out-String).Trim()
}

function Wait-FastbootDevice {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        $lines = @(& $Fastboot devices 2>$null)
        if ($lines | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+fastboot$" }) {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Tablet $Serial did not appear in fastboot within 45 seconds"
}

function Get-FastbootVariable {
    param([Parameter(Mandatory = $true)][string]$Name)

    # fastboot prints successful getvar replies to stderr. Capture the native
    # streams directly so Windows PowerShell 5 cannot wrap them as error records.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Fastboot
    $startInfo.Arguments = "-s $Serial getvar $Name"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Failed to start fastboot getvar $Name"
        }
        $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } finally {
        $process.Dispose()
    }
    if ($exitCode -ne 0) {
        throw "fastboot getvar $Name failed: $output"
    }
    $match = [regex]::Match($output, "(?m)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if (-not $match.Success) {
        throw "Could not parse fastboot variable $Name from: $output"
    }
    return $match.Groups[1].Value.Trim()
}

foreach ($tool in @($Adb, $Fastboot)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        throw "Required platform tool not found: $tool"
    }
}

$RecoveryImage = (Resolve-Path -LiteralPath $RecoveryImage).Path
$ActualImageSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $RecoveryImage).Hash.ToLowerInvariant()
if (-not $AllowedImageHashes.ContainsKey($ActualImageSha256)) {
    throw "Diagnostic recovery SHA-256 is not allowlisted: $ActualImageSha256"
}
$RecoveryBackup = Assert-FileHash $RecoveryBackup $ExpectedBackupSha256 'Original recovery_b backup'
if ((Get-Item -LiteralPath $RecoveryImage).Length -gt $RecoveryPartitionSize) {
    throw 'Diagnostic image exceeds the 100 MiB recovery_b partition'
}
if ((Get-Item -LiteralPath $RecoveryBackup).Length -ne $RecoveryPartitionSize) {
    throw 'Original recovery_b backup is not exactly 100 MiB'
}

Write-Host 'Pinned recovery artifacts verified:'
Write-Host "  Test image: $RecoveryImage"
Write-Host "  Test SHA-256: $ActualImageSha256"
Write-Host "  Test profile: $($AllowedImageHashes[$ActualImageSha256])"
Write-Host "  Backup: $RecoveryBackup"
Write-Host "  Backup SHA-256: $ExpectedBackupSha256"

if ($Action -in @('Preflight', 'Launch')) {
    $deviceLine = @(& $Adb devices -l) | Where-Object {
        $_ -match "^$([regex]::Escape($Serial))\s+device\s+.*\bdevice:TB371FC\b"
    }
    if (@($deviceLine).Count -ne 1) {
        throw "Expected authorized TB371FC $Serial in Android"
    }

    $slot = Get-AdbProperty 'ro.boot.slot_suffix'
    $locked = Get-AdbProperty 'ro.boot.flash.locked'
    $bootCompleted = Get-AdbProperty 'sys.boot_completed'
    $batteryText = (& $Adb -s $Serial shell dumpsys battery) | Out-String
    $batteryMatch = [regex]::Match($batteryText, '(?m)^\s*level:\s*(\d+)\s*$')
    if ($slot -ne '_b' -or $locked -ne '0' -or $bootCompleted -ne '1') {
        throw "Unsafe Android state: slot=$slot locked=$locked boot_completed=$bootCompleted"
    }
    if (-not $batteryMatch.Success -or [int]$batteryMatch.Groups[1].Value -lt 50) {
        throw "Battery level is unavailable or below 50%"
    }

    Write-Host "Android preflight passed: slot B, unlocked, battery $($batteryMatch.Groups[1].Value)%"
    if ($Action -eq 'Preflight') {
        Write-Host 'Preflight-only mode: no reboot and no write were performed.'
        exit 0
    }

    if (-not $PSCmdlet.ShouldProcess('TB371FC recovery_b', 'Temporarily replace recovery_b and boot it once')) {
        exit 0
    }

    Invoke-Checked $Adb -s $Serial reboot bootloader
    Wait-FastbootDevice
    $fastbootSlot = Get-FastbootVariable 'current-slot'
    $unlocked = Get-FastbootVariable 'unlocked'
    $partitionSize = Get-FastbootVariable 'partition-size:recovery_b'
    if ($fastbootSlot -ne 'b' -or $unlocked -ne 'yes') {
        throw "Unsafe fastboot state: current-slot=$fastbootSlot unlocked=$unlocked"
    }
    if ([Convert]::ToUInt64(($partitionSize -replace '^0x', ''), 16) -ne $RecoveryPartitionSize) {
        throw "Unexpected recovery_b size: $partitionSize"
    }

    Invoke-Checked $Fastboot -s $Serial flash recovery_b $RecoveryImage
    Invoke-Checked $Fastboot -s $Serial reboot recovery
    Write-Host 'Diagnostic recovery was written and recovery boot was requested.'
    Write-Host 'After collecting logs, run /bin/busybox reboot -f in the USB serial shell.'
    Write-Host 'When Android returns, run this script with -Action Restore immediately.'
    exit 0
}

if (-not $PSCmdlet.ShouldProcess('TB371FC recovery_b', 'Restore the exact EDL backup of recovery_b')) {
    exit 0
}

$adbLine = @(& $Adb devices) | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+device$" }
if (@($adbLine).Count -eq 1) {
    if ((Get-AdbProperty 'ro.boot.slot_suffix') -ne '_b') {
        throw 'Android did not return on slot B; refusing automatic restore'
    }
    Invoke-Checked $Adb -s $Serial reboot bootloader
}
Wait-FastbootDevice
if ((Get-FastbootVariable 'current-slot') -ne 'b' -or (Get-FastbootVariable 'unlocked') -ne 'yes') {
    throw 'Unsafe fastboot state for recovery restore'
}
Invoke-Checked $Fastboot -s $Serial flash recovery_b $RecoveryBackup
Invoke-Checked $Fastboot -s $Serial reboot
Write-Host 'Original recovery_b was restored from the verified EDL backup.'
