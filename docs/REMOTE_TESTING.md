# TB371FC extended remote Linux test

This procedure is designed for a session where nobody is physically present
at the tablet. It maximizes evidence collected during one diagnostic Linux
boot and postpones rollback until every useful test has finished.

## Physical limitation

After exact stock `recovery_b` and signed `vbmeta_b` are restored, this tablet
may enter stock Recovery because the existing recovery boot request remains
active. Stock Recovery currently exposes ADB as `unauthorized`, so the host
cannot reliably select `Reboot system now`. Do not work around this by writing
`misc` or clearing the bootloader control block: that would expand the set of
modified partitions beyond the authorized recovery/vbmeta pair.

The intended end state for an unattended session is therefore either:

1. restored stock partitions with the tablet waiting safely in stock Recovery
   until the owner selects `Reboot system now`; or
2. diagnostic Linux kept running while connected to power, with rollback
   deferred until the owner is available.

Use option 1 only after every log has been copied to the host. Never restore
in the middle of the test because that intentionally ends remote access.

## Expanded image contents

The extended image includes:

- static upstream QRTR v1.1 `qrtr-ns` and `qrtr-lookup`;
- `collect-hardware-snapshot`, a read-only inventory of CPU/RAM, UFS/microSD,
  thermals, power, DRM modes, USB-C/DP, PCI/MHI/QRTR, Bluetooth transports,
  input/AP500U, ALSA, cameras/media, sensors and remote processors;
- `start-qrtr-diagnostics` and `stop-qrtr-diagnostics`, which only control
  QRTR logging and never write `ON\n` to `/dev/wlan`;
- `capture-input-events`, for a bounded AP500U/touch event capture when a
  person is present to interact with the screen or stylus.
- `activate-wlan-once`, which requires an explicit token, verifies the no-SSR
  guard, both QRTR processes and all 28 BDF files, creates a per-boot sentinel
  before sending the exact three bytes, and refuses a second activation;
- `return-to-bootloader`, which requires a separate logs-copied token before
  loading the already tested one-shot reboot module.

On Windows, run the read-only baseline collector after USB NCM appears:

```powershell
.\scripts\collect-extended-diagnostics.ps1
```

It auto-detects the active NCM adapter, saves timestamped baseline, QRTR and
full dmesg logs, and does not activate WLAN. NCM command output is flushed to
the Windows file as each chunk arrives, so a disconnect or restart preserves
the partial evidence already received.

After all captures are complete, create a deterministic finding table and
SHA-256 manifest without contacting the tablet:

```powershell
.\scripts\analyze-diagnostic-session.ps1 `
  -InputDirectory .\diagnostics\remote-session
```

The generated `session-summary.md` flags panic/reboot/storage errors, the CNSS
timeout and no-SSR guard, MHI/QRTR/FW_READY/WLAN progress, and evidence for
AP500U, 120 Hz, DP, Bluetooth, ALSA and camera/media nodes. It never treats a
pattern match as proof of full hardware functionality; raw logs remain the
source of truth.

The final unattended-session v2 artifacts are stored outside Git:

- initramfs SHA-256:
  `c96513dbd2dcce021e8a161404c8bd0dcd03f5078e86ce314c34b3062ef03bd0`;
- 100 MiB recovery SHA-256:
  `664ac94117ebc46af96f4d230958a8a91bf8b1712ec8cad5d61fa14664e8c7de`.

The recovery is offline verified but intentionally not launch-allowlisted.

## Test order

1. Confirm stable NCM shell and capture baseline plus full dmesg.
2. Start `qrtr-ns`/`qrtr-lookup`; confirm both remain alive.
3. Capture the pre-WLAN MHI/QRTR state.
4. After reviewing the baseline, send exactly one `ON\n` request and wait at
   least 25 seconds. The no-SSR kernel must keep Linux alive even on timeout.
5. Copy QRTR, CNSS, MHI and dmesg logs to Windows immediately.
6. Capture a second hardware snapshot and compare network, thermal, power and
   remote-processor state with the baseline.
7. Inspect touch/AP500U nodes, panel modes, Bluetooth UART/firmware, ALSA,
   camera/media nodes and sensor/remoteproc state without powering unknown
   camera rails or probing arbitrary I2C addresses.
8. If a dock is physically connected later, test USB host enumeration,
   Ethernet carrier/DHCP and DP connector state in a separate phase.
9. Only after all evidence is copied, invoke the embedded bootloader reboot,
   restore exact stock `recovery_b` then exact signed `vbmeta_b`, and accept
   that physical `Reboot system now` may be required afterward.

## Immediate stop conditions

Do not continue component activation if the NCM shell disappears, uptime
resets, battery/thermal readings become implausible, repeated PCIe errors
appear, storage reports I/O errors, or the tablet leaves Linux unexpectedly.
Proceed directly to the already verified bootloader/rollback path if it is
still reachable.
