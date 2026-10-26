param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$fbWidth = 2944
$fbHeight = 1840
$fbStride = 11776
$fbBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $InputPath).Path)
if ($fbBytes.Length -ne $fbStride * $fbHeight) { throw 'Unexpected framebuffer length' }
$fbBitmap = [System.Drawing.Bitmap]::new($fbWidth, $fbHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
try {
    $fbRect = [System.Drawing.Rectangle]::new(0, 0, $fbWidth, $fbHeight)
    $fbLock = $fbBitmap.LockBits($fbRect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
    try {
        if ($fbLock.Stride -ne $fbStride) { throw 'Unexpected bitmap stride' }
        [System.Runtime.InteropServices.Marshal]::Copy($fbBytes, 0, $fbLock.Scan0, $fbBytes.Length)
    } finally { $fbBitmap.UnlockBits($fbLock) }
    $fbBitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally { $fbBitmap.Dispose() }
