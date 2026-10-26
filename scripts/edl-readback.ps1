#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^COM\d+$')]
    [string]$ComPort,

    [string]$ToolsDir,
    [string]$ReadbackXml,
    [string]$Inventory,
    [string]$OutputDir,
    [switch]$ExecuteReadback
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path

if (-not $ToolsDir) {
    $ToolsDir = Join-Path $RepoRoot 'tools\tb371fc-stock-recovery'
}
if (-not $ReadbackXml) {
    $ReadbackXml = Join-Path $RepoRoot 'artifacts\edl-readback\tb371fc-critical-readback.xml'
}
if (-not $Inventory) {
    $Inventory = Join-Path $RepoRoot 'artifacts\edl-readback\tb371fc-critical-readback.json'
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot ('artifacts\device-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

$ToolsDir = (Resolve-Path -LiteralPath $ToolsDir).Path
$ReadbackXml = (Resolve-Path -LiteralPath $ReadbackXml).Path
$Inventory = (Resolve-Path -LiteralPath $Inventory).Path
$OutputDir = [IO.Path]::GetFullPath($OutputDir)

$Sahara = Join-Path $ToolsDir 'QSaharaServer.exe'
$Loader = Join-Path $ToolsDir 'fh_loader.exe'
$Firehose = Join-Path $ToolsDir 'prog_firehose_ddr.elf'

$PinnedHashes = @{
    'QSaharaServer.exe'     = '42a5cdd3daa1798099625962a569a72656f28dd7d408be0e532bb12ee35ec4aa'
    'fh_loader.exe'         = 'dea55ec366c9b9a85c6b16b91b6796d8bace3c834850d7307ae17cacb91c5145'
    'prog_firehose_ddr.elf' = '974e9d8cf8b8daa04efd31a64f6b63719ca87e7fcbcfe1f5ed1d3e0b5b483429'
}

foreach ($path in @($Sahara, $Loader, $Firehose)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing stock recovery tool: $path"
    }
    $name = Split-Path -Leaf $path
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actual -ne $PinnedHashes[$name]) {
        throw "SHA-256 mismatch for $name`: $actual"
    }
}

[xml]$xml = Get-Content -Raw -LiteralPath $ReadbackXml
$commands = @($xml.data.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
if ($commands.Count -eq 0) {
    throw 'Readback XML has no commands'
}
$unsafe = @($commands | Where-Object { $_.Name -ne 'read' })
if ($unsafe.Count -ne 0) {
    throw "Readback XML contains non-read commands: $($unsafe.Name -join ', ')"
}

$parsedInventory = Get-Content -Raw -LiteralPath $Inventory | ConvertFrom-Json
$inventoryData = @()
foreach ($item in $parsedInventory) {
    $inventoryData += $item
}
if ($inventoryData.Count -ne $commands.Count) {
    throw "XML/inventory count mismatch: $($commands.Count) vs $($inventoryData.Count)"
}

$expectedTotal = [int64]0
$expectedNames = @{}
foreach ($entry in $inventoryData) {
    $filename = [string]$entry.filename
    if ([IO.Path]::GetFileName($filename) -ne $filename) {
        throw "Unsafe output filename in inventory: $filename"
    }
    if ($expectedNames.ContainsKey($filename)) {
        throw "Duplicate output filename in inventory: $filename"
    }
    $expectedNames[$filename] = $entry
    $expectedTotal += [int64]$entry.expected_bytes
}

foreach ($command in $commands) {
    $filename = [string]$command.filename
    if (-not $expectedNames.ContainsKey($filename)) {
        throw "XML output is absent from inventory: $filename"
    }
}

$driveRoot = [IO.Path]::GetPathRoot($OutputDir)
$driveName = $driveRoot.TrimEnd('\').TrimEnd(':')
$freeBytes = (Get-PSDrive -Name $driveName).Free
if ($freeBytes -lt ($expectedTotal + 256MB)) {
    throw "Insufficient free space: need at least $($expectedTotal + 256MB) bytes"
}

$qdloader = @(Get-CimInstance Win32_PnPEntity | Where-Object {
    $_.PNPDeviceID -match '^USB\\VID_05C6&PID_9008' -and
    $_.Name -match [regex]::Escape("($ComPort)")
})

Write-Host 'TB371FC EDL readback preflight:'
Write-Host "  XML commands:     $($commands.Count), all read-only"
Write-Host "  Expected output:  $expectedTotal bytes"
Write-Host "  Destination:      $OutputDir"
Write-Host "  Firehose SHA-256: $($PinnedHashes['prog_firehose_ddr.elf'])"
if ($qdloader.Count -eq 1) {
    Write-Host "  Device:           $($qdloader[0].Name)"
} else {
    Write-Host "  Device:           no unique QDLoader 9008 device on $ComPort"
}

if (-not $ExecuteReadback) {
    Write-Host ''
    Write-Host 'Preflight-only mode: no Sahara/Firehose command was sent.'
    exit 0
}

if ($qdloader.Count -ne 1) {
    throw "Expected exactly one USB VID_05C6&PID_9008 device on $ComPort, found $($qdloader.Count)"
}

$action = "read $($commands.Count) critical partitions ($expectedTotal bytes) through EDL; no write/erase command"
if (-not $PSCmdlet.ShouldProcess("TB371FC QDLoader on $ComPort", $action)) {
    exit 0
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Push-Location $OutputDir
try {
    Write-Host 'Uploading the verified stock Firehose programmer...'
    & $Sahara -p "\\.\$ComPort" -s "13:$Firehose"
    if ($LASTEXITCODE -ne 0) {
        throw "QSaharaServer failed with exit code $LASTEXITCODE"
    }

    Write-Host 'Reading critical partitions...'
    $xmlDir = Split-Path -Parent $ReadbackXml
    $xmlName = Split-Path -Leaf $ReadbackXml
    & $Loader "--port=\\.\$ComPort" "--search_path=$xmlDir" "--sendxml=$xmlName" `
        "--mainoutputdir=$OutputDir" --memoryname=ufs --showpercentagecomplete `
        --zlpawarehost=1 --noprompt
    if ($LASTEXITCODE -ne 0) {
        throw "fh_loader readback failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$verified = @()
foreach ($entry in $inventoryData) {
    $path = Join-Path $OutputDir ([string]$entry.filename)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Readback file is missing: $path"
    }
    $actualSize = (Get-Item -LiteralPath $path).Length
    if ($actualSize -ne [int64]$entry.expected_bytes) {
        throw "Readback size mismatch for $path`: expected $($entry.expected_bytes), got $actualSize"
    }
    $record = [ordered]@{}
    foreach ($property in $entry.PSObject.Properties) {
        $record[$property.Name] = $property.Value
    }
    $record['sha256'] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    $verified += [pscustomobject]$record
}

$manifest = [ordered]@{
    format = 'tb371fc-edl-readback-v1'
    created_utc = [DateTime]::UtcNow.ToString('o')
    device = $qdloader[0].PNPDeviceID
    com_port = $ComPort
    files = $verified
}
$manifestPath = Join-Path $OutputDir 'sha256-manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $manifestPath
Write-Host "READBACK VERIFIED: $($verified.Count) files"
Write-Host "Manifest: $manifestPath"

Push-Location $OutputDir
try {
    Write-Host 'Requesting a normal reset from Firehose...'
    & $Loader "--port=\\.\$ComPort" --reset --memoryname=ufs --noprompt
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Firehose reset failed. Hold Power and Volume Down until the tablet restarts.'
    }
} finally {
    Pop-Location
}
