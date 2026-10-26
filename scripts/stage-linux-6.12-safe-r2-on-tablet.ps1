#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Address = '169.254.77.2',
    [ValidateRange(1, 65535)]
    [int]$Port = 2222,
    [string]$IdentityFile = ''
)

$ErrorActionPreference = 'Stop'
$package = 'D:\TB371FC-builds\linux-6.12.30-tb371fc-safe-r2'
if (-not $IdentityFile) {
    $IdentityFile = Join-Path $PSScriptRoot '..\artifacts\tb371fc-development-ssh\id_ed25519'
}
$identity = (Resolve-Path -LiteralPath $IdentityFile).Path
$knownHosts = Join-Path $env:TEMP 'tb371fc-development-known-hosts'
$stage = '/tmp/tb371fc-linux-6.12-safe-r2'
$files = @(
    @{ Source = Join-Path $package 'Image'; Target = 'Image' },
    @{ Source = Join-Path $package 'dtb\qcom\sm8250-lenovo-tb371fc-archsafe-microsd.dtb'; Target = 'sm8250-lenovo-tb371fc-archsafe-microsd.dtb' },
    @{ Source = Join-Path $package 'initramfs-6.12-arch-development.cpio.gz'; Target = 'initramfs-6.12-arch-development.cpio.gz' },
    @{ Source = Join-Path $package 'modules-6.12.30-tb371fc-arch612-safe+.tar.gz'; Target = 'modules.tar.gz' },
    @{ Source = 'D:\TB371FC-builds\linux-6.12.30-tb371fc-safe-r2-runtime\kexec-failsafe-bootloader-watchdog-v56.3-r3.3.ko'; Target = 'kexec-failsafe-bootloader-watchdog-v56.3-r3.3.ko' },
    @{ Source = Join-Path $PSScriptRoot 'load-linux-6.12-safe-r2.sh'; Target = 'load-linux-6.12-safe-r2.sh' },
    @{ Source = Join-Path $PSScriptRoot 'execute-linux-6.12-safe-r2-failsafe.sh'; Target = 'execute-linux-6.12-safe-r2-failsafe.sh' },
    @{ Source = Join-Path $PSScriptRoot 'install-linux-6.12-safe-r2-on-tablet.sh'; Target = 'install-linux-6.12-safe-r2-on-tablet.sh' }
)

if (-not (Test-NetConnection -ComputerName $Address -Port $Port -InformationLevel Quiet)) {
    throw "TB371FC SSH is not reachable at $Address`:$Port"
}

$sshOptions = @('-i', $identity, '-p', "$Port", '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', "UserKnownHostsFile=$knownHosts")
& ssh.exe @sshOptions "root@$Address" "rm -rf -- '$stage'; mkdir -p '$stage'"
if ($LASTEXITCODE -ne 0) { throw 'Failed to create tablet staging directory' }

foreach ($file in $files) {
    $source = (Resolve-Path -LiteralPath $file.Source).Path
    & scp.exe -i $identity -P $Port -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$knownHosts" -- $source "root@$Address`:$stage/$($file.Target)"
    if ($LASTEXITCODE -ne 0) { throw "Failed to transfer $source" }
}

& ssh.exe @sshOptions "root@$Address" "chmod 0755 '$stage/'*.sh; '$stage/install-linux-6.12-safe-r2-on-tablet.sh'"
if ($LASTEXITCODE -ne 0) { throw 'Linux 6.12 safe runtime installation failed' }
Write-Host 'Linux 6.12 safe r2 is staged and verified; it has NOT been executed.'
