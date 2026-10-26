#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('ValidateOnly', 'FlashFastboot')]
    [string]$Action = 'ValidateOnly',
    [string]$Serial = $env:TB371FC_SERIAL
)

$ErrorActionPreference = 'Stop'
$Recovery = 'D:\TB371FC-builds\linux-6.12.30-tb371fc-direct-recovery-r5\recovery.img'
$Vbmeta = Join-Path $PSScriptRoot '..\artifacts\tb371fc-vbmeta_b-verification-disabled.img'
$Rollback = 'D:\TB371FC-builds\arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe\tb371fc-arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe-recovery.img'
$Expected = @{
    Recovery = 'c74083af711400a37651e9e2b7f78dfb61b472e3b248331d2e65cf8393062944'
    Vbmeta = '5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169'
    Rollback = 'c08efccc1f94d0c3da9ce0689b668c4640cc27523e64c97e81bde767eef1ab3b'
}

function Assert-Hash([string]$Path, [string]$Hash) {
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $actual = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Hash) { throw "SHA-256 mismatch for $resolved`: $actual" }
    return $resolved
}

function Get-FastbootVar([string]$Name) {
    $output = (& fastboot.exe -s $Serial getvar $Name 2>&1) | Out-String
    if ($LASTEXITCODE -ne 0) { throw "fastboot getvar $Name failed: $output" }
    $match = [regex]::Match($output, "(?m)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if (-not $match.Success) { throw "Cannot parse fastboot variable $Name" }
    return $match.Groups[1].Value.Trim()
}

$Recovery = Assert-Hash $Recovery $Expected.Recovery
$Vbmeta = Assert-Hash $Vbmeta $Expected.Vbmeta
$Rollback = Assert-Hash $Rollback $Expected.Rollback
if ((Get-Item -LiteralPath $Recovery).Length -ne 100MB -or
    (Get-Item -LiteralPath $Rollback).Length -ne 100MB -or
    (Get-Item -LiteralPath $Vbmeta).Length -ne 64KB) {
    throw 'Pinned artifact size mismatch'
}

Write-Host 'Linux 6.12 r5 direct recovery and V56.5 rollback verified.'
if ($Action -eq 'ValidateOnly') { exit 0 }

$device = @(& fastboot.exe devices) | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+fastboot$" }
if ($device.Count -ne 1) { throw "Expected $Serial in fastboot" }
$slot = Get-FastbootVar 'current-slot'
$unlocked = Get-FastbootVar 'unlocked'
$recoverySize = [Convert]::ToUInt64(((Get-FastbootVar 'partition-size:recovery_b') -replace '^0x', ''), 16)
$vbmetaSize = [Convert]::ToUInt64(((Get-FastbootVar 'partition-size:vbmeta_b') -replace '^0x', ''), 16)
if ($slot -ne 'b' -or $unlocked -ne 'yes' -or $recoverySize -ne 100MB -or $vbmetaSize -ne 64KB) {
    throw "Unsafe fastboot state: slot=$slot unlocked=$unlocked recovery=$recoverySize vbmeta=$vbmetaSize"
}

if (-not $PSCmdlet.ShouldProcess('TB371FC recovery_b and vbmeta_b', 'Install Linux 6.12 r5 direct recovery without automatic rollback')) { exit 0 }
& fastboot.exe -s $Serial flash recovery_b $Recovery
if ($LASTEXITCODE -ne 0) { throw 'recovery_b flash failed' }
& fastboot.exe -s $Serial flash vbmeta_b $Vbmeta
if ($LASTEXITCODE -ne 0) { throw 'vbmeta_b flash failed; remain in fastboot and restore the pinned V56.5 recovery' }
& fastboot.exe -s $Serial reboot recovery
if ($LASTEXITCODE -ne 0) { throw 'reboot recovery failed' }
Write-Host 'Linux 6.12 r5 boot requested. No automatic V56.5 rollback is armed.'
Write-Host "Pinned rollback remains at: $Rollback"
