#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Address = '169.254.77.2',
    [ValidateRange(1, 65535)] [int]$Port = 2222,
    [string]$IdentityFile = ''
)

$ErrorActionPreference = 'Stop'
$package = 'D:\TB371FC-builds\linux-6.12.30-tb371fc-arch612-desktop+-desktop-r4'
if (-not $IdentityFile) {
    $IdentityFile = Join-Path $PSScriptRoot '..\artifacts\tb371fc-development-ssh\id_ed25519'
}
$identity = (Resolve-Path -LiteralPath $IdentityFile).Path
$knownHosts = Join-Path $env:TEMP 'tb371fc-development-known-hosts'
$stage = '/tmp/tb371fc-linux-6.12-desktop-gpu-r4'
$files = @(
    @{ Source = Join-Path $package 'Image'; Target = 'Image' },
    @{ Source = Join-Path $package 'dtb\qcom\sm8250-lenovo-tb371fc-archsafe-microsd.dtb'; Target = 'board.dtb' },
    @{ Source = Join-Path $package 'initramfs-6.12-arch-development.cpio.gz'; Target = 'initramfs.cpio.gz' },
    @{ Source = Join-Path $package 'modules-6.12.30-tb371fc-arch612-desktop+.tar.gz'; Target = 'modules.tar.gz' },
    @{ Source = Join-Path $package 'firmware-a650-6.12.30-tb371fc-arch612-desktop+.tar.gz'; Target = 'firmware.tar.gz' },
    @{ Source = 'D:\TB371FC-builds\linux-6.12.30-tb371fc-safe-r2-runtime\kexec-failsafe-bootloader-watchdog-v56.3-r3.3.ko'; Target = 'watchdog-v56.3.ko' },
    @{ Source = 'D:\TB371FC-builds\tb371fc-v56-5-runtime-stage-r3-graphics\kexec-failsafe-bootloader-watchdog-v56.5.ko'; Target = 'watchdog-v56.5.ko' },
    @{ Source = Join-Path $PSScriptRoot 'load-linux-6.12-desktop-gpu-r4.sh'; Target = 'load.sh' },
    @{ Source = Join-Path $PSScriptRoot 'execute-linux-6.12-desktop-gpu-r4-failsafe.sh'; Target = 'execute.sh' },
    @{ Source = Join-Path $PSScriptRoot 'capture-linux-6.12-gpu.sh'; Target = 'capture-gpu.sh' },
    @{ Source = Join-Path $PSScriptRoot 'install-linux-6.12-desktop-gpu-r4-on-tablet.sh'; Target = 'install.sh' }
)

foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) { throw "Missing staged input: $($file.Source)" }
}
if (-not (Test-NetConnection -ComputerName $Address -Port $Port -InformationLevel Quiet)) {
    throw "TB371FC SSH is not reachable at $Address`:$Port"
}

$ssh = @('-i', $identity, '-p', "$Port", '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', "UserKnownHostsFile=$knownHosts")
& ssh.exe @ssh "root@$Address" "rm -rf -- '$stage'; mkdir -p '$stage'"
if ($LASTEXITCODE -ne 0) { throw 'Failed to create the tablet staging directory' }
foreach ($file in $files) {
    $source = (Resolve-Path -LiteralPath $file.Source).Path
    & scp.exe -i $identity -P $Port -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$knownHosts" -- $source "root@$Address`:$stage/$($file.Target)"
    if ($LASTEXITCODE -ne 0) { throw "Failed to transfer $source" }
}
& ssh.exe @ssh "root@$Address" "chmod 0755 '$stage/'*.sh; '$stage/install.sh'"
if ($LASTEXITCODE -ne 0) { throw 'Linux 6.12 desktop GPU runtime installation failed' }
Write-Host 'Linux 6.12 desktop GPU r4 is staged and verified; it has NOT been executed.'
