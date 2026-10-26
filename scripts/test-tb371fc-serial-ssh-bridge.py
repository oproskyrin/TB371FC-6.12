#!/usr/bin/env python3
"""Offline binary-forwarding test for the TB371FC serial SSH host bridge."""

import pathlib
import socket
import subprocess
import sys
import threading
import time


def main() -> int:
    bridge = pathlib.Path(__file__).with_name("tb371fc-serial-ssh-bridge.py")
    port = 22353
    serial_port = 22354
    payload = bytes(range(256)) + b"TB371FC-SSH-BINARY"
    emulator = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    emulator.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    emulator.bind(("127.0.0.1", serial_port))
    emulator.listen(1)

    def emulate_tablet() -> None:
        connection, _ = emulator.accept()
        with connection:
            connection.sendall(b"boot text\r\n__TB371FC_SSH_GATE_READY__\r\n")
            command = bytearray()
            while b"SSH\n" not in command:
                chunk = connection.recv(16)
                if not chunk:
                    raise RuntimeError("bridge closed before the SSH command")
                command.extend(chunk)
            if b"SSH\n" not in command:
                raise RuntimeError(f"unexpected gate command: {bytes(command)!r}")
            connection.sendall(b"__TB371FC_SSH_STREAM__\r\n")
            close_token = b"\x00TB371FC_CLOSE_ABANDONED_SSH_STREAM_"
            remaining = len(payload)
            while remaining:
                data = connection.recv(min(4096, remaining))
                if not data:
                    raise RuntimeError("bridge closed during binary echo")
                connection.sendall(data)
                remaining -= len(data)
            command = bytearray()
            while close_token not in command:
                data = connection.recv(4096)
                if not data:
                    raise RuntimeError("bridge closed before the EOF token")
                command.extend(data)
            time.sleep(0.2)
            # Model sshd's encrypted close tail followed by the target shell
            # returning to its serial gate.
            connection.sendall(
                b"encrypted-close-tail"
                b"__TB371FC_SSH_GATE_READY__\r\n"
            )
            connection.settimeout(5)
            try:
                while connection.recv(4096):
                    pass
            except TimeoutError:
                raise RuntimeError("bridge did not close after the gate marker")

    emulator_thread = threading.Thread(target=emulate_tablet, daemon=True)
    emulator_thread.start()
    process = subprocess.Popen(
        [
            sys.executable,
            str(bridge),
            "--serial-port",
            f"socket://127.0.0.1:{serial_port}",
            "--listen-port",
            str(port),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        ready = process.stdout.readline().strip()
        if not ready.startswith("READY "):
            raise RuntimeError(f"bridge did not become ready: {ready!r}")
        with socket.create_connection(("127.0.0.1", port), timeout=5) as client:
            client.sendall(payload)
            received = bytearray()
            deadline = time.monotonic() + 5
            while len(received) < len(payload) and time.monotonic() < deadline:
                received.extend(client.recv(4096))
            if bytes(received) != payload:
                raise RuntimeError("serial bridge changed the binary payload")
        process.wait(timeout=12)
        remaining_stdout = process.stdout.read()
        if "DRAINED target returned to SSH gate" not in remaining_stdout:
            raise RuntimeError(
                f"bridge did not drain to the next gate: {remaining_stdout!r}"
            )
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        emulator.close()
    print("Serial SSH host bridge offline test: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
