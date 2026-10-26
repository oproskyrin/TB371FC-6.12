#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$InterfaceIndex = 46,
    [int]$ShellPort = 2323,
    [string]$TabletAddress = '169.254.77.2'
)

$ErrorActionPreference = 'Stop'
$package = 'D:\TB371FC-builds\mainline-7.1.7-native-display-longwrite-v3'
$payloads = @(
    @{ Path = Join-Path $package 'Image-7.1.7-tb371fc-native-display-longwrite-v3'; Port = 2325; Sha256 = '0afcf25e382deafdc277d9fa10ffb8b62474fcbea297bda7c40d5778b36b6170' },
    @{ Path = Join-Path $package 'sm8250-lenovo-tb371fc-display-test.dtb'; Port = 2326; Sha256 = 'd41d9d67366c0a38a83317baf4b7d8c15854b05fd9e10947f45714d89808d9a9' },
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
    $sendParameters = @{
        Path = $payload.Path
        InterfaceIndex = $InterfaceIndex
        TabletAddress = $TabletAddress
        Port = $payload.Port
        TimeoutMilliseconds = 120000
    }
    & "$PSScriptRoot\send-diagnostic-ncm-file.ps1" @sendParameters
}

Start-Sleep -Seconds 1
$load = 'if [ -x /bin/load-mainline-kexec ]; then /bin/load-mainline-kexec; else /run/tb371fc-rescue/load-mainline-kexec; fi; echo TB371FC_COMMAND_DONE'
$loadParameters = @{
    InterfaceIndex = $InterfaceIndex
    TabletAddress = $TabletAddress
    Port = $ShellPort
    Command = $load
    TimeoutMilliseconds = 120000
}
& "$PSScriptRoot\invoke-diagnostic-ncm.ps1" @loadParameters

Write-Host 'Mainline payload is staged and loaded only. It has NOT been executed.'
