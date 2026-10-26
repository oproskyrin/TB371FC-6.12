#!/usr/bin/env python3
"""Send one command to the V51 USB ACM BusyBox ash and capture its output."""

import argparse
import re
import sys
import time

import serial


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True)
    parser.add_argument("--command", default="id; uname -a")
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()

    marker = "__TB371FC_V51_COMMAND_DONE__"
    marker_line = re.compile(
        rb"(?:^|\r?\n)" + re.escape(marker.encode()) + rb":([0-9]+)\r?(?:\n|$)"
    )
    # A real serial terminal sends carriage return for Enter.  ttyGS0's sane
    # line discipline maps CR to NL; a bare LF was only echoed by this target.
    command = f"{args.command}; rc=$?; echo {marker}:$rc\r"
    with serial.Serial(
        args.port,
        115200,
        timeout=0.20,
        write_timeout=3.0,
        dsrdtr=False,
        rtscts=False,
    ) as port:
        port.dtr = True
        port.rts = True
        time.sleep(1.0)
        port.reset_input_buffer()
        port.write(b"\r")
        port.flush()
        time.sleep(0.5)
        port.reset_input_buffer()
        port.write(command.encode("utf-8"))
        # Also submit the current canonical buffer explicitly.  This is
        # harmless after CR and helps diagnose gadget ttys whose initial line
        # discipline has not yet mapped carriage return to newline.
        port.write(b"\x04")
        port.flush()
        deadline = time.monotonic() + args.timeout
        output = bytearray()
        while time.monotonic() < deadline:
            chunk = port.read(4096)
            if chunk:
                output.extend(chunk)
                if marker_line.search(output):
                    break

    text = output.decode("utf-8", "replace")
    sys.stdout.write(text)
    match = marker_line.search(output)
    if not match:
        return 2
    return 0 if int(match.group(1)) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
