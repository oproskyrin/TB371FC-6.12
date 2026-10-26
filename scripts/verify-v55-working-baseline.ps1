#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
$BuildDir = 'D:\TB371FC-builds'

$Files = @(
    [pscustomobject]@{
        Name = 'V55 recovery image'
        Path = Join-Path $BuildDir 'arch-development-loader-v55-community-simplefb-arch-loopback-ssh\tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img'
        Size = 104857600
        Hash = 'c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5'
    }
    [pscustomobject]@{
        Name = 'V55 initramfs'
        Path = Join-Path $BuildDir 'arch-development-loader-v55-community-simplefb-arch-loopback-ssh\tb371fc-v55-simplefb-arch-loopback-ssh.cpio.gz'
        Size = 21840789
        Hash = 'b634b92d265fc73f4770e9595055f9a101acd28383b96f75a07bce0a56008e06'
    }
    [pscustomobject]@{
        Name = 'Stock recovery_b backup'
        Path = Join-Path $ProjectDir 'artifacts\device-backup\lun0-recovery_b.bin'
        Size = 104857600
        Hash = '94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668'
    }
    [pscustomobject]@{
        Name = 'Stock signed vbmeta_b backup'
        Path = Join-Path $ProjectDir 'artifacts\device-backup\lun4-vbmeta_b.bin'
        Size = 65536
        Hash = '58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05'
    }
    [pscustomobject]@{
        Name = 'Temporary test vbmeta_b'
        Path = Join-Path $ProjectDir 'artifacts\tb371fc-vbmeta_b-verification-disabled.img'
        Size = 65536
        Hash = '5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169'
    }
)

foreach ($Expected in $Files) {
    $Item = Get-Item -LiteralPath $Expected.Path -ErrorAction Stop
    if ($Item.Length -ne $Expected.Size) {
        throw "$($Expected.Name) size mismatch: $($Item.Length), expected $($Expected.Size)"
    }
    $ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Item.FullName).Hash.ToLowerInvariant()
    if ($ActualHash -ne $Expected.Hash) {
        throw "$($Expected.Name) SHA-256 mismatch: $ActualHash"
    }
    Write-Host "OK: $($Expected.Name)"
}

Write-Host 'V55 working baseline and exact Android rollback anchors are intact.'
Write-Host 'Offline validation only: no device query, reboot, flash or write was performed.'

