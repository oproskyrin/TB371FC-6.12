#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TabletAddress = '169.254.77.2',
    [int]$RescuePort = 2323,
    [int]$SshPort = 2222,
    [ValidateRange(10, 180)]
    [int]$WaitSeconds = 120,
    [string]$IdentityFile = (Join-Path $PSScriptRoot '..\artifacts\tb371fc-development-ssh\id_ed25519')
)

$ErrorActionPreference = 'Stop'
$deadline = (Get-Date).AddSeconds($WaitSeconds)
$adapter = $null
while ((Get-Date) -lt $deadline) {
    $adapter = Get-NetAdapter -IncludeHidden | Where-Object {
        $_.Status -eq 'Up' -and
        ($_.InterfaceDescription -match 'NCM|UsbNcm' -or $_.Name -match 'NCM')
    } | Sort-Object ifIndex | Select-Object -First 1
    if ($adapter) { break }
    Start-Sleep -Seconds 1
}
if (-not $adapter) {
    throw 'TB371FC USB NCM adapter did not appear.'
}

$source = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '0.*' } | Select-Object -First 1
if (-not $source) {
    throw "NCM adapter $($adapter.ifIndex) has no IPv4 address. Assign 169.254.77.1/16 as Administrator."
}

$rescueReady = $false
$sshReady = $false
while ((Get-Date) -lt $deadline) {
    $rescueReady = Test-NetConnection -ComputerName $TabletAddress -Port $RescuePort `
        -InformationLevel Quiet -WarningAction SilentlyContinue
    $sshReady = Test-NetConnection -ComputerName $TabletAddress -Port $SshPort `
        -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($rescueReady -or $sshReady) { break }
    Start-Sleep -Seconds 1
}

[pscustomobject]@{
    InterfaceIndex = $adapter.ifIndex
    InterfaceName = $adapter.Name
    HostAddress = $source.IPAddress
    RescueReady = $rescueReady
    SshReady = $sshReady
}

if ($sshReady) {
    & (Join-Path $PSScriptRoot 'connect-arch-development.ps1') `
        -Address $TabletAddress -Port $SshPort -IdentityFile $IdentityFile
    exit $LASTEXITCODE
}

if ($rescueReady) {
    Write-Host "Arch SSH is not ready yet; rescue shell is available on ${TabletAddress}:$RescuePort."
    exit 0
}

throw 'Neither the V50 rescue shell nor Arch SSH became reachable.'
