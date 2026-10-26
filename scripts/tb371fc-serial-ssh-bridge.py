#!/usr/bin/env python3
"""Expose TB371FC OpenSSH carried over USB ACM on a localhost TCP port."""

import argparse
import socket
import sys
import threading
import time

import serial


def open_serial_port(serial_port: str):
    return serial.serial_for_url(
        serial_port,
        115200,
        timeout=0.20,
        write_timeout=5.0,
        dsrdtr=False,
        rtscts=False,
    )


def recover_target_gate(serial_port: str, gate_ready: bytes) -> bool:
    """Recover ttyGS0 after target BusyBox nc misses the host TCP FIN."""
    break_stream = b"\x00TB371FC_CLOSE_STALE_SSH_STREAM_" * 64
    with open_serial_port(serial_port) as breaker:
        breaker.dtr = True
        breaker.rts = True
        breaker.write(break_stream)
        breaker.flush()

    # Closing and reopening the Windows COM handle is significant here.  The
    # V55 USB gadget does not propagate a TCP-style half-close through ttyGS0,
    # while this bounded reconnect reliably lets target nc/sshd unwind.
    time.sleep(2.0)
    with open_serial_port(serial_port) as probe:
        probe.dtr = True
        probe.rts = True
        probe.write(b"\r\n")
        probe.flush()
        deadline = time.monotonic() + 12.0
        window = bytearray()
        while time.monotonic() < deadline:
            chunk = probe.read(4096)
            if not chunk:
                continue
            window.extend(chunk)
            if len(window) > len(gate_ready) * 4:
                del window[: -len(gate_ready) * 4]
            if gate_ready in window:
                return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial-port", required=True)
    parser.add_argument("--listen-address", default="127.0.0.1")
    parser.add_argument("--listen-port", type=int, default=22222)
    parser.add_argument(
        "--mode", choices=("ssh", "diag", "direct"), default="ssh"
    )
    args = parser.parse_args()

    gate_ready = b"__TB371FC_SSH_GATE_READY__"
    target_gate_observed = False
    client_eof_observed = False
    with open_serial_port(args.serial_port) as port:
        port.dtr = True
        port.rts = True
        # Release a stale target-side read left behind by a previous host
        # connection. The target ignores an empty command and emits a fresh
        # gate marker while this serial port is open.
        # ttyGS0 is configured in canonical/sane mode at the command gate.
        # Use CRLF here: some Windows USB-ACM sessions leave ICRNL disabled,
        # so a bare LF can remain buffered and the gate never advances.
        port.write(b"\r\n")
        port.flush()
        stream_ready = b"__TB371FC_SSH_STREAM__"
        sshd_failed = b"__TB371FC_SSHD_NOT_LISTENING__"

        def read_until(
            markers: tuple[bytes, ...], timeout: float
        ) -> tuple[bytes, bytes, bytes]:
            deadline = time.monotonic() + timeout
            data = bytearray()
            while time.monotonic() < deadline:
                chunk = port.read(4096)
                if chunk:
                    data.extend(chunk)
                    for marker in markers:
                        position = data.find(marker)
                        if position >= 0:
                            end = position + len(marker)
                            while end < len(data) and data[end] in b"\r\n":
                                end += 1
                            return marker, bytes(data[:position]), bytes(data[end:])
            raise TimeoutError(f"serial gate timeout; received {bytes(data)!r}")

        if args.mode != "direct":
            marker, _, _ = read_until((gate_ready,), 60.0)
            if marker != gate_ready:
                raise RuntimeError("unexpected serial gate response")
        if args.mode == "diag":
            port.write(b"DIAG\n")
            port.flush()
            marker, diagnostic, _ = read_until((b"__TB371FC_DIAG_DONE__",), 30.0)
            if marker != b"__TB371FC_DIAG_DONE__":
                raise RuntimeError("unexpected diagnostic response")
            sys.stdout.buffer.write(diagnostic.lstrip(b"\r\n"))
            sys.stdout.buffer.flush()
            return 0
        buffered = b""
        if args.mode != "direct":
            port.write(b"SSH\n")
            port.flush()
            marker, _, buffered = read_until((stream_ready, sshd_failed), 30.0)
            if marker == sshd_failed:
                print("Tablet reports that sshd is not listening", file=sys.stderr)
                return 3

        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((args.listen_address, args.listen_port))
        listener.listen(1)
        print(
            f"READY {listener.getsockname()[0]}:{listener.getsockname()[1]} -> {args.serial_port}",
            flush=True,
        )
        connection, peer = listener.accept()
        listener.close()
        print(f"CONNECTED {peer[0]}:{peer[1]}", flush=True)
        if buffered:
            connection.sendall(buffered)
        stop = threading.Event()
        client_eof = threading.Event()
        target_gate = threading.Event()
        client_closed_at: list[float | None] = [None]
        gate_window = bytearray()
        # The tablet-side BusyBox nc has a USB tty as stdin/stdout. Closing
        # the Windows COM handle does not reliably deliver EOF to ttyGS0. If
        # the TCP client exits, keep draining the tty until OpenSSH processes
        # its clean disconnect, target nc exits and the shell emits its next
        # gate marker. Do not inject bytes into the encrypted stream here: the
        # former immediate break corrupted otherwise valid SSH disconnect
        # packets and made the following session fail with Bad packet length.
        # The bounded COM-reopen recovery below remains the fallback if the
        # target does not return to the gate on its own.
        drain_timeout = 10.0

        def serial_to_socket() -> None:
            try:
                while not stop.is_set():
                    data = port.read(65536)
                    if data:
                        if client_eof.is_set():
                            gate_window.extend(data)
                            if len(gate_window) > len(gate_ready) * 2:
                                del gate_window[: -len(gate_ready) * 2]
                            if gate_ready in gate_window:
                                target_gate.set()
                                stop.set()
                                break
                        else:
                            try:
                                connection.sendall(data)
                            except OSError:
                                client_closed_at[0] = time.monotonic()
                                client_eof.set()
                    if client_eof.is_set() and client_closed_at[0] is not None:
                        if time.monotonic() - client_closed_at[0] >= drain_timeout:
                            stop.set()
                            break
            except serial.SerialException:
                stop.set()
            finally:
                if not client_eof.is_set():
                    stop.set()

        def socket_to_serial() -> None:
            try:
                while not stop.is_set():
                    data = connection.recv(65536)
                    if not data:
                        break
                    port.write(data)
                    port.flush()
            except (OSError, serial.SerialException):
                pass
            finally:
                client_closed_at[0] = time.monotonic()
                client_eof.set()

        threads = [
            threading.Thread(target=serial_to_socket, daemon=True),
            threading.Thread(target=socket_to_serial, daemon=True),
        ]
        for thread in threads:
            thread.start()
        stop.wait()
        connection.close()

        if target_gate.is_set():
            target_gate_observed = True
            print("DRAINED target returned to SSH gate", flush=True)
        elif client_eof.is_set():
            client_eof_observed = True
            print(
                "WARNING target gate was not observed after serial drain",
                file=sys.stderr,
                flush=True,
            )

    if client_eof_observed and not target_gate_observed:
        if recover_target_gate(args.serial_port, gate_ready):
            print("RECOVERED target returned to SSH gate after COM reopen", flush=True)
        else:
            print(
                "WARNING target gate recovery after COM reopen failed",
                file=sys.stderr,
                flush=True,
            )
            return 4

    print("CLOSED", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
