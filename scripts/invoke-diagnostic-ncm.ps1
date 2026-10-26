#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$InterfaceIndex = 46,
    [string]$TabletAddress = '169.254.77.2',
    [int]$Port = 2323,
    [string]$Command = 'uname -a; cat /proc/cmdline; dmesg | tail -n 120; echo TB371FC_COMMAND_DONE',
    [int]$TimeoutMilliseconds = 5000,
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'
$source = Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '0.*' } |
    Select-Object -First 1
if (-not $source) {
    throw "No IPv4 address exists on interface $InterfaceIndex"
}

$outputStream = $null
if ($OutputFile) {
    $fullOutputPath = [IO.Path]::GetFullPath($OutputFile)
    $parent = Split-Path -Parent $fullOutputPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Output directory does not exist: $parent"
    }
    $outputStream = [IO.File]::Open(
        $fullOutputPath,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::Read
    )
}

$socket = New-Object System.Net.Sockets.Socket(
    [System.Net.Sockets.AddressFamily]::InterNetwork,
    [System.Net.Sockets.SocketType]::Stream,
    [System.Net.Sockets.ProtocolType]::Tcp
)
try {
    # IP_UNICAST_IF is a network-byte-order DWORD on Windows. It constrains
    # this one diagnostic connection without changing the host routing table.
    $networkOrderIndex = [System.Net.IPAddress]::HostToNetworkOrder($InterfaceIndex)
    $socket.SetSocketOption(
        [System.Net.Sockets.SocketOptionLevel]::IP,
        [System.Net.Sockets.SocketOptionName]31,
        [int]$networkOrderIndex
    )
    $socket.SetSocketOption(
        [System.Net.Sockets.SocketOptionLevel]::Socket,
        [System.Net.Sockets.SocketOptionName]::DontRoute,
        $true
    )
    $socket.Bind((New-Object System.Net.IPEndPoint(
        [System.Net.IPAddress]::Parse($source.IPAddress), 0
    )))
    $connect = $socket.BeginConnect($TabletAddress, $Port, $null, $null)
    if (-not $connect.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) {
        throw "Timed out connecting to ${TabletAddress}:$Port on interface $InterfaceIndex"
    }
    $socket.EndConnect($connect)
    $socket.ReceiveTimeout = $TimeoutMilliseconds
    $socket.SendTimeout = $TimeoutMilliseconds

    $stream = New-Object System.Net.Sockets.NetworkStream($socket, $false)
    $payload = [Text.Encoding]::ASCII.GetBytes("$Command`r`n")
    $stream.Write($payload, 0, $payload.Length)
    $stream.Flush()

    $buffer = New-Object byte[] 65536
    $result = New-Object System.IO.MemoryStream
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($stream.DataAvailable) {
            $count = $stream.Read($buffer, 0, $buffer.Length)
            if ($count -le 0) { break }
            $result.Write($buffer, 0, $count)
            if ($outputStream) {
                $outputStream.Write($buffer, 0, $count)
                $outputStream.Flush()
            }
            $text = [Text.Encoding]::ASCII.GetString($result.ToArray())
            if ($text.Contains('TB371FC_COMMAND_DONE')) { break }
        } else {
            Start-Sleep -Milliseconds 50
        }
    }
    $decoded = [Text.Encoding]::ASCII.GetString($result.ToArray())
    if ($outputStream) {
        Write-Host "Diagnostic response saved: $fullOutputPath"
    }
    $decoded
} finally {
    if ($stream) { $stream.Dispose() }
    if ($outputStream) { $outputStream.Dispose() }
    $socket.Dispose()
}
