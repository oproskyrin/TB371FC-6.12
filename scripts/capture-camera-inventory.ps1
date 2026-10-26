param(
    [string]$Serial = $env:TB371FC_SERIAL,
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb is not available in PATH"
}

$deviceLine = (& adb devices) | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+" }
if (-not $deviceLine) {
    throw "Tablet $Serial is not visible to adb"
}
if ($deviceLine -notmatch "\sdevice$") {
    throw "Tablet $Serial is not authorized: $deviceLine"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDirectory = Join-Path $PSScriptRoot "..\diagnostics\camera-$Serial-$stamp"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Save-AdbOutput {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string[]]$AdbArguments
    )

    $path = Join-Path $OutputDirectory $Name
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & adb -s $Serial @AdbArguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    @(
        "# adb -s $Serial $($AdbArguments -join ' ')"
        "# exit-code: $exitCode"
        $output
    ) | Set-Content -LiteralPath $path -Encoding utf8
}

Save-AdbOutput "getprop.txt" @("shell", "getprop")
Save-AdbOutput "hardwareinfo.txt" @("shell", "cat", "/sys/hwinfo/hardwareinfo")
Save-AdbOutput "camera-service.txt" @("shell", "dumpsys", "media.camera")
Save-AdbOutput "services.txt" @("shell", "service", "list")
Save-AdbOutput "vendor-camera-files.txt" @(
    "shell", "sh", "-c",
    "find /vendor/etc/camera /vendor/lib64/camera /vendor/lib64 -maxdepth 2 -type f 2>/dev/null | grep -Ei 'camera|camx|sensor|chromatix|eeprom|actuator' | sort"
)
Save-AdbOutput "video-nodes.txt" @(
    "shell", "sh", "-c",
    "ls -la /sys/class/video4linux /dev/video* /dev/media* 2>&1"
)

$logcat = & adb -s $Serial logcat -d -b all -v threadtime 2>&1
$logcat | Select-String -Pattern "camera|camx|sensor|csiphy|eeprom|actuator|AX6637|s5k4h7|gc08a3|hi1339|ofilm|qtech|txd" |
    ForEach-Object { $_.Line } |
    Set-Content -LiteralPath (Join-Path $OutputDirectory "camera-logcat.txt") -Encoding utf8

$manifest = Get-ChildItem -LiteralPath $OutputDirectory -File |
    Sort-Object Name |
    ForEach-Object {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
        "$hash  $($_.Name)"
    }
$manifest | Set-Content -LiteralPath (Join-Path $OutputDirectory "SHA256SUMS") -Encoding ascii

Write-Output "Read-only camera inventory saved to $OutputDirectory"
