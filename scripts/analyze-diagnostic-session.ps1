#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,

    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'
$inputPath = (Resolve-Path -LiteralPath $InputDirectory).Path
if (-not (Test-Path -LiteralPath $inputPath -PathType Container)) {
    throw "Diagnostic input is not a directory: $inputPath"
}
if (-not $OutputFile) {
    $OutputFile = Join-Path $inputPath 'session-summary.md'
}
$outputPath = [IO.Path]::GetFullPath($OutputFile)
if (Test-Path -LiteralPath $outputPath) {
    throw "Refusing to overwrite existing summary: $outputPath"
}

$files = @(Get-ChildItem -LiteralPath $inputPath -File -Filter '*.txt' |
    Where-Object { $_.FullName -ne $outputPath } |
    Sort-Object Name)
if (-not $files) {
    throw "No .txt diagnostic logs found in $inputPath"
}

$checks = @(
    [pscustomobject]@{ Name = 'Kernel panic'; Severity = 'FAIL'; Pattern = '(?im)kernel panic|not syncing' }
    [pscustomobject]@{ Name = 'Unexpected reboot evidence'; Severity = 'FAIL'; Pattern = '(?im)watchdog bite|subsystem_restart|rebooting in|restart level.*system' }
    [pscustomobject]@{ Name = 'Storage I/O error'; Severity = 'FAIL'; Pattern = '(?im)ufs.*(fatal|i/o error)|mmc.*i/o error|blk_update_request.*error' }
    [pscustomobject]@{ Name = 'Out of memory'; Severity = 'FAIL'; Pattern = '(?im)out of memory|oom-killer' }
    [pscustomobject]@{ Name = 'CNSS FW_READY timeout'; Severity = 'EXPECTED-BLOCKER'; Pattern = '(?im)timeout waiting for fw ready indication' }
    [pscustomobject]@{ Name = 'No-SSR suppression worked'; Severity = 'PASS'; Pattern = '(?im)suppressing wlan subsystem restart|soc restart was suppressed' }
    [pscustomobject]@{ Name = 'MHI mission mode reached'; Severity = 'PASS'; Pattern = '(?im)mission_mode' }
    [pscustomobject]@{ Name = 'QRTR service announcement'; Severity = 'PASS'; Pattern = '(?im)new-server|service.*instance.*node.*port' }
    [pscustomobject]@{ Name = 'FW_READY observed'; Severity = 'PASS'; Pattern = '(?im)(received.*fw[_ ]ready|fw[_ ]ready.*(received|success))' }
    [pscustomobject]@{ Name = 'wlan0 appeared'; Severity = 'PASS'; Pattern = '(?im)(^|\s)wlan0(:|\s)' }
    [pscustomobject]@{ Name = 'AP500U pen registered'; Severity = 'PASS'; Pattern = '(?im)nvtcapacitivepen|capacitive.*pen' }
    [pscustomobject]@{ Name = '120 Hz panel mode present'; Severity = 'PASS'; Pattern = '(?im)2944x1840.*120|120.*2944x1840' }
    [pscustomobject]@{ Name = 'DisplayPort connected'; Severity = 'PASS'; Pattern = '(?im)^-- /sys/class/drm/card\d+-DP-\d+/status\r?\nconnected$' }
    [pscustomobject]@{ Name = 'Bluetooth HCI present'; Severity = 'PASS'; Pattern = '(?im)(^|\s)hci0(\s|:|$)|/sys/class/bluetooth/hci\d+' }
    [pscustomobject]@{ Name = 'ALSA card present'; Severity = 'PASS'; Pattern = '(?im)^\s*[0-9]+\s+\[.+\]:' }
    [pscustomobject]@{ Name = 'Camera/media node present'; Severity = 'PASS'; Pattern = '(?im)/dev/(media|video|v4l-subdev)[0-9]+' }
)

$texts = @{}
foreach ($file in $files) {
    $texts[$file.Name] = [IO.File]::ReadAllText($file.FullName)
}

$builder = New-Object Text.StringBuilder
[void]$builder.AppendLine('# TB371FC diagnostic session summary')
[void]$builder.AppendLine()
[void]$builder.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
[void]$builder.AppendLine()
[void]$builder.AppendLine('## Automated findings')
[void]$builder.AppendLine()
[void]$builder.AppendLine('| Result | Check | Evidence files |')
[void]$builder.AppendLine('|---|---|---|')
foreach ($check in $checks) {
    $matches = @($files | Where-Object { $texts[$_.Name] -match $check.Pattern } | ForEach-Object Name)
    $result = if ($matches) { $check.Severity } else { 'NOT SEEN' }
    $evidence = if ($matches) { ($matches -join ', ') } else { '-' }
    [void]$builder.AppendLine("| $result | $($check.Name) | $evidence |")
}

[void]$builder.AppendLine()
[void]$builder.AppendLine('## Log integrity')
[void]$builder.AppendLine()
[void]$builder.AppendLine('| File | Bytes | SHA-256 |')
[void]$builder.AppendLine('|---|---:|---|')
foreach ($file in $files) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    [void]$builder.AppendLine("| $($file.Name) | $($file.Length) | ``$hash`` |")
}

[void]$builder.AppendLine()
[void]$builder.AppendLine('## Interpretation limits')
[void]$builder.AppendLine()
[void]$builder.AppendLine('This report is a deterministic pattern scan, not proof that a component is fully functional. Review the referenced raw logs before changing hardware state or authorizing another activation.')

$parent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $parent)
}
[IO.File]::WriteAllText($outputPath, $builder.ToString(), (New-Object Text.UTF8Encoding($false)))
Write-Host "Diagnostic summary created: $outputPath"
