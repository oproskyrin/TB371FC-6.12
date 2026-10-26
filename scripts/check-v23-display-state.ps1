#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TabletAddress = '169.254.77.2',
    [ValidateRange(1, 65535)]
    [int]$Port = 2222,
    [string]$BindAddress = '169.254.97.192',
    [string]$KeyPath,
    [ValidateRange(1, 30)]
    [int]$ObserveSeconds = 3
)

$ErrorActionPreference = 'Stop'
if (-not $KeyPath) {
    $KeyPath = Join-Path $PSScriptRoot '..\artifacts\tb371fc-development-ssh\id_ed25519'
}
$key = (Resolve-Path -LiteralPath $KeyPath).Path
$ssh = (Get-Command ssh.exe -ErrorAction Stop).Source
$commonArgs = @(
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    '-o', 'StrictHostKeyChecking=no',
    '-b', $BindAddress,
    '-i', $key,
    '-p', $Port,
    "root@$TabletAddress"
)

function Invoke-TabletRead {
    param([Parameter(Mandatory = $true)][string]$Command)

    $result = & $ssh @commonArgs $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Tablet SSH command failed ($LASTEXITCODE): $result"
    }
    return ($result | Out-String).TrimEnd()
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not $Text.Contains($Needle)) {
        throw "$Description is not proven: missing '$Needle'"
    }
}

$panelDebug = '/sys/kernel/debug/qcom,mdss_dsi_panel_spinel_tianma_nt36532_dsc_3k_video'
$kmsLog = Invoke-TabletRead 'cat /var/log/tb371fc-kms-smoketest.log'
$processes = Invoke-TabletRead 'ps -ef'
$dsi0 = Invoke-TabletRead "timeout 5 cat $panelDebug/dsi-ctrl-0/state_info"
$dsi1 = Invoke-TabletRead "timeout 5 cat $panelDebug/dsi-ctrl-1/state_info"
$dsi0Registers = Invoke-TabletRead "timeout 8 cat $panelDebug/dsi-ctrl-0/reg_dump"
$dsi1Registers = Invoke-TabletRead "timeout 8 cat $panelDebug/dsi-ctrl-1/reg_dump"
$drmState = Invoke-TabletRead 'timeout 8 cat /sys/kernel/debug/dri/0/state'
$framebuffers = Invoke-TabletRead 'timeout 8 cat /sys/kernel/debug/dri/0/framebuffer'
$encoderA = Invoke-TabletRead 'for f in /sys/kernel/debug/dri/0/encoder*/status; do timeout 3 cat $f; done'
Start-Sleep -Seconds $ObserveSeconds
$encoderB = Invoke-TabletRead 'for f in /sys/kernel/debug/dri/0/encoder*/status; do timeout 3 cat $f; done'
$uptime = Invoke-TabletRead 'cat /proc/uptime'
$usbOnline = Invoke-TabletRead 'cat /sys/class/power_supply/usb/online'

Assert-Contains $kmsLog 'HANDOFF_OK: both DSI video engines are on' 'gated handoff'
Assert-Contains $kmsLog 'KMS_CYCLE: enabling a freshly initialized display pipeline' 'cold re-enable'
Assert-Contains $kmsLog 'KMS_OK: green checkerboard is active; holding 86400 seconds' 'held framebuffer'
Assert-Contains $processes '/run/tb371fc-rescue/drm-kms-smoketest 120 cycle 86400' 'KMS holder process'
Assert-Contains $dsi0 'VIDEO_ENGINE = ON' 'DSI0 video engine'
Assert-Contains $dsi1 'VIDEO_ENGINE = ON' 'DSI1 video engine'
Assert-Contains $dsi0 'PIXEL_CLK = 188333333' 'DSI0 pixel clock'
Assert-Contains $dsi1 'PIXEL_CLK = 188333333' 'DSI1 pixel clock'
Assert-Contains $dsi0Registers 'DSI_ACK_ERR_STATUS            : 0x00000000' 'DSI0 ACK status'
Assert-Contains $dsi1Registers 'DSI_ACK_ERR_STATUS            : 0x00000000' 'DSI1 ACK status'
Assert-Contains $dsi0Registers 'DSI_TIMEOUT_STATUS            : 0x00000000' 'DSI0 timeout status'
Assert-Contains $dsi1Registers 'DSI_TIMEOUT_STATUS            : 0x00000000' 'DSI1 timeout status'
Assert-Contains $dsi0Registers 'DSI_LANE_STATUS               : 0x00001f00' 'DSI0 lane status'
Assert-Contains $dsi1Registers 'DSI_LANE_STATUS               : 0x00001f00' 'DSI1 lane status'
Assert-Contains $drmState 'active=1' 'active DRM CRTC'
Assert-Contains $drmState '2944x1840x120' '120 Hz native mode'
Assert-Contains $drmState 'fb=231' 'active v23 framebuffer'
Assert-Contains $framebuffers 'framebuffer[231]:' 'v23 framebuffer object'
Assert-Contains $framebuffers 'format=XR24 little-endian' 'v23 framebuffer format'
Assert-Contains $framebuffers 'size=2944x1840' 'v23 framebuffer dimensions'
Assert-Contains $framebuffers 'pitch[0]=11776' 'v23 framebuffer pitch'
Assert-Contains $framebuffers 'size=21667840' 'v23 framebuffer allocation size'
Assert-Contains $encoderA 'intf:1' 'first physical interface'
Assert-Contains $encoderA 'intf:2' 'second physical interface'

if ($encoderA -ne $encoderB) {
    throw "Encoder counters changed during the $ObserveSeconds-second stability window.`nBefore:`n$encoderA`nAfter:`n$encoderB"
}
if ($usbOnline.Trim() -ne '1') {
    throw "USB power/network link is not online: '$usbOnline'"
}

[pscustomobject]@{
    Result = 'PASS'
    NativeMode = '2944x1840@120'
    Dsi0VideoEngine = 'ON'
    Dsi1VideoEngine = 'ON'
    EncoderCountersStableSeconds = $ObserveSeconds
    UsbOnline = $usbOnline.Trim()
    DsiAckErrors = 0
    DsiTimeouts = 0
    ActiveFramebuffer = '231 XR24 2944x1840 pitch=11776 size=21667840'
    UptimeSeconds = (($uptime -split '\s+')[0])
    PhysicalPanelObservation = 'PENDING'
}
