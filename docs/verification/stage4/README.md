# Stage 4 verification — Bluetooth and ESC/POS printing

Date: 2026-10-02

Branch: `feature/full-pos`

Hardware status: software verified; physical MP-58N verification deferred to Stage 7.

## Implemented architecture

The printing stack is isolated behind `PrinterTransport`. Flutter owns printer settings, receipt rendering, print orchestration, result messages, and print-attempt persistence. Android Kotlin owns Bluetooth Classic adapter state, Android 12+ runtime permissions, bonded-device enumeration, RFCOMM/SPP socket lifecycle, and byte transmission. The method-channel name is `dakao_in_bill/printer` and exposes only state, permission, paired-device, connect, write, and disconnect operations.

No third-party Bluetooth package or backend was added. Android lists already paired devices only. It does not perform active discovery, does not scan in the background, and does not silently enable Bluetooth. The selected device name and Bluetooth address are stored in the existing local printer-settings row.

The native transport uses the standard Serial Port Profile UUID `00001101-0000-1000-8000-00805F9B34FB`. It reuses a live socket for the configured address, reconnects on an explicit connection/write attempt when needed, writes in 512-byte chunks, flushes, and closes the socket on I/O failure or activity destruction. Blocking connect/write work is serialized on a background-only lock. The short state lock is never held across Bluetooth I/O, so a main-thread disconnect or activity teardown can close an in-progress socket and unblock it. Failed connection candidates are also closed.

## Receipt encoding

Flutter lays out each receipt from the saved `OrderItems` snapshots and the saved `receipt_settings_snapshot`. It never reads the current product or app settings when reprinting a historical order. Text is drawn with bundled Plus Jakarta Sans into a monochrome, 384-dot-wide bitmap. The bitmap is split into bands no taller than 160 dots and encoded with ESC/POS `GS v 0`; the payload begins with printer initialization and ends with four feed lines.

Rasterizing the entire text layout makes Vietnamese glyphs deterministic and independent of a printer's unknown UTF-8 or code-page support. Automated tests render strings including `Đakao`, `Cơm tấm`, `Sườn`, and `Chả`, assert deterministic non-empty output, inspect the 384-dot raster headers, and enforce the band-height limit.

The distinct test page contains no order and changes no order, payment, revenue, or print-attempt data.

## Save and print sequence

The production **In bill** action performs this sequence:

1. Validate the cart and guard against concurrent submission.
2. Create the order and its item/settings snapshots in one Drift transaction.
3. Commit the transaction.
4. Clear the cart and rotate its submission token while keeping checkout locked.
5. Ask `PrinterService` to render and send the already saved order.
6. Record the print attempt in an independent transaction.
7. Unlock checkout and return to the sales screen, ready for the next order.

Bluetooth I/O never runs inside the order transaction. The cleared cart remains locked until the print result is recorded, preventing a second sale from sharing the first sale's in-flight future. A printer error cannot roll back the saved order. A retry/reprint loads the same order ID, creates no order number, and changes no order total, status, payment timestamp, or revenue. Reprint is rejected before transport access for a cancelled order. There is no automatic retry after reconnect or after an ambiguous result.

## Result and attempt semantics

`sent` means the app completed the Bluetooth socket write and flush. It does not prove that paper physically printed. User feedback therefore says the data was sent and asks the user to check the paper; it does not claim print success.

Each order print/reprint attempt records the order ID, attempt timestamp, software result, and a structured error string for failed or unknown results. `print_count` increments, and `printed_at` updates to the latest attempt time, only for `sent`. Failed and unknown attempts do not increment it. Rendering errors are normalized to failed attempts. If bytes may have started transmitting before an I/O error, or the transport exits unexpectedly without a trustworthy boundary, the result is stored as `UNKNOWN_OUTCOME`; the app tells the user the receipt may have printed partially and never resends automatically. If the transmission result itself cannot be persisted, the app likewise reports an unknown outcome and does not retry automatically.

An unconfigured printer is recorded as a failed attempt for an already saved order. Test prints are not associated with an order and do not create print-attempt rows.

## Permissions and UI

The Android manifest declares legacy `BLUETOOTH` and `BLUETOOTH_ADMIN` through API 30, plus `BLUETOOTH_CONNECT` and `BLUETOOTH_SCAN` for Android 12 and later. `BLUETOOTH_SCAN` uses `neverForLocation`. The app requests the modern permissions only from the explicit printer screen action.

The Stitch-aligned Settings screen links to printer setup. Printer setup reports unavailable, disabled, denied, disconnected, and connected states; lists bonded devices; stores the chosen name/address; supports refresh/reconnect and a distinct test print; and gives actionable error messages. V1 exposes no auto-print toggle.

Order details expose an explicit **In lại bill** action for UNPAID and PAID orders. The action is disabled for CANCELLED orders.

## Automated verification

The final gate covers formatting, static analysis, the full Flutter test suite, the API 36 integration test, and a debug Android APK build. The suite verifies the required save-before-print ordering, failure persistence, UNPAID state, retry/reprint identity, historical snapshots, unknown outcomes, result persistence and `print_count`, rapid-submit idempotency, printer states, and test-print isolation.

Final command results after the review pass:

- `dart format --output=none --set-exit-if-changed lib test integration_test`: 54 files checked, 0 changed.
- `flutter analyze`: no issues found.
- `flutter test`: all 93 tests passed.
- `flutter test integration_test/order_flow_test.dart -d emulator-5554`: 1 integration test passed on API 36.
- `flutter build apk --debug`: succeeded; produced `build/app/outputs/flutter-apk/app-debug.apk`.
- The final APK installed successfully and `com.example.dakao_in_bill/.MainActivity` became the focused API 36 activity.

An independent code review found concurrency, exception-normalization, and socket-lifecycle issues during the first pass. Those issues were corrected and the reviewer's final narrow re-check reported no remaining Critical, Important, or P2 findings.

## API 36 emulator verification

The normal debug APK was installed and launched on `Dakao_API_36` (`emulator-5554`), without replacing the production printer channel with a fake. The Settings and printer screens opened without crashes. Android displayed the real Nearby Devices permission dialog; denial returned the app to its explicit permission-denied state. The emulator had no paired printer, so no physical-send claim was made.

A normal sale was then submitted with no configured printer. The UI reported `Đã lưu đơn #0001. Chưa cấu hình máy in.` The cart cleared, the single UNPAID order remained visible, explicit reprint reported `Chưa cấu hình máy in Bluetooth.`, and no second order appeared. After force-stopping and relaunching the app, order `#0001` and its detail were still present. After explicitly cancelling that order, its detail showed the disabled `Không thể in lại đơn đã hủy` action.

The integration test separately uses a fake transport to prove that the saved order is queryable before `send` is invoked, then checks persistence and payment after rebuilding the app. This fake is test-only and is not evidence of MP-58N compatibility.

Evidence images:

- `settings.png`
- `printer-permission.png`
- `android-permission-dialog.png`
- `permission-denied.png`
- `save-print-failed.png`
- `order-after-print-failure.png`
- `reprint-not-configured.png`
- `cancelled-reprint-disabled.png`

## Stage 7 hardware assumptions

The following remain explicitly unverified until testing with the physical MP-58N and representative Android phones:

- the printer exposes Bluetooth Classic SPP;
- its pairing workflow and PIN behavior;
- its Bluetooth address remains a suitable stable identifier;
- its printable width is 384 dots;
- its supported ESC/POS command subset;
- compatibility with `GS v 0` raster bands;
- whether 160-dot raster bands are accepted reliably;
- whether 512-byte Bluetooth writes are safe;
- required pauses or other write timing constraints;
- feed behavior and whether a cut command is supported or appropriate;
- Vietnamese raster legibility, darkness, speed, and paper margins;
- socket reuse, disconnect detection, and reconnect behavior;
- behavior across Android phone vendors and OS versions.

The Stage 4 implementation deliberately sends feed lines and no cut command. These values are replaceable after Stage 7 measurements.

## Deviations and remaining risks

The implementation offers bonded-device selection rather than active discovery. This avoids continuous scanning and matches the expected workflow: pair the MP-58N in Android settings, then select it in the app. Some Android vendors may still vary in permission presentation or Bluetooth stack behavior.

Software write completion is the strongest result available over this transport. Printers generally provide no reliable paper-complete acknowledgement through basic SPP, so operators must check paper output and initiate reprint themselves when necessary. Physical MP-58N compatibility is not claimed by Stage 4.
