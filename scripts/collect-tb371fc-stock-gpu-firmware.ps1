#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Adb = 'adb.exe',
    [string]$BaseFirmwareDir = 'D:\TB371FC-builds\tb371fc-linux-firmware-a650-r1',
    [string]$OutputDir = 'D:\TB371FC-builds\tb371fc-stock-gpu-firmware-r1'
)

$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputDir) {
    throw "Refusing to overwrite existing directory: $OutputDir"
}
if (-not (Test-Path -LiteralPath $BaseFirmwareDir -PathType Container)) {
    throw "Base firmware directory is missing: $BaseFirmwareDir"
}

& $Adb start-server | Out-Null
$state = (& $Adb get-state 2>$null).Trim()
if ($state -ne 'device') {
    throw "ADB device is not ready (state: '$state'). Boot Android and authorize this PC first."
}
$rootId = (& $Adb shell su -c id 2>$null | Out-String).Trim()
if ($rootId -notmatch 'uid=0') {
    throw 'Root through su is unavailable; stock firmware collection requires the existing Android root.'
}

Copy-Item -LiteralPath $BaseFirmwareDir -Destination $OutputDir -Recurse
$tempRemote = '/data/local/tmp/tb371fc-gpu-fw'
& $Adb shell su -c "rm -rf $tempRemote; mkdir -p $tempRemote; chmod 0777 $tempRemote" | Out-Null

function Copy-FirstStockFile {
    param(
        [Parameter(Mandatory)] [string[]]$Candidates,
        [Parameter(Mandatory)] [string]$Destination
    )
    foreach ($candidate in $Candidates) {
        & $Adb shell su -c "test -s '$candidate'" 2>$null
        if ($LASTEXITCODE -ne 0) { continue }
        $remoteName = Split-Path -Leaf $candidate
        & $Adb shell su -c "cp '$candidate' '$tempRemote/$remoteName'; chmod 0644 '$tempRemote/$remoteName'" | Out-Null
        $target = Join-Path $OutputDir $Destination
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        & $Adb pull "$tempRemote/$remoteName" $target | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to pull $candidate" }
        return $candidate
    }
    throw "None of the stock firmware candidates exists: $($Candidates -join ', ')"
}

$vendorRoots = @('/vendor/firmware', '/vendor/firmware_mnt/image', '/odm/firmware')
$sqeSource = Copy-FirstStockFile -Destination 'qcom\a650_sqe.fw' -Candidates ($vendorRoots | ForEach-Object { "$_/a650_sqe.fw" })
$gmuSource = Copy-FirstStockFile -Destination 'qcom\a650_gmu.bin' -Candidates ($vendorRoots | ForEach-Object { "$_/a650_gmu.bin" })
$zapSource = Copy-FirstStockFile -Destination 'qcom\sm8250\lenovo\tb371fc\a650_zap.mbn' -Candidates ($vendorRoots | ForEach-Object { "$_/a650_zap.mdt" })

$segmentSources = @()
foreach ($index in 0..15) {
    $suffix = 'b{0:d2}' -f $index
    $candidates = $vendorRoots | ForEach-Object { "$_/a650_zap.$suffix" }
    foreach ($candidate in $candidates) {
        & $Adb shell su -c "test -s '$candidate'" 2>$null
        if ($LASTEXITCODE -ne 0) { continue }
        $destination = "qcom\sm8250\lenovo\tb371fc\a650_zap.$suffix"
        $remoteName = "a650_zap.$suffix"
        & $Adb shell su -c "cp '$candidate' '$tempRemote/$remoteName'; chmod 0644 '$tempRemote/$remoteName'" | Out-Null
        & $Adb pull "$tempRemote/$remoteName" (Join-Path $OutputDir $destination) | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to pull $candidate" }
        $segmentSources += $candidate
        break
    }
}
& $Adb shell su -c "rm -rf $tempRemote" | Out-Null

$sourceLines = @(
    'source=TB371FC stock Android vendor firmware (rooted read-only collection)',
    "sqe=$sqeSource",
    "gmu=$gmuSource",
    "zap=$zapSource",
    "zap_segments=$($segmentSources -join ' ')",
    "collected_utc=$([DateTime]::UtcNow.ToString('o'))"
)
Set-Content -LiteralPath (Join-Path $OutputDir 'STOCK-SOURCE.txt') -Encoding utf8 -Value $sourceLines
Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
    Where-Object { $_.Name -ne 'SHA256SUMS' } |
    ForEach-Object {
        $relative = $_.FullName.Substring($OutputDir.Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
        "$hash  $relative"
    } | Set-Content -LiteralPath (Join-Path $OutputDir 'SHA256SUMS') -Encoding ascii

Write-Host "Stock A650 firmware collected without partition writes: $OutputDir"
Write-Host 'Use this directory as FIRMWARE_DIR for the final desktop package.'
