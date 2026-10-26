#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('ValidateOnly', 'InstallStage0FromLenovoFastboot',
        'BootPayloadFromUboot', 'RestoreFromLenovoFastboot')]
    [string]$Action,

    [string]$PlatformToolsDir = (Split-Path (Get-Command fastboot.exe).Source),

    [ValidateSet('stage0', 'display-gated', 'display', 'arch-microsd',
        'r7-arch-microsd')]
    [string]$PayloadProfile = 'stage0',

    [string]$LenovoSerial = $env:TB371FC_SERIAL,

    [string]$UbootSerial = 'TB371FC-UBOOT',

    [switch]$TwoPartitionWriteApproved,

    [switch]$RamBootApproved,

    [switch]$RollbackToV56,

    [ValidateRange(30, 300)]
    [int]$ObserveSeconds = 120
)

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
$ArtifactDir = Join-Path $ProjectDir 'artifacts'
$BuildDir = 'D:\TB371FC-builds'
$Fastboot = Join-Path $PlatformToolsDir 'fastboot.exe'
$Paths = @{
    Stage0Recovery = Join-Path $BuildDir 'u-boot-tb371fc-stage0-v3-uncompressed\tb371fc-u-boot-stage0-recovery.img'
    Stage0Payload = Join-Path $BuildDir 'u-boot-linux-7.1.8-r6-display-wideplane-payloads\tb371fc-linux-7.1.8-stage0-u-boot.img'
    DisplayGatedPayload = Join-Path $BuildDir 'u-boot-linux-7.1.8-r6-display-gated-payload\tb371fc-linux-7.1.8-display-gated-u-boot.img'
    DisplayPayload = Join-Path $BuildDir 'u-boot-linux-7.1.8-r6-display-wideplane-payloads\tb371fc-linux-7.1.8-display-test-u-boot.img'
    ArchMicrosdPayload = Join-Path $BuildDir 'u-boot-linux-7.1.8-r4-arch-microsd-payloads\tb371fc-linux-7.1.8-arch-test-arch-development-u-boot.img'
    R7ArchMicrosdPayload = Join-Path $BuildDir 'u-boot-linux-7.1.8-r7-arch-microsd-payloads\tb371fc-linux-7.1.8-arch-test-arch-development-u-boot.img'
    V56Recovery = Join-Path $BuildDir 'arch-development-loader-v56-2-community-simplefb-qca6390-kde-fhandle-safe\tb371fc-arch-development-loader-v56-2-community-simplefb-qca6390-kde-fhandle-safe-recovery.img'
    RecoveryBackup = Join-Path $ArtifactDir 'device-backup\lun0-recovery_b.bin'
    VbmetaTest = Join-Path $ArtifactDir 'tb371fc-vbmeta_b-verification-disabled.img'
    VbmetaBackup = Join-Path $ArtifactDir 'device-backup\lun4-vbmeta_b.bin'
}
$Expected = @{
    Stage0Recovery = @{ Size = 104857600; Hash = '84bb3d7f8ae768e1550539b5b1489495f80ac375f55379cf4ac8c41b5321aa01' }
    Stage0Payload = @{ Size = 33812480; Hash = 'af8fe098070c0192af9840af98d7dcb55914d525c73745b9ef75688146d2daea' }
    DisplayGatedPayload = @{ Size = 18898944; Hash = '1bb58f5dbcd393dacfa63ed892f62b40ec9f63a889b497286c4f9cea7cf5aa93' }
    DisplayPayload = @{ Size = 33816576; Hash = '4f59f0ea38f1ddf135ba1a2739c1fb771e19aef1f45250d7d82657b9d80708e9' }
    ArchMicrosdPayload = @{ Size = 34086912; Hash = '6dd8f7542564ecdd60b4c28d912c2a097d38ea0a3121feb813bc86ba81d76d5c' }
    R7ArchMicrosdPayload = @{ Size = 34099200; Hash = 'f89dcb12e6d28ae3ab200bb07480268724eef0bd8b384b4022c9689df2ab7b7c' }
    V56Recovery = @{ Size = 104857600; Hash = 'b0cd0e66e9bade28c56c8215ed4f39503cf4649e02639cb72e779e6b4699447b' }
    RecoveryBackup = @{ Size = 104857600; Hash = '94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668' }
    VbmetaTest = @{ Size = 65536; Hash = '5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169' }
    VbmetaBackup = @{ Size = 65536; Hash = '58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05' }
}

function Invoke-NativeChecked {
    param([string]$Program, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

function Get-FastbootDevices {
    return @(& $Fastboot devices 2>$null | ForEach-Object {
        if ($_ -match '^(\S+)\s+fastboot$') { $Matches[1] }
    })
}

function Wait-FastbootSerial {
    param([string]$Serial, [int]$Seconds = 60)
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        if ((Get-FastbootDevices) -contains $Serial) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Fastboot serial $Serial did not appear within $Seconds seconds"
}

function Get-FastbootVariable {
    param([string]$Serial, [string]$Name)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Fastboot
    $startInfo.Arguments = "-s $Serial getvar $Name"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        $text = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "fastboot getvar $Name failed: $text" }
    } finally {
        $process.Dispose()
    }
    $match = [regex]::Match($text, "(?m)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if (-not $match.Success) { throw "Cannot parse fastboot variable $Name" }
    return $match.Groups[1].Value.Trim()
}

function Assert-LenovoFastbootSafety {
    Wait-FastbootSerial $LenovoSerial
    $slot = Get-FastbootVariable $LenovoSerial 'current-slot'
    $unlocked = Get-FastbootVariable $LenovoSerial 'unlocked'
    $recoverySize = Get-FastbootVariable $LenovoSerial 'partition-size:recovery_b'
    $vbmetaSize = Get-FastbootVariable $LenovoSerial 'partition-size:vbmeta_b'
    if ($slot -ne 'b' -or $unlocked -ne 'yes') {
        throw "Unsafe Lenovo fastboot state: slot=$slot unlocked=$unlocked"
    }
    if ([Convert]::ToUInt64(($recoverySize -replace '^0x', ''), 16) -ne 100MB -or
        [Convert]::ToUInt64(($vbmetaSize -replace '^0x', ''), 16) -ne 64KB) {
        throw "Unexpected slot-B partition sizes: recovery=$recoverySize vbmeta=$vbmetaSize"
    }
}

function Restore-SelectedBaseline {
    Assert-LenovoFastbootSafety
    if ($RollbackToV56) {
        Invoke-NativeChecked $Fastboot -s $LenovoSerial flash recovery_b $Paths.V56Recovery
        Invoke-NativeChecked $Fastboot -s $LenovoSerial flash vbmeta_b $Paths.VbmetaTest
        Write-Host 'V56.2 recovery_b and verification-disabled vbmeta_b restored.'
    } else {
        Invoke-NativeChecked $Fastboot -s $LenovoSerial flash recovery_b $Paths.RecoveryBackup
        Invoke-NativeChecked $Fastboot -s $LenovoSerial flash vbmeta_b $Paths.VbmetaBackup
        Write-Host 'Exact stock recovery_b and signed vbmeta_b restored.'
    }
}

function Start-SelectedBaseline {
    if ($RollbackToV56) {
        Invoke-NativeChecked $Fastboot -s $LenovoSerial reboot recovery
        Write-Host 'V56.2 Linux boot requested after rollback.'
    } else {
        Invoke-NativeChecked $Fastboot -s $LenovoSerial reboot
        Write-Host 'Normal Android boot requested after rollback.'
    }
}

function Get-LinuxDiagnosticUsb {
    return @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
        $_.PNPDeviceID -match '^USB\\VID_1D6B&PID_010[4-7].*\\TB371FC-'
    })
}

if (-not (Test-Path -LiteralPath $Fastboot -PathType Leaf)) {
    throw "fastboot.exe not found: $Fastboot"
}
foreach ($name in @($Paths.Keys | Sort-Object)) {
    $item = Get-Item -LiteralPath $Paths[$name]
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToLowerInvariant()
    if ($item.Length -ne $Expected[$name].Size -or $hash -ne $Expected[$name].Hash) {
        throw "$name failed pinned size/hash verification"
    }
    $Paths[$name] = $item.FullName
}

Write-Host 'All U-Boot, Linux payload, vbmeta and rollback artifacts are hash-verified.'
if ($Action -eq 'ValidateOnly') {
    Write-Host 'Validation-only mode: no device query, reboot, RAM boot or write was performed.'
    exit 0
}

if ($Action -eq 'InstallStage0FromLenovoFastboot') {
    if (-not $TwoPartitionWriteApproved) {
        throw 'Pass -TwoPartitionWriteApproved only during an attended test.'
    }
    Assert-LenovoFastbootSafety
    if (-not $PSCmdlet.ShouldProcess('TB371FC recovery_b and vbmeta_b',
        'Temporarily install read-only U-Boot stage-0')) { exit 0 }
    Invoke-NativeChecked $Fastboot -s $LenovoSerial flash recovery_b $Paths.Stage0Recovery
    try {
        Invoke-NativeChecked $Fastboot -s $LenovoSerial flash vbmeta_b $Paths.VbmetaTest
        Invoke-NativeChecked $Fastboot -s $LenovoSerial reboot recovery
    } catch {
        Write-Warning 'Stage-0 launch failed while Lenovo fastboot was available; restoring stock.'
        Restore-SelectedBaseline
        Start-SelectedBaseline
        throw
    }

    $disappearBy = [DateTime]::UtcNow.AddSeconds(15)
    while ([DateTime]::UtcNow -lt $disappearBy -and
        (Get-FastbootDevices) -contains $LenovoSerial) { Start-Sleep -Milliseconds 500 }
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        $devices = Get-FastbootDevices
        if ($devices -contains $UbootSerial) {
            Write-Host 'U-Boot stage-0 fastboot is ready as TB371FC-UBOOT.'
            Write-Host 'Next attended step: BootPayloadFromUboot with the stage0 profile.'
            exit 0
        }
        if ($devices -contains $LenovoSerial) {
            Write-Warning 'Stage-0 returned to Lenovo fastboot; restoring stock automatically.'
            Restore-SelectedBaseline
            Start-SelectedBaseline
            exit 2
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'U-Boot did not enumerate. Do not continue; manually enter Lenovo fastboot and restore.'
}

if ($Action -eq 'BootPayloadFromUboot') {
    if (-not $RamBootApproved) {
        throw 'Pass -RamBootApproved only with a person observing the tablet.'
    }
    Wait-FastbootSerial $UbootSerial
    $payloadName = switch ($PayloadProfile) {
        'stage0' { 'Stage0Payload' }
        'display-gated' { 'DisplayGatedPayload' }
        'display' { 'DisplayPayload' }
        'arch-microsd' { 'ArchMicrosdPayload' }
        'r7-arch-microsd' { 'R7ArchMicrosdPayload' }
    }
    if (-not $PSCmdlet.ShouldProcess("$UbootSerial RAM", "Boot $PayloadProfile Linux 7.1.8 payload")) { exit 0 }
    Invoke-NativeChecked $Fastboot -s $UbootSerial boot $Paths[$payloadName]

    $deadline = [DateTime]::UtcNow.AddSeconds($ObserveSeconds)
    do {
        if ((Get-LinuxDiagnosticUsb).Count -gt 0) {
            Write-Host "Linux $PayloadProfile diagnostic USB appeared; no partition was written by U-Boot."
            exit 0
        }
        if ((Get-FastbootDevices) -contains $LenovoSerial) {
            Write-Warning 'RAM payload returned to Lenovo fastboot; restoring stock automatically.'
            Restore-SelectedBaseline
            Start-SelectedBaseline
            exit 2
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'No Linux USB or Lenovo fastboot appeared. Preserve the screen, then manually enter Lenovo fastboot and restore.'
}

if (-not $TwoPartitionWriteApproved) {
    throw 'Pass -TwoPartitionWriteApproved to acknowledge the two exact stock restore writes.'
}
Assert-LenovoFastbootSafety
if (-not $PSCmdlet.ShouldProcess('TB371FC recovery_b and vbmeta_b', 'Restore exact stock backups')) { exit 0 }
Restore-SelectedBaseline
Start-SelectedBaseline
