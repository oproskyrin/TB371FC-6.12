param(
    [string]$Serial = $env:TB371FC_SERIAL,
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb is not available in PATH"
}

$deviceLine = (& adb devices) | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+" }
if (-not $deviceLine) {
    throw "Tablet $Serial is not visible to adb"
}
if ($deviceLine -notmatch "\sdevice$") {
    throw "Tablet $Serial is not authorized: $deviceLine"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDirectory = Join-Path $PSScriptRoot "..\diagnostics\hardware-$Serial-$stamp"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Save-AdbOutput {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string[]]$AdbArguments
    )

    $path = Join-Path $OutputDirectory $Name
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & adb -s $Serial @AdbArguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    @(
        "# adb -s $Serial $($AdbArguments -join ' ')"
        "# exit-code: $exitCode"
        $output
    ) | Set-Content -LiteralPath $path -Encoding utf8
}

function Save-ShellOutput {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Command
    )

    # adb rebuilds all arguments following "shell" into one remote command.
    # Base64 avoids host/adb/Android quoting changes for pipes, loops and
    # multiline snippets without creating a temporary file on the tablet.
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Command)
    $encoded = [System.Convert]::ToBase64String($bytes)
    Save-AdbOutput $Name @("shell", "echo $encoded | base64 -d | sh")
}

Save-AdbOutput "getprop.txt" @("shell", "getprop")
Save-ShellOutput "kernel-and-boot.txt" @'
uname -a
cat /proc/version
printf '\n--- cmdline ---\n'
cat /proc/cmdline
printf '\n--- bootconfig ---\n'
cat /proc/bootconfig 2>&1
printf '\n--- verified boot ---\n'
getprop ro.boot.slot_suffix
getprop ro.boot.flash.locked
getprop ro.boot.verifiedbootstate
getprop ro.boot.vbmeta.device_state
'@
Save-ShellOutput "cpu-memory.txt" @'
cat /proc/cpuinfo
printf '\n--- meminfo ---\n'
cat /proc/meminfo
printf '\n--- devfreq ---\n'
find /sys/class/devfreq -maxdepth 2 -type f \( -name name -o -name available_frequencies -o -name cur_freq \) -print -exec cat {} \; 2>/dev/null
'@
Save-ShellOutput "partitions-and-filesystems.txt" @'
cat /proc/partitions
printf '\n--- by-name ---\n'
ls -la /dev/block/by-name 2>&1
printf '\n--- mounts ---\n'
cat /proc/mounts
'@
Save-ShellOutput "device-tree-files.txt" @'
find /proc/device-tree -maxdepth 6 -type f -print 2>&1 | sort
'@
Save-ShellOutput "device-tree-text.txt" @'
for f in /proc/device-tree/model /proc/device-tree/compatible /proc/device-tree/chosen/bootargs; do printf '\n--- %s ---\n' "$f"; tr '\000' '\n' < "$f" 2>&1; done
find /proc/device-tree -type f \( -name compatible -o -name label -o -name status \) 2>/dev/null | sort | while read f; do printf '\n%s: ' "$f"; tr '\000' ' ' < "$f"; done
'@
Save-ShellOutput "loaded-modules.txt" @'
cat /proc/modules
printf '\n--- module parameters ---\n'
find /sys/module -maxdepth 2 -type d -name parameters -print 2>/dev/null | sort
'@
Save-AdbOutput "input-devices.txt" @("shell", "cat", "/proc/bus/input/devices")
Save-AdbOutput "getevent-capabilities.txt" @("shell", "getevent", "-pl")
Save-ShellOutput "hid-and-touch-sysfs.txt" @'
find /sys/bus/hid/devices /sys/class/input /sys/bus/spi/devices /sys/bus/i2c/devices -maxdepth 3 \( -type l -o -type f \) 2>/dev/null | sort
'@
Save-AdbOutput "display-service.txt" @("shell", "dumpsys", "display")
Save-AdbOutput "surfaceflinger.txt" @("shell", "dumpsys", "SurfaceFlinger")
Save-ShellOutput "display-settings.txt" @'
settings get system peak_refresh_rate
settings get system min_refresh_rate
settings get secure user_refresh_rate
wm size
wm density
find /sys/class/graphics /sys/class/backlight -maxdepth 3 -type f 2>/dev/null | sort
'@
Save-ShellOutput "pci-inventory.txt" @'
for d in /sys/bus/pci/devices/*; do [ -e "$d" ] || continue; echo "--- $d ---"; cat "$d/uevent" 2>/dev/null; done
lspci -nn -k 2>&1
'@
Save-AdbOutput "wifi-service.txt" @("shell", "dumpsys", "wifi")
Save-AdbOutput "bluetooth-service.txt" @("shell", "dumpsys", "bluetooth_manager")
Save-ShellOutput "network-interfaces.txt" @'
ip -details link 2>&1
printf '\n--- rfkill ---\n'
find /sys/class/rfkill -maxdepth 2 -type f -print -exec cat {} \; 2>/dev/null
'@
Save-AdbOutput "usb-service.txt" @("shell", "dumpsys", "usb")
Save-ShellOutput "usb-typec-sysfs.txt" @'
find /sys/class/typec /sys/bus/usb/devices /sys/class/udc -maxdepth 4 \( -type l -o -type f \) 2>/dev/null | sort
printf '\n--- USB devices ---\n'
for d in /sys/bus/usb/devices/*; do [ -f "$d/uevent" ] || continue; echo "--- $d ---"; cat "$d/uevent"; done
'@
Save-AdbOutput "ethernet-service.txt" @("shell", "dumpsys", "ethernet")
Save-AdbOutput "audio-flinger.txt" @("shell", "dumpsys", "media.audio_flinger")
Save-AdbOutput "audio-policy.txt" @("shell", "dumpsys", "media.audio_policy")
Save-ShellOutput "alsa-and-codecs.txt" @'
cat /proc/asound/cards 2>&1
cat /proc/asound/pcm 2>&1
find /sys/kernel/debug/asoc /sys/class/sound -maxdepth 4 \( -type l -o -type f \) 2>/dev/null | sort
'@
Save-AdbOutput "sensor-service.txt" @("shell", "dumpsys", "sensorservice")
Save-ShellOutput "sensors-sysfs.txt" @'
find /sys/class/iio /sys/class/sensors /sys/class/ssc -maxdepth 5 \( -type l -o -type f \) 2>/dev/null | sort
'@
Save-AdbOutput "battery-service.txt" @("shell", "dumpsys", "battery")
Save-ShellOutput "power-thermal.txt" @'
find /sys/class/power_supply -maxdepth 3 -type f -print 2>/dev/null | sort
printf '\n--- thermal zones ---\n'
for z in /sys/class/thermal/thermal_zone*; do [ -e "$z" ] || continue; printf '%s ' "$z"; cat "$z/type" "$z/temp" 2>/dev/null | tr '\n' ' '; echo; done
'@
Save-ShellOutput "firmware-inventory.txt" @'
find /vendor/firmware_mnt /vendor/firmware /odm/firmware -maxdepth 4 -type f 2>/dev/null | sort
'@
Save-ShellOutput "platform-devices.txt" @'
find /sys/bus/platform/devices -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | sort
'@
Save-ShellOutput "interrupts-iomem.txt" @'
cat /proc/interrupts 2>&1
printf '\n--- iomem ---\n'
cat /proc/iomem 2>&1
'@
Save-ShellOutput "security-state.txt" @'
getenforce 2>&1
id
cat /sys/fs/selinux/enforce 2>&1
'@
Save-AdbOutput "dmesg.txt" @("shell", "dmesg")

$manifest = Get-ChildItem -LiteralPath $OutputDirectory -File |
    Sort-Object Name |
    ForEach-Object {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
        "$hash  $($_.Name)"
    }
$manifest | Set-Content -LiteralPath (Join-Path $OutputDirectory "SHA256SUMS") -Encoding ascii

Write-Output "Read-only hardware inventory saved to $OutputDirectory"
