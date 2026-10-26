$ErrorActionPreference = 'Stop'

$fastboot = '<platform-tools>\fastboot.exe'
$deadline = (Get-Date).AddMinutes(4)

while ((Get-Date) -lt $deadline) {
    $devices = & $fastboot devices 2>$null
    if ($LASTEXITCODE -eq 0 -and $devices) {
        "$(Get-Date -Format o) fastboot detected: $devices"
        & $fastboot reboot recovery
        if ($LASTEXITCODE -ne 0) {
            throw "fastboot reboot recovery failed with exit code $LASTEXITCODE"
        }
        "$(Get-Date -Format o) recovery reboot requested"
        exit 0
    }
    Start-Sleep -Milliseconds 500
}

throw 'Timed out waiting for diag39-r2 watchdog fastboot fallback'
