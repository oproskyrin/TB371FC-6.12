#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$InterfaceIndex = 3,
    [int]$ShellPort = 2323,
    [string]$TabletAddress = '169.254.77.2'
)

$ErrorActionPreference = 'Stop'
$package = 'D:\TB371FC-builds\mainline-7.1.7-native-display-phycfg-v4'
$payloads = @(
    @{ Path = Join-Path $package 'Image-7.1.7-tb371fc-native-display-phycfg-v4'; Port = 2325; Sha256 = 'c21a05263b9271bade98f95b705f676da4c8f543d80e5f2ed503f839448840be' },
    @{ Path = Join-Path $package 'sm8250-lenovo-tb371fc-display-test.dtb'; Port = 2326; Sha256 = '69f68b1a30796986f1676c60faad11a0be8a861278f21e364c6af01eaf18182d' },
    @{ Path = Join-Path $package 'tb371fc-mainline-display-initramfs.cpio.gz'; Port = 2327; Sha256 = '423aeb496f5ff471073d52f444fc269c624055bee813239b8d87409ecf12bd2c' }
)

foreach ($payload in $payloads) {
    if (-not (Test-Path -LiteralPath $payload.Path -PathType Leaf)) {
        throw "Missing payload: $($payload.Path)"
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $payload.Path).Hash.ToLowerInvariant()
    if ($actual -ne $payload.Sha256) {
        throw "SHA-256 mismatch before transfer: $($payload.Path)"
    }
    & "$PSScriptRoot\send-diagnostic-ncm-file.ps1" `
        -Path $payload.Path `
        -InterfaceIndex $InterfaceIndex `
        -TabletAddress $TabletAddress `
        -Port $payload.Port `
        -TimeoutMilliseconds 120000
}

Start-Sleep -Seconds 1
$load = '/run/tb371fc-rescue/load-mainline-kexec; echo TB371FC_COMMAND_DONE'
& "$PSScriptRoot\invoke-diagnostic-ncm.ps1" `
    -InterfaceIndex $InterfaceIndex `
    -TabletAddress $TabletAddress `
    -Port $ShellPort `
    -Command $load `
    -TimeoutMilliseconds 120000

Write-Host 'Mainline PHY-config v4 payload is verified and loaded only; it has not been executed.'
