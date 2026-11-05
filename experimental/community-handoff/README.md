# Community handoff — 2026-11-05

Development is paused. The owner's tablet has been returned to its original
Android recovery/vbmeta; Linux sources and local backups are retained. Contributors
are welcome. This directory preserves unfinished work, **not a recommended release**.

## Proven baseline versus experiments

| Profile | Evidence | Limitation |
|---|---|---|
| R226 v2 payload / recovery selector v3 | Installed boot, visible KDE, touch, SD150, SuperSpeed peripheral | One tablet/card; fixed Type-C orientation; not a generic installer |
| R228 host experiments | Manual host/controller and read-only flash checks | Not integrated reliable powered-hub support |
| R231 charge keepalive | Actual charge confirmed by gauge current and increasing capacity | Replug/reboot sometimes needs service restart; not a complete charger driver |
| R234 AUX bus | Unreserved GPIO0/1; FSA-family device answered at I2C 0x42, ID 0xf1 | No working DP/HDMI established |
| R235 watchdog-only | Compile, policy tests, negative opt-in gate test | Positive PD contract gate never reached |
| R236/R237/R238 | Bounded sink current, explicit 3.072 V L2A supply, isolated RAM harness | Hardware PD negotiation failed |
| R239 | Initialize RX ownership and GoodCRC DEVICE/SINK roles before IRQs | First message received; hard-reset loop remained |
| R240 | Fix malformed RX handling and always attempt buffer release | Valid first RX acknowledged, but partner reset ~29 ms later |
| R241 | Log first PD header, TCPM state/attached/roles; capture complete TCPM log | Compiled and packaged offline only; never booted |

R226 measurements: 150 MHz SDR104 ~65–67 MB/s read, ~44 MB/s write on the
tested card, bounded read/write/hash tests passed. 202 MHz writes remain broken.
USB3 negotiated SuperSpeed/configured/U0, but NCM was only ~3–6 MB/s. Neither
link speed nor flashing a kernel guarantees useful throughput on another board/card.

## Source map

- `scripts/r227-*`, `r229-*`: read-only Type-C / charger register snapshots.
- `scripts/r230-*`, `r231-*`: sink rearm and guarded watchdog keepalive.
- `scripts/r232-dp-prep/`: private TCPM source transformations and build adapters.
- `scripts/r235-watchdog-only/`, `r236-current-limit/`: guards and host-side tests.
- `scripts/r237-pd-integration/`: opt-in regulator change, initrd hook, manual probe.
- `scripts/r239-pd-receiver/`, `r240-rx-cleanup/`, `r241-tcpm-trace/`: incremental
  RX fixes and diagnostics, with host-side malformed-message regression tests.
- `scripts/package-r238-pd-ram.sh`, `verify-r238-initrd.py`: isolated initrd packager
  and archive comparison. R239–R241 retain the **r238 harness name**.
- `reference/r241/`: complete matched generated TCPM/PMIC module sources. This
  avoids dependence on the original author's temporary R239/R240 source folders.
- `reference/kernel-6.12.114/`: tracked working-tree diff against vanilla
  Linux 6.12.114, its local base commit ID, and configured build `.config`.
  This is a source-tree snapshot including diagnostics; **not proof that every
  change was in the installed R226 Image**. Do not blindly stack it on existing patches.
- `reference/ps5169.c`: extracted driver reference; retain its upstream copyright/license.
- `SOURCE_SHA256SUMS`: integrity of exported reference sources, not a binary release manifest.

No keys, private network profiles, raw device logs, Android partition dumps,
firmware blobs, personal root filesystem or provisioned initrds are included.
Existing licenses/copyrights of Linux and vendor-derived code remain applicable.

## Rebuilding the latest diagnostic modules

Use Linux/WSL, LLVM/clang18 and a **prepared, matching configured kernel build**,
including Module.symvers. The tested release string is `6.12.114-tb371fc-r199+`;
the string alone does not guarantee symbol CRC or ABI compatibility.

```sh
# KERNEL_OUT points to your matching configured/output tree.
work=$(mktemp -d)
cp experimental/community-handoff/reference/r241/* "$work/"
make -C "$KERNEL_OUT" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
```

This compiles only; it does not load modules or authorize hardware tests.
Historical `build-r*.sh` scripts retain workspace/artifact paths. Adapt these paths
and dependencies first; generated reference sources above need no private folder.
Clean-checkout reproducibility of a complete distributable R226 image remains work
for contributors. Preserve original per-device backups before any hardware test.

Run host-only policy, fault-injection and RX regression models without a tablet:

```sh
bash experimental/community-handoff/test-offline.sh
```

These tests reproduce the old malformed-message bug and exercise its cleanup fix;
they do not establish that the same bug caused the observed hardware PD resets.

## Important findings / next work

1. Investigate **first PD message and TCPM attachment timing**. In R240, first
   packet had raw size 21 (22 bytes), valid read and successful ACK release.
   Partner HARD_RESET followed ~29 ms later with RX ACK already clear. The
   later RX-disable event followed reset; it is not evidence of its cause.
2. Capture R241 `header/type/count/state/attached/dr/pr/sop` and the complete
   initial trace. TCPM drops messages when not attached. This is a hypothesis
   to investigate, **not a confirmed explanation or reason to shorten debounce**.
3. The debugfs TCPM log is consumptive. Let `collect-tcpm.sh` be its only reader;
   it starts before PMIC probe, polls every 0.1 s, caps output at 1 MiB/80 s.
   Read `/run/r238/tcpm-full.log`, not `cat debugfs | tail`.
4. Make charging/reconnect robust before host+PD+DP integration. Then validate
   FSA SBU routing, PS5169 lane/orientation policy and DP altmode separately.
   The PD-only DT intentionally has DEVICE data role and no DP graph/altmodes.
5. Retain SD150/card-identity guards. Do not bypass them to advertise generic
   SDR104/202 MHz support. Continue read-only-first testing on new cards.

## Safety invariants

- Never run R231 and TCPM simultaneously: they would both own Type-C/charging.
- Do not load the replacement R237 regulator provider alongside the live R203
  provider/PHY consumers. L2A must be 3.072 V, not an approximate 3.1 V.
- R236 caps sink input to inherited/requested/1.5 A minimum, fixed 5 V only;
  initial 100 mA, source VBUS forbidden. Errors leave conservative suspension.
- R235 pets the existing watchdog only after its explicit power/ownership gates.
  It was never reached in successful live charging under TCPM in these tests.
- RAM test masks R231 at runtime and arms a 180 s return timer. This is best
  effort, not recovery from a kernel hang. Keep physical access to power keys.
- Do not suppress hard resets, force VBUS, disable thermal/OV protection or raise
  current/voltage limits to hide negotiation failures.
- Capture logs before unloading modules/rebooting. Reboot to known R226 and
  verify actual charging, not just the battery icon. MM8013 negative current
  was into the battery on this tablet; confirm capacity trend as well.

Send focused PRs to this repository with kernel/base config, reproducible build
steps, hardware/card/cable details (redact identifiers), before/after results,
rollback steps and any regressions. Do not upload keys or personal firmware dumps.
