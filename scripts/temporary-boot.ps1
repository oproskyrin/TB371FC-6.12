#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$PlatformToolsDir,

    [string]$BootImage,

    [string]$Serial,

    [switch]$ExecuteTemporaryBoot
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BootImage) {
    $BootImage = Join-Path $ScriptDir '..\artifacts\tb371fc-touch-test-boot.img'
}
$ExpectedSha256 = 'e31ffbe084e0610e3467a98bf5708ee5ef1f665779aa7d0de5864a2739e80e79'
$MaximumBootImageSize = 96MB
$Adb = Join-Path $PlatformToolsDir 'adb.exe'
$Fastboot = Join-Path $PlatformToolsDir 'fastboot.exe'

foreach ($tool in @($Adb, $Fastboot)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        throw "Required platform tool not found: $tool"
    }
}

$BootImage = (Resolve-Path -LiteralPath $BootImage).Path
$imageInfo = Get-Item -LiteralPath $BootImage
if ($imageInfo.Length -gt $MaximumBootImageSize) {
    throw "Boot image exceeds the 96 MiB limit: $($imageInfo.Length) bytes"
}

$stream = [IO.File]::OpenRead($BootImage)
try {
    $magicBytes = New-Object byte[] 8
    if ($stream.Read($magicBytes, 0, 8) -ne 8) {
        throw 'Boot image is too short'
    }
    $magic = [Text.Encoding]::ASCII.GetString($magicBytes)
} finally {
    $stream.Dispose()
}
if ($magic -ne 'ANDROID!') {
    throw "Boot image has invalid magic: $magic"
}

$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $BootImage).Hash.ToLowerInvariant()
if ($actualSha256 -ne $ExpectedSha256) {
    throw "Boot image SHA-256 mismatch. Expected $ExpectedSha256, got $actualSha256"
}

$deviceLines = @(& $Adb devices -l) | Where-Object {
    $_ -match '^(\S+)\s+device\s+.*\bdevice:TB371FC\b'
}
if ($LASTEXITCODE -ne 0) {
    throw 'adb devices failed'
}
if ($Serial) {
    $deviceLines = @($deviceLines | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s" })
}
$deviceLines = @($deviceLines)
if ($deviceLines.Count -ne 1) {
    throw "Expected exactly one authorized TB371FC, found $($deviceLines.Count)"
}
$deviceLine = [string]$deviceLines[0]
$Serial = ([regex]::Match($deviceLine, '^(\S+)')).Groups[1].Value

function Get-AndroidProperty {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = (& $Adb -s $Serial shell getprop $Name)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read Android property: $Name"
    }
    return ($value | Out-String).Trim()
}

$device = Get-AndroidProperty 'ro.product.device'
$build = Get-AndroidProperty 'ro.build.display.id'
$slot = Get-AndroidProperty 'ro.boot.slot_suffix'
$locked = Get-AndroidProperty 'ro.boot.flash.locked'
$verifiedBoot = Get-AndroidProperty 'ro.boot.verifiedbootstate'

if ($device -ne 'TB371FC') {
    throw "Connected device is not TB371FC: $device"
}
if ($locked -ne '0') {
    throw "Bootloader is reported locked (ro.boot.flash.locked=$locked)"
}

Write-Host 'TB371FC temporary-boot preflight passed:'
Write-Host "  Serial:        $Serial"
Write-Host "  Android build: $build"
Write-Host "  Active slot:   $slot"
Write-Host "  Verified boot: $verifiedBoot"
Write-Host "  Image:         $BootImage"
Write-Host "  Size:          $($imageInfo.Length) bytes"
Write-Host "  SHA-256:       $actualSha256"

if (-not $ExecuteTemporaryBoot) {
    Write-Host ''
    Write-Host 'Preflight-only mode: no reboot or tablet mutation was performed.'
    Write-Host 'RAM boot is not available: the TB371FC ABL rejected fastboot boot as an unknown command.'
    exit 0
}

throw @'
Execution is disabled for this tablet/firmware. On 2026-08-10 the unlocked
TB371FC ABL accepted the image download but rejected the boot command with:
  FAILED (remote: 'unknown command')
No partition was written and Android recovered on slot B. Do not retry this
route and do not substitute fastboot flash. A separately reviewed launch and
rollback method is required.
'@
