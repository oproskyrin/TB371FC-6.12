"""Minimal Chrome DevTools Protocol client (Python stdlib only) for remote browser tests.

  python3 tb371fc-cdp.py eval 'JS expression'        -> prints the JSON result (first page target)
  python3 tb371fc-cdp.py nav URL                      -> navigates the first page target
Chromium must run with --remote-debugging-port=9222.
"""
import base64
import json
import os
import socket
import struct
import sys
import urllib.request

PORT = 9222


def target():
    pages = json.load(urllib.request.urlopen(f'http://127.0.0.1:{PORT}/json'))
    pages = [p for p in pages if p.get('type') == 'page']
    want = os.environ.get('CDP_URL')
    if want:
        pages = [p for p in pages if want in p.get('url', '')] or pages
    return pages[0]['webSocketDebuggerUrl']


class WS:
    def __init__(self, url):
        rest = url.split('://', 1)[1]
        hostport, path = rest.split('/', 1)
        host, port = hostport.split(':')
        self.s = socket.create_connection((host, int(port)), timeout=60)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f'GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\n'
                        f'Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n').encode())
        resp = b''
        while b'\r\n\r\n' not in resp:
            resp += self.s.recv(4096)
        assert b' 101 ' in resp.split(b'\r\n')[0], resp[:100]
        self.buf = resp.split(b'\r\n\r\n', 1)[1]

    def send(self, text):
        data = text.encode()
        head = bytes([0x81])
        n = len(data)
        if n < 126:
            head += bytes([0x80 | n])
        elif n < 65536:
            head += bytes([0x80 | 126]) + struct.pack('>H', n)
        else:
            head += bytes([0x80 | 127]) + struct.pack('>Q', n)
        mask = os.urandom(4)
        self.s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(65536)
            if not chunk:
                raise EOFError
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def recv(self):
        b0, b1 = self._read(2)
        n = b1 & 0x7f
        if n == 126:
            n = struct.unpack('>H', self._read(2))[0]
        elif n == 127:
            n = struct.unpack('>Q', self._read(8))[0]
        return self._read(n).decode(errors='replace')


def call(ws, method, params, ident=[0]):
    ident[0] += 1
    ws.send(json.dumps({'id': ident[0], 'method': method, 'params': params}))
    while True:
        msg = json.loads(ws.recv())
        if msg.get('id') == ident[0]:
            return msg


def main():
    ws = WS(target())
    if sys.argv[1] == 'eval':
        r = call(ws, 'Runtime.evaluate', {'expression': sys.argv[2], 'returnByValue': True, 'awaitPromise': True})
        res = r.get('result', {})
        if 'exceptionDetails' in res:
            print(json.dumps(res['exceptionDetails'].get('text', 'exception'), ensure_ascii=False))
        else:
            print(json.dumps(res.get('result', {}).get('value'), ensure_ascii=False))
    elif sys.argv[1] == 'nav':
        print(json.dumps(call(ws, 'Page.navigate', {'url': sys.argv[2]})))


if __name__ == '__main__':
    main()
