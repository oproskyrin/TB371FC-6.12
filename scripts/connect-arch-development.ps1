#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Address = '169.254.77.2',
    [ValidateRange(1, 65535)]
    [int]$Port = 2222,
    [string]$IdentityFile = (Join-Path $PSScriptRoot '..\artifacts\tb371fc-development-ssh\id_ed25519')
)

$ErrorActionPreference = 'Stop'
$identity = (Resolve-Path -LiteralPath $IdentityFile).Path
$knownHosts = Join-Path (Split-Path -Parent $identity) 'known_hosts'
$expectedFingerprint = 'SHA256:4XB7QNE9Gre04cjQN7S27zpoFYrXJN9FvH1mXnZent4'
$actualFingerprint = (& ssh-keygen.exe -lf "$identity.pub") | Out-String
if ($LASTEXITCODE -ne 0 -or $actualFingerprint -notmatch [regex]::Escape($expectedFingerprint)) {
    throw 'Unexpected TB371FC development SSH identity key'
}

if (-not (Test-NetConnection -ComputerName $Address -Port $Port -InformationLevel Quiet)) {
    throw "TB371FC SSH is not reachable at $Address`:$Port"
}

& ssh.exe -i $identity -p $Port `
    -o IdentitiesOnly=yes `
    -o StrictHostKeyChecking=accept-new `
    -o "UserKnownHostsFile=$knownHosts" `
    "root@$Address"
exit $LASTEXITCODE
