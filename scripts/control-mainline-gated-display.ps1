#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('ValidateOnly', 'WaitAndSnapshot', 'StartTest', 'Status')]
    [string]$Action,

    [ValidateSet(30, 60, 120, 144)]
    [int]$Refresh = 120,

    [ValidateSet('checker', 'red', 'green', 'blue', 'white', 'black', 'flash')]
    [string]$Pattern = 'checker',

    [ValidateRange(10, 600)]
    [int]$HoldSeconds = 120,

    [ValidateRange(15, 180)]
    [int]$WaitSeconds = 90,

    [string]$OutputDirectory,

    [switch]$KmsApproved
)

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
$SerialHelper = Join-Path $PSScriptRoot 'tb371fc-serial-ash.py'
$Payload = 'D:\TB371FC-builds\u-boot-linux-7.1.8-r6-display-gated-payload\tb371fc-linux-7.1.8-display-gated-u-boot.img'
$ExpectedSize = 18898944
$ExpectedHash = '1bb58f5dbcd393dacfa63ed892f62b40ec9f63a889b497286c4f9cea7cf5aa93'
$Python = (Get-Command python.exe).Source

function Assert-LocalInputs {
    $item = Get-Item -LiteralPath $Payload
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToLowerInvariant()
    if ($item.Length -ne $ExpectedSize -or $hash -ne $ExpectedHash) {
        throw 'The gated r6 display payload failed its pinned size/hash check.'
    }
    if (-not (Test-Path -LiteralPath $SerialHelper -PathType Leaf)) {
        throw "Serial command helper is missing: $SerialHelper"
    }
    & $Python -c 'import serial' 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Python pyserial is unavailable.' }
}

function Get-GatedSerialPort {
    return @(Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PNPDeviceID -match '^USB\\VID_1D6B&PID_0104.*\\TB371FC-DIAG' -or
            $_.Name -match 'TB371FC'
        })
}

function Wait-GatedSerialPort {
    $deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
    do {
        $ports = @(Get-GatedSerialPort)
        if ($ports.Count -eq 1) { return $ports[0].DeviceID }
        if ($ports.Count -gt 1) {
            throw "More than one TB371FC diagnostic serial port is present: $($ports.DeviceID -join ', ')"
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "TB371FC-DIAG serial port did not appear within $WaitSeconds seconds."
}

function Invoke-TabletCommand {
    param([string]$Port, [string]$Command, [string]$LogName, [int]$Timeout = 90)
    if (-not $OutputDirectory) {
        $script:OutputDirectory = Join-Path $ProjectDir (
            'diagnostics\mainline-r6-gated-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        [void](New-Item -ItemType Directory -Path $OutputDirectory)
    }
    $log = Join-Path $OutputDirectory $LogName
    & $Python $SerialHelper --port $Port --command $Command --timeout $Timeout 2>&1 |
        Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        throw "Tablet command failed or timed out; partial output: $log"
    }
    Write-Host "Captured: $log"
}

Assert-LocalInputs
if ($Action -eq 'ValidateOnly') {
    Write-Host 'Gated r6 controller verified locally; no device query or modeset was performed.'
    exit 0
}

$port = Wait-GatedSerialPort
Write-Host "TB371FC gated diagnostic serial port: $port"

switch ($Action) {
    'WaitAndSnapshot' {
        Invoke-TabletCommand $port `
            'cat /run/tb371fc-display-probe.txt; echo __LIVE__; snapshot-mainline-display /run/tb371fc-display-host-snapshot.txt' `
            'probe-and-live-snapshot.txt' 120
    }
    'StartTest' {
        if (-not $KmsApproved) {
            throw 'Pass -KmsApproved only while a person is observing the tablet and rollback remains available.'
        }
        Invoke-TabletCommand $port `
            "run-mainline-display-test $Refresh $Pattern $HoldSeconds" `
            'start-test.txt' 20
    }
    'Status' {
        Invoke-TabletCommand $port 'status-mainline-display-test' 'display-status.txt' 120
    }
}

