#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$InterfaceIndex,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\diagnostics\remote-session')
)

$ErrorActionPreference = 'Stop'
$invokeScript = Join-Path $PSScriptRoot 'invoke-diagnostic-ncm.ps1'

if (-not $InterfaceIndex) {
    $adapter = Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and
        ($_.InterfaceDescription -match 'NCM|UsbNcm' -or $_.Name -match 'NCM')
    } | Select-Object -First 1
    if (-not $adapter) {
        throw 'No active USB NCM adapter was found'
    }
    $InterfaceIndex = $adapter.ifIndex
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $resolvedOutput) {
    if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Container)) {
        throw "Output path is not a directory: $resolvedOutput"
    }
} else {
    [void](New-Item -ItemType Directory -Path $resolvedOutput)
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$common = @{
    InterfaceIndex = $InterfaceIndex
    TimeoutMilliseconds = 45000
}

& $invokeScript @common `
    -Command 'collect-hardware-snapshot /run/baseline.txt; cat /run/baseline.txt; echo TB371FC_COMMAND_DONE' `
    -OutputFile (Join-Path $resolvedOutput "baseline-$stamp.txt") | Out-Null

& $invokeScript @common `
    -Command 'start-qrtr-diagnostics; sleep 2; echo ==qrtr-ns==; cat /run/qrtr-ns.log; echo ==qrtr-lookup==; cat /run/qrtr-lookup.log; echo TB371FC_COMMAND_DONE' `
    -OutputFile (Join-Path $resolvedOutput "qrtr-start-$stamp.txt") | Out-Null

& $invokeScript @common `
    -Command 'collect-hardware-snapshot /run/post-qrtr.txt; cat /run/post-qrtr.txt; echo TB371FC_COMMAND_DONE' `
    -OutputFile (Join-Path $resolvedOutput "post-qrtr-$stamp.txt") | Out-Null

& $invokeScript @common `
    -Command 'dmesg; echo TB371FC_COMMAND_DONE' `
    -OutputFile (Join-Path $resolvedOutput "dmesg-$stamp.txt") | Out-Null

Write-Host "Extended read-only diagnostics completed: $resolvedOutput"
Write-Host 'WLAN was not activated by this script.'
