"""TB371FC USB rescue channel (Linux 6.12 maintenance mode, 172.31.77.2): commands and file streaming.

  py -3.14 scripts/tb371fc-ncm.py cmd "uname -a"
  py -3.14 scripts/tb371fc-ncm.py send LOCAL_FILE "REMOTE_SINK"   (e.g. "dd of=/dev/mmcblk0p2 bs=4M")

The rescue shell (busybox nc -e sh on port 2323) has no prompt; a marker line ends each command.
For send, the tablet runs "nc -l -p 2400 | REMOTE_SINK" in the background and this script streams
the file to port 2400. A .zst file is decompressed on the PC side (python zstandard not needed:
uses the zstd CLI from WSL when available, else sends the file as is).
"""
import socket
import subprocess
import sys
import time

TABLET = '172.31.77.2'
SHELL_PORT = 2323
DATA_PORT = 2400


def local_ip():
    out = subprocess.run(['powershell', '-NoProfile', '-Command',
                          "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '172.31.77.*' } | Select-Object -First 1).IPAddress"],
                         capture_output=True, text=True).stdout.strip()
    if not out:
        sys.exit('no 172.31.77.x address on the PC (USB network not up)')
    return out


def connect(port, src, timeout=15):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind((src, 0))
    s.settimeout(timeout)
    s.connect((TABLET, port))
    return s


def run(cmd, src, timeout=600):
    s = connect(SHELL_PORT, src)
    marker = '__TB371FC_DONE__'
    # the initramfs has links only for some busybox applets; maintenance mode installs all of them
    s.sendall(f'export PATH=/run/maint-bin:/bin:/sbin:$PATH\n{cmd}\necho {marker}$?\nexit\n'.encode())
    s.settimeout(timeout)
    buf = b''
    while True:
        try:
            d = s.recv(65536)
        except socket.timeout:
            break
        if not d:
            break
        buf += d
        if marker.encode() in buf and b'\n' in buf.split(marker.encode())[-1]:
            break
    s.close()
    text = buf.decode(errors='replace')
    rc = None
    if marker in text:
        body, tail = text.split(marker, 1)
        rc = tail.strip().splitlines()[0] if tail.strip() else None
        text = body
    return text, rc


def send(path, sink, src):
    run(f"(setsid sh -c 'nc -l -p {DATA_PORT} | {sink}; echo $? > /tmp/tb371fc-recv.rc' </dev/null >/tmp/tb371fc-recv.log 2>&1 &)", src, timeout=10)
    time.sleep(1.5)
    s = connect(DATA_PORT, src, timeout=60)
    t0 = time.time()
    sent = 0
    if path.endswith('.zst'):
        wsl_path = '/mnt/' + path[0].lower() + path[2:].replace('\\', '/')
        p = subprocess.Popen(['wsl.exe', '-d', 'Ubuntu-24.04', '-u', 'root', '-e', 'zstd', '-dc', wsl_path], stdout=subprocess.PIPE)
        src_f = p.stdout
    else:
        src_f = open(path, 'rb')
    last = t0
    while True:
        chunk = src_f.read(4 << 20)
        if not chunk:
            break
        s.sendall(chunk)
        sent += len(chunk)
        if time.time() - last > 30:
            last = time.time()
            print(f'  {sent >> 20} MiB, {sent / (last - t0) / 1e6:.1f} MB/s', flush=True)
    s.shutdown(socket.SHUT_WR)
    s.close()
    dt = time.time() - t0
    print(f'sent {sent} bytes in {dt:.0f} s ({sent / max(dt, 1) / 1e6:.1f} MB/s)')
    # wait for the sink to finish writing
    for _ in range(3600):
        out, _ = run('cat /tmp/tb371fc-recv.rc 2>/dev/null', src, timeout=10)
        if out.strip():
            print('sink rc=' + out.strip())
            return out.strip() == '0'
        time.sleep(2)
    return False


def main():
    src = local_ip()
    if sys.argv[1] == 'cmd':
        out, rc = run(sys.argv[2], src, timeout=float(sys.argv[3]) if len(sys.argv) > 3 else 600)
        sys.stdout.write(out)
        print(f'[rc={rc}]')
        sys.exit(0 if rc == '0' else 1)
    if sys.argv[1] == 'send':
        sys.exit(0 if send(sys.argv[2], sys.argv[3], src) else 1)


if __name__ == '__main__':
    main()
