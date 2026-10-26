# Reboot the running Linux 6.12 over SSH and keep the tablet in the 4.19 console.
# R179: clean reboot (systemd stops services and unmounts the persistent root; "reboot -f" left the
# ext4 journal to be replayed on every next boot). Wait until Linux has really gone (its own USB
# ACM port could otherwise be mistaken for the console), then hold the console.
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
cmd /c "ssh -p2222 -i artifacts/tb371fc-development-ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR -o ConnectTimeout=8 root@172.31.77.2 `"sync; (sleep 1; systemctl reboot) >/dev/null 2>&1 &`" 2>&1"
$end = (Get-Date).AddSeconds(120)
do {
    $up = Test-NetConnection 172.31.77.2 -Port 2222 -InformationLevel Quiet -WarningAction SilentlyContinue
} while ($up -and (Get-Date) -lt $end)
# graceful shutdown may hang on a service: fall back to the old forced reboot
if ($up) {
    cmd /c "ssh -p2222 -i artifacts/tb371fc-development-ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR -o ConnectTimeout=8 root@172.31.77.2 `"sync; (sleep 1; systemctl reboot -f) >/dev/null 2>&1 &`" 2>&1"
}
$t = Get-Date; while (((Get-Date) - $t).TotalSeconds -lt 8) {}
& .\scripts\tb371fc-hold-console.ps1
