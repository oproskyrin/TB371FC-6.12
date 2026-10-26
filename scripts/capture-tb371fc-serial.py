#!/usr/bin/env python3
"""Capture a TB371FC USB ACM stream across bounded disconnects."""

from __future__ import annotations

import argparse
import pathlib
import sys
import time

import serial


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial-port", required=True)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--baudrate", type=int, default=115200)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    deadline = time.monotonic() + args.timeout
    args.output.parent.mkdir(parents=True, exist_ok=True)
    received = 0
    connections = 0

    with args.output.open("wb", buffering=0) as stream:
        while time.monotonic() < deadline:
            port = None
            try:
                port = serial.Serial(
                    port=args.serial_port,
                    baudrate=args.baudrate,
                    timeout=0.25,
                    write_timeout=1.0,
                )
                connections += 1
                while time.monotonic() < deadline:
                    chunk = port.read(65536)
                    if chunk:
                        stream.write(chunk)
                        received += len(chunk)
            except (OSError, serial.SerialException):
                time.sleep(0.25)
            finally:
                if port is not None:
                    try:
                        port.close()
                    except serial.SerialException:
                        pass

    print(
        f"captured_bytes={received} connections={connections} "
        f"output={args.output}",
        file=sys.stderr,
    )
    return 0 if received else 1


if __name__ == "__main__":
    raise SystemExit(main())
