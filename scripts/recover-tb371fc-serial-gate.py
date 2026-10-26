#!/usr/bin/env python3
import sys
import time

import serial


port_name = sys.argv[1] if len(sys.argv) > 1 else "COM9"
with serial.Serial(
    port_name, 115200, timeout=0.2, write_timeout=5.0,
    dsrdtr=False, rtscts=False,
) as port:
    port.dtr = False
    port.rts = False
    time.sleep(3)
    break_stream = (b"\x00TB371FC_FORCE_CLOSE_" + b"X" * 64) * 64
    for offset in range(0, len(break_stream), 512):
        try:
            port.write(break_stream[offset : offset + 512])
            port.flush()
        except serial.SerialTimeoutException:
            # Closing/reopening the COM handle is the important recovery
            # edge; a saturated stale SSH stream need not accept every byte.
            break
        time.sleep(0.05)
    time.sleep(2)

time.sleep(5)
with serial.Serial(
    port_name, 115200, timeout=0.2, write_timeout=5.0,
    dsrdtr=False, rtscts=False,
) as port:
    port.dtr = True
    port.rts = True
    deadline = time.monotonic() + 30
    received = bytearray()
    # Drain first. After target nc exits, the shell can already be blocked
    # writing the next gate marker while the host COM handle is closed. A
    # write-first recovery then deadlocks against a saturated OUT endpoint.
    drain_deadline = time.monotonic() + 5
    while time.monotonic() < drain_deadline:
        received.extend(port.read(port.in_waiting or 1))
        if b"__TB371FC_SSH_GATE_READY__" in received:
            break
    if b"__TB371FC_SSH_GATE_READY__" not in received:
        try:
            port.write(b"\r\n")
            port.flush()
        except serial.SerialTimeoutException:
            pass
    while time.monotonic() < deadline:
        # A 4096-byte overlapped read can remain pending indefinitely on a
        # quiet Windows USB-ACM endpoint despite the pyserial timeout. Read
        # only what is queued (or one byte) so the monotonic deadline remains
        # authoritative and recovery always finishes within the bound.
        received.extend(port.read(port.in_waiting or 1))
        if b"__TB371FC_SSH_GATE_READY__" in received:
            break
    sys.stdout.buffer.write(received[-4000:])
    if b"__TB371FC_SSH_GATE_READY__" not in received:
        raise SystemExit("serial gate was not recovered")
