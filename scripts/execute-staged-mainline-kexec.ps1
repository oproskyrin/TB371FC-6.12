#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [int]$InterfaceIndex = 46,
    [int]$ShellPort = 2323,
    [string]$TabletAddress = '169.254.77.2'
)

$ErrorActionPreference = 'Stop'
if (-not $PSCmdlet.ShouldProcess($TabletAddress, 'execute staged mainline kernel with kexec')) {
    return
}
$execute = 'if [ -x /bin/execute-mainline-kexec ]; then /bin/execute-mainline-kexec; else /run/tb371fc-rescue/execute-mainline-kexec; fi'
$executeParameters = @{
    InterfaceIndex = $InterfaceIndex
    TabletAddress = $TabletAddress
    Port = $ShellPort
    Command = $execute
    TimeoutMilliseconds = 10000
}
& "$PSScriptRoot\invoke-diagnostic-ncm.ps1" @executeParameters
