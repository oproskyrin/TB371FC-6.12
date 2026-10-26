#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$InterfaceIndex = 46,
    [string]$TabletAddress = '169.254.77.2',
    [int]$ShellPort = 2323
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$bridge = 'D:\TB371FC-builds\arch-development-loader-v30-longwrite-kexec-bridge\tb371fc-arch-development-loader-v30-longwrite-kexec-bridge-recovery.img'
$mainline = 'D:\TB371FC-builds\mainline-7.1.7-native-display-longwrite-v3\Image-7.1.7-tb371fc-native-display-longwrite-v3'
$recoveryBackup = Join-Path $project 'artifacts\device-backup\lun0-recovery_b.bin'
$vbmetaBackup = Join-Path $project 'artifacts\device-backup\lun4-vbmeta_b.bin'
$vbmetaTest = Join-Path $project 'artifacts\tb371fc-vbmeta_b-verification-disabled.img'
$expected = @{
    $bridge = 'dc7bd05ce80312e5733b33867740596c83420ec828e1c03d1b0981fa8fc96089'
    $mainline = '0afcf25e382deafdc277d9fa10ffb8b62474fcbea297bda7c40d5778b36b6170'
    $recoveryBackup = '94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668'
    $vbmetaBackup = '58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05'
    $vbmetaTest = '5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169'
}

foreach ($path in $expected.Keys) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing pinned artifact: $path"
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actual -ne $expected[$path]) {
        throw "Pinned artifact hash mismatch: $path expected=$($expected[$path]) actual=$actual"
    }
}

$remote = @'
echo "UNAME=$(uname -a)"
echo "ROOT=$(awk '$2 == "/" { print $1 ":" $3 }' /proc/mounts)"
echo "USB_ONLINE=$(cat /sys/class/power_supply/usb/online 2>/dev/null || echo missing)"
echo "USB_PRESENT=$(cat /sys/class/power_supply/usb/present 2>/dev/null || echo missing)"
echo "DSI_STATUS=$(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null || echo missing)"
echo "DSI_ENABLED=$(cat /sys/class/drm/card0-DSI-1/enabled 2>/dev/null || echo missing)"
test -x /run/tb371fc-rescue/return-to-bootloader && echo RETURN_HELPER=yes || echo RETURN_HELPER=no
test -s /lib/modules/4.19.325-cip134-st18-perf+/extra/reboot-bootloader.ko && echo RETURN_MODULE=yes || echo RETURN_MODULE=no
if grep -qw machine_kexec /proc/kallsyms 2>/dev/null; then echo KEXEC=yes; else echo KEXEC=no; fi
echo TB371FC_COMMAND_DONE
'@

$invoke = Join-Path $PSScriptRoot 'invoke-diagnostic-ncm.ps1'
$response = & $invoke `
    -InterfaceIndex $InterfaceIndex `
    -TabletAddress $TabletAddress `
    -Port $ShellPort `
    -TimeoutMilliseconds 30000 `
    -Command $remote
$text = $response -join "`n"

$required = @(
    'UNAME=Linux tb371fc-arch-loader 4.19.325-cip134-st18-perf+ #1 SMP PREEMPT Wed Aug 12 11:33:09 +05 2026',
    'ROOT=/dev/loop0:ext4',
    'USB_ONLINE=1',
    'USB_PRESENT=1',
    'DSI_STATUS=connected',
    'DSI_ENABLED=enabled',
    'RETURN_HELPER=yes',
    'RETURN_MODULE=yes',
    'KEXEC=no'
)
foreach ($marker in $required) {
    if ($text -notmatch [regex]::Escape($marker)) {
        throw "Linux-to-v30 preflight failed: missing marker '$marker'"
    }
}

Write-Host 'Linux-to-v30 preflight passed.'
Write-Host '  current kernel: exact v27 build'
Write-Host '  Arch root:      /dev/loop0 ext4'
Write-Host '  display:        connected and enabled'
Write-Host '  power:          USB online and present'
Write-Host '  return path:    guarded bootloader helper and module present'
Write-Host '  kexec:          unavailable in v27, v30 bridge required'
Write-Host '  artifacts:      v30, v3 and both Android backups pinned by SHA-256'
Write-Host 'No reboot, partition write or device-state mutation was performed.'
