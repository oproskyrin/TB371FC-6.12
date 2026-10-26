#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$PlatformToolsDir,

    [string]$Serial = $env:TB371FC_SERIAL,

    [ValidateSet('v1-6g', 'v2-12g')]
    [string]$ImageProfile = 'v1-6g',

    [string]$SourceImage,

    [ValidatePattern('^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$')]
    [string]$VolumeUuid = 'D42E-5DC7',

    [switch]$MicroSdWriteApproved,

    [switch]$UpgradeExisting
)

$ErrorActionPreference = 'Stop'
$Adb = Join-Path $PlatformToolsDir 'adb.exe'
$Profiles = @{
    'v1-6g' = @{
        Source = '\\wsl.localhost\Ubuntu-24.04\root\arch-tb371fc\tb371fc-arch-development-v1.raw'
        WslSource = '/root/arch-tb371fc/tb371fc-arch-development-v1.raw'
        Size = [Int64]6442450944
        Sha256 = '874aefbc65f176c94ad4e7dc7636993fd6d7f8b0bed8b77fee17da7d6609594e'
    }
    'v2-12g' = @{
        Source = '\\wsl.localhost\Ubuntu-24.04\root\arch-tb371fc\tb371fc-arch-development-v2-12g.raw'
        WslSource = '/root/arch-tb371fc/tb371fc-arch-development-v2-12g.raw'
        Size = [Int64]12884901888
        Sha256 = 'ae0fe97debbb6b6c485546dd130e9a9a15724784b41af3fb862bad1f1cf58b44'
    }
}
$Profile = $Profiles[$ImageProfile]
if ([string]::IsNullOrWhiteSpace($SourceImage)) {
    $SourceImage = $Profile.Source
}
$ExpectedSize = $Profile.Size
$ExpectedSha256 = $Profile.Sha256
$RemoteDir = "/storage/$VolumeUuid/tb371fc-linux"
$RemoteFinal = "$RemoteDir/tb371fc-arch-development.raw"
$RemotePartial = "$RemoteFinal.partial"
$RemoteBackup = "$RemoteDir/tb371fc-arch-development.pre-$ImageProfile-backup.raw"
$RemoteFailed = "$RemoteDir/tb371fc-arch-development.$ImageProfile-failed.raw"

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$Program,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )

    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path -LiteralPath $Adb -PathType Leaf)) {
    throw "adb.exe was not found: $Adb"
}
$source = Get-Item -LiteralPath $SourceImage
if ($source.Length -ne $ExpectedSize) {
    throw "Source image size mismatch: $($source.Length)"
}
$defaultWslSource = $Profile.Source
if ($source.FullName -eq $defaultWslSource) {
    $hashLine = (& wsl.exe -d Ubuntu-24.04 -u root -- sha256sum $Profile.WslSource) | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw 'WSL failed to hash the development image'
    }
    $sourceHash = ([regex]::Match($hashLine, '^[0-9a-fA-F]{64}')).Value.ToLowerInvariant()
} else {
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source.FullName).Hash.ToLowerInvariant()
}
if ($sourceHash -ne $ExpectedSha256) {
    throw "Source image SHA-256 mismatch: $sourceHash"
}

$deviceLine = @(& $Adb devices -l) | Where-Object {
    $_ -match "^$([regex]::Escape($Serial))\s+device\s+.*\bdevice:TB371FC\b"
}
if (@($deviceLine).Count -ne 1) {
    throw "Expected one authorized TB371FC $Serial in Android"
}
$state = (& $Adb -s $Serial shell "getprop sys.boot_completed; getprop ro.boot.slot_suffix; getprop ro.boot.flash.locked") | ForEach-Object { $_.Trim() }
if ($state.Count -ne 3 -or $state[0] -ne '1' -or $state[1] -ne '_b' -or $state[2] -ne '0') {
    throw "Unsafe Android state: $($state -join ',')"
}

$volume = (& $Adb -s $Serial shell 'sm list-volumes all') | Where-Object {
    $_.Trim() -eq "public:179,1 mounted $VolumeUuid"
}
if (@($volume).Count -ne 1) {
    throw "Expected mounted microSD volume $VolumeUuid was not found"
}
$remoteProbe = (& $Adb -s $Serial shell "if [ -e '$RemoteFinal' ]; then echo FINAL_EXISTS; fi; if [ -e '$RemotePartial' ]; then echo PARTIAL_EXISTS; fi; if [ -e '$RemoteBackup' ]; then echo BACKUP_EXISTS; fi; if [ -e '$RemoteFailed' ]; then echo FAILED_EXISTS; fi; df -k '/storage/$VolumeUuid' | tail -1") | Out-String
if ($remoteProbe -match 'PARTIAL_EXISTS|BACKUP_EXISTS|FAILED_EXISTS') {
    throw 'Refusing to overwrite an existing partial, backup or failed image'
}
$finalExists = $remoteProbe -match 'FINAL_EXISTS'
if ($finalExists -and -not $UpgradeExisting) {
    throw 'Existing image found. Pass -UpgradeExisting to preserve it as the schema-1 backup.'
}
if (-not $finalExists -and $UpgradeExisting) {
    throw 'Upgrade was requested but the existing final image is missing'
}
$dfMatch = [regex]::Match($remoteProbe, '(?m)^\S+\s+\d+\s+\d+\s+(\d+)\s+')
$RequiredFree = $ExpectedSize + 2GB
if (-not $dfMatch.Success -or [Int64]$dfMatch.Groups[1].Value * 1KB -lt $RequiredFree) {
    throw "microSD free space is unavailable or below the $RequiredFree-byte transaction floor"
}

Write-Host 'TB371FC microSD development-image preflight passed.'
Write-Host "  source: $($source.FullName)"
Write-Host "  profile: $ImageProfile"
Write-Host "  size:   $ExpectedSize bytes"
Write-Host "  SHA-256: $ExpectedSha256"
Write-Host "  target: $RemoteFinal"
if ($UpgradeExisting) {
    Write-Host "  preserved old image: $RemoteBackup"
} else {
    Write-Host '  existing microSD files and partition layout will not be changed.'
}

if (-not $MicroSdWriteApproved) {
    Write-Host "Preflight only. Pass -MicroSdWriteApproved to create the new $ExpectedSize-byte file."
    exit 0
}
if (-not $PSCmdlet.ShouldProcess($RemoteFinal, 'Create and verify Arch development image on microSD')) {
    exit 0
}

Invoke-NativeChecked $Adb -s $Serial shell "mkdir -p '$RemoteDir'"
Invoke-NativeChecked $Adb -s $Serial push $source.FullName $RemotePartial

$remoteSize = (& $Adb -s $Serial shell "toybox stat -c %s '$RemotePartial'").Trim()
if ($remoteSize -ne [string]$ExpectedSize) {
    throw "Remote partial image size mismatch: $remoteSize"
}
$remoteHashLine = (& $Adb -s $Serial shell "toybox sha256sum '$RemotePartial'") | Out-String
$remoteHash = ([regex]::Match($remoteHashLine, '^[0-9a-fA-F]{64}')).Value.ToLowerInvariant()
if ($remoteHash -ne $ExpectedSha256) {
    throw "Remote partial image SHA-256 mismatch: $remoteHash"
}

if ($UpgradeExisting) {
    Invoke-NativeChecked $Adb -s $Serial shell "mv '$RemoteFinal' '$RemoteBackup'"
    try {
        Invoke-NativeChecked $Adb -s $Serial shell "mv '$RemotePartial' '$RemoteFinal'"
    } catch {
        & $Adb -s $Serial shell "mv '$RemoteBackup' '$RemoteFinal'"
        throw
    }
} else {
    Invoke-NativeChecked $Adb -s $Serial shell "mv '$RemotePartial' '$RemoteFinal'"
}
try {
    $finalSize = (& $Adb -s $Serial shell "toybox stat -c %s '$RemoteFinal'").Trim()
    if ($finalSize -ne [string]$ExpectedSize) {
        throw "Final image size mismatch after rename: $finalSize"
    }
    $finalHashLine = (& $Adb -s $Serial shell "toybox sha256sum '$RemoteFinal'") | Out-String
    $finalHash = ([regex]::Match($finalHashLine, '^[0-9a-fA-F]{64}')).Value.ToLowerInvariant()
    if ($finalHash -ne $ExpectedSha256) {
        throw "Final image SHA-256 mismatch after rename: $finalHash"
    }
} catch {
    if ($UpgradeExisting) {
        & $Adb -s $Serial shell "mv '$RemoteFinal' '$RemoteFailed'; mv '$RemoteBackup' '$RemoteFinal'"
    }
    throw
}
Write-Host 'Verified Arch development image installed on microSD.'
Write-Host "  $RemoteFinal"
Write-Host "  SHA-256: $ExpectedSha256"
