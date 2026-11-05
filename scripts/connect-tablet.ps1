param([string]$Command = 'uname -r; uptime', [int]$WaitSeconds = 0,
    [string]$Address = '')
$projectRoot = Split-Path -Parent $PSScriptRoot
$key = Join-Path $projectRoot 'artifacts/tb371fc-development-ssh/id_ed25519'
$knownHosts = 'artifacts/tb371fc-development-ssh/known_hosts'
# Pinned key came from the tablet over the existing USB control connection.
$sshOptions = @('-4','-p','2223','-i',$key,'-o','BatchMode=yes','-o','ConnectTimeout=5',
    '-o','ServerAliveInterval=10','-o','ServerAliveCountMax=3',
    '-o','StrictHostKeyChecking=yes','-o',"UserKnownHostsFile=$knownHosts")
# Optional known tablet address if mDNS is temporarily unavailable. Always check
# the same pinned tablet identity; never accept an unknown host key by IP.
if ($Address) { $sshOptions += @('-o','HostKeyAlias=[tb371fc.local]:2223') }
$endpoints = if ($Address) { @($Address) } else { @('tb371fc.local','172.31.77.2') }
$deadline = (Get-Date).AddSeconds($WaitSeconds)
Push-Location $projectRoot
try {
do {
    foreach ($endpoint in $endpoints) {
        & ssh @sshOptions "root@$endpoint" true 2>$null
        if ($LASTEXITCODE -eq 0) {
            # Execute requested command only once, never replay a mutation on retry.
            # Encode to preserve quotes/pipes across Windows PowerShell native argv.
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command + "`n"))
            & ssh @sshOptions "root@$endpoint" "printf %s $encoded | base64 -d | sh"
            exit $LASTEXITCODE
        }
    }
    if ((Get-Date) -ge $deadline) { break }
    Start-Sleep -Seconds 5
} while ($true)
Write-Error 'Tablet not reachable by mDNS Wi-Fi or USB; no remote command executed.'
exit 1
} finally { Pop-Location }
