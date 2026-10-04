# Stage 7A — MP-58N Hardware Readiness

> Stage 7A was the software-readiness checkpoint before access to real
> hardware. Stage 7B has since passed on a physical MP-58N using the accepted
> production candidate profile. See
> [Stage 7B physical verification](../stage7b/README.md). The assumptions and
> checklist below are retained as the historical pre-test record.

## Checkpoint

- Branch: `debug/mp58n`
- Base commit: `9204482` (`feat: complete settings and backup restore`)
- Stage 7A commit: the commit containing this document, titled
  `feat: prepare MP-58N hardware diagnostics`
- Scope: debug-only hardware test harness. This is not physical printer
  verification.

## Existing Stage 4 architecture reused

The implementation continues to use `PrinterTransport`, `PrinterService`,
`PrinterSettingsController`, `ReceiptRenderer`, `PrintAttemptRepository`, and
the single native `dakao_in_bill/printer` MethodChannel. Kotlin still owns one
Bluetooth Classic RFCOMM socket protected by connection-generation and I/O
locks. No second printer stack, database migration, or backup-format change was
introduced.

Production order printing remains save, commit, render, send, then independently
record the attempt. Cancelled reprints remain disabled. Ambiguous writes remain
`UNKNOWN_OUTCOME` and are never automatically resent.

## Changes

- Added a debug-gated MP-58N Hardware Lab route and link from printer settings.
  Both are excluded when `kDebugMode` is false.
- Added structured transport observations for permission state, bonded devices,
  socket creation/connect, payload size, chunk start/completion, flush,
  exceptions, disconnect, and elapsed time.
- Centralized temporary parameters in `HardwareLabParameters`. They are held in
  memory and never overwrite production printer settings.
- Removed Android 12+ `BLUETOOTH_SCAN` because Stage 7A performs no active
  discovery. Bonded-device access and RFCOMM use `BLUETOOTH_CONNECT`; legacy
  permissions remain capped at API 30.
- Added deterministic ASCII, feed, geometry, Vietnamese raster, and full sample
  receipt payloads. The latter three use the production GS v 0 raster pipeline;
  the sample receipt creates no database order or print attempt.
- Added copyable timestamped logs. Logs contain test/device/transport metadata,
  not order or customer data.

## Diagnostic tests

| Test | Software observation |
| --- | --- |
| ASCII Test | Sends a minimal `ESC @`, ASCII text, and four-line feed payload. |
| Feed Test | Sends only initialization and four-line feed; no cutter command. |
| Raster Geometry Test | Sends border, center line, markers, circle, square, and width label. |
| Vietnamese Raster Test | Rasterizes Vietnamese diacritics through the production pipeline. |
| Full Receipt Test | Renders a deterministic fake order without database mutation. |

A completed write is shown as: “Dữ liệu đã được gửi qua Bluetooth. Hãy kiểm
tra giấy in để xác nhận.” It does not claim physical printing.

## Temporary transport parameters

- Raster width: 320, 384 (default), or 432 dots
- Raster band height: 64, 96, 128, 160 (default), or 192 dots
- Chunk size: 128, 256, 512 (production default), or 1024 bytes
- Inter-chunk delay: 0 (production default), 5, 10, 20, or 50 ms

Kotlin validates chunk size and delay again at the native boundary. Reset to
defaults is available. These values are not persisted.

## Automated verification

- Dart formatting: 87 files checked, 0 changed.
- Flutter analysis: no issues.
- Flutter tests: all 160 passed.
- API 36 order-flow integration test: passed.
- API 36 backup/restore integration test: passed.
- Debug APK build: passed.
- Release APK build: passed; the release Hardware Lab gate was checked on the
  API 36 emulator.

Focused coverage includes deterministic payload bytes, geometry dimensions,
Vietnamese and sample receipt rasterization, all approved chunk sizes,
parameter rejection, connection transitions and failure, chunk failure and
ambiguous outcome, no resend, duplicate-action guards, selected-device changes,
debug gating, transport-only UI wording, database non-mutation, and all existing
production printer tests.

## Emulator/manual verification

On the API 36 emulator, the production app launched, printer settings retained
their normal permission state, and the debug APK exposed the Hardware Lab link.
The lab displayed its transport-only warning, permission action, diagnostic
buttons, and bounded parameter controls. A separately installed release APK
retained the production printer settings screen and did not expose the lab.

The emulator cannot verify Bluetooth Classic SPP or paper output.

## Independent review

The review found no Critical issue and one Important lifecycle issue: leaving
the lab during a connect/write could leave the operation without a visible
owner. The fix disconnects on controller disposal, ignores stale async
completions, permits an explicit disconnect during a write, and prevents
notifications after disposal. Red-green tests cover disposal during connect and
disconnect during a blocked write. Related permission double-tap and parameter
constructor bounds were also tightened. Android activity teardown already
called `closeSocket()` from `onDestroy()`.

## Production invariants checked

- No database schema or migration change.
- No backup archive or schema change.
- No revenue query or calculation change.
- No order creation, transition, token, or cancellation change.
- No database transaction spans Bluetooth I/O.
- A diagnostic full receipt creates no order, revenue, or production
  `print_attempt` record.
- Production default chunking remains 512 bytes with 0 ms delay.
- Printer failures do not delete orders; retries do not create orders or change
  revenue; unknown outcomes do not resend automatically.

## HARDWARE ASSUMPTIONS — NOT VERIFIED

The following are assumptions until Stage 7B is performed with the physical
printer:

- MP-58N exposes Bluetooth Classic SPP.
- The standard SPP UUID is accepted.
- Pairing works and its PIN behavior is usable.
- Android reports a stable, usable Bluetooth address.
- `ESC @` initialization is supported.
- Basic ASCII text is supported and rendered as expected.
- `ESC d` feed behavior matches the requested line count.
- GS v 0 monochrome raster is supported.
- The actual printable width is suitable for the offered profiles.
- The 384-dot production assumption is correct.
- The printer tolerates the configured raster band heights.
- The printer tolerates 128, 256, 512, or 1024-byte writes.
- Any required inter-chunk delay is known.
- Printer buffer capacity is sufficient for long receipts.
- Vietnamese raster text and diacritics are readable.
- Margins, alignment, clipping, and geometry are correct.
- Disconnect and reconnect behavior is reliable.
- Power-off during a write produces the expected failure or ambiguous outcome.
- A successful socket write and flush corresponds to physical paper output.

## STAGE 7B PHYSICAL CHECKLIST

1. Charge and power on the printer.
2. Enable Bluetooth on Android.
3. Pair the printer in Android settings.
4. Record the displayed device name.
5. Record pairing PIN behavior.
6. Open Đakao printer settings.
7. Grant required Bluetooth permission.
8. Verify the bonded device appears.
9. Select the printer.
10. Open MP-58N Hardware Lab from the debug build.
11. Connect and record the socket observations.
12. Run ASCII Test.
13. Physically confirm paper output.
14. Run Feed Test.
15. Run Raster Geometry Test.
16. Measure and inspect clipping and printable width.
17. Run Vietnamese Raster Test.
18. Inspect diacritics and readability.
19. Run Full Receipt Test.
20. Test disconnect and reconnect.
21. Power the printer off during a controlled diagnostic write.
22. Observe and record error or unknown-outcome behavior.
23. Determine a stable chunk size and inter-chunk delay.
24. Record the final verified hardware profile.
25. Only then propose production adjustments.
