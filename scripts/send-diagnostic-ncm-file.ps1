#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Path,
    [int]$InterfaceIndex = 46,
    [string]$TabletAddress = '169.254.77.2',
    [int]$Port = 2325,
    [int]$TimeoutMilliseconds = 10000
)

$ErrorActionPreference = 'Stop'
$source = Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '0.*' } | Select-Object -First 1
if (-not $source) { throw "No IPv4 address exists on interface $InterfaceIndex" }
$fullPath = [IO.Path]::GetFullPath($Path)
$input = [IO.File]::OpenRead($fullPath)
$socket = New-Object Net.Sockets.Socket(
    [Net.Sockets.AddressFamily]::InterNetwork,
    [Net.Sockets.SocketType]::Stream,
    [Net.Sockets.ProtocolType]::Tcp
)
try {
    $networkOrderIndex = [Net.IPAddress]::HostToNetworkOrder($InterfaceIndex)
    $socket.SetSocketOption([Net.Sockets.SocketOptionLevel]::IP,
        [Net.Sockets.SocketOptionName]31, [int]$networkOrderIndex)
    $socket.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket,
        [Net.Sockets.SocketOptionName]::DontRoute, $true)
    $socket.Bind((New-Object Net.IPEndPoint([Net.IPAddress]::Parse($source.IPAddress), 0)))
    $connect = $socket.BeginConnect($TabletAddress, $Port, $null, $null)
    if (-not $connect.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) {
        throw "Timed out connecting to ${TabletAddress}:$Port"
    }
    $socket.EndConnect($connect)
    $stream = New-Object Net.Sockets.NetworkStream($socket, $false)
    $input.CopyTo($stream)
    $stream.Flush()
    $socket.Shutdown([Net.Sockets.SocketShutdown]::Send)
    "Sent $($input.Length) bytes: $fullPath"
} finally {
    if ($stream) { $stream.Dispose() }
    $input.Dispose()
    $socket.Dispose()
}
