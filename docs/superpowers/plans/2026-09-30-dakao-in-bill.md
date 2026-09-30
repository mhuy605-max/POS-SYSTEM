# Đakao In Bill Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for native execution, or superpowers:subagent-driven-development only if that execution method is selected. Do not begin implementation before review.

**Goal:** Deliver the scoped offline Android order/bill app with durable orders and real Bluetooth ESC/POS printing.

**Architecture:** Small feature modules, one typed SQLite database, controller/repository boundaries and an isolated printer adapter. Save transactions complete before printing; printer failures never erase orders.

**Tech Stack:** Flutter/Dart, proposed Drift/Riverpod/go_router, provisional Classic transport and ESC/POS encoder, local file picker/archive.

**Spec:** [technical design](../specs/2026-09-30-dakao-in-bill-design.md). User approved the design with decisions recorded in the spec. Native execution is authorized for Stage 0 only.

## Global constraints

- Android first; runtime works without Internet; no backend or excluded POS features.
- Integer VND, immutable saved order/item/receipt snapshots, UNPAID creation, commit before print.
- Retry/reprint act on order IDs and cannot create orders or affect revenue.
- Reproduce approved Stitch reference; do not redesign absent screens.
- Candidate stack requires Flutter ≥3.44 and Dart ≥3.12; versions remain provisional until build gates pass.
- Stage commits should be small and reviewed. No remote, push or server deployment is required.

## Stage 0 — Review and establish the build baseline

- [ ] Review spec rules 1–5, schema additions and Android phone support. Obtain Stitch export/link/assets and target phone Android version. Resolve these before dependent code.
- [ ] Locate or install stable Flutter and Android SDK/Studio; record actual SDK/JDK/AGP/Gradle combination. Run `flutter --version`, `dart --version`, `flutter doctor -v`, `flutter devices`, `adb devices`. Accept Android licenses through the normal setup flow.
- [ ] Initialize Git after review, record approved documents in the initial commit, and create `feature/full-pos`. No premature hardware-success label.
- [ ] Scaffold Android-only Flutter project as `dakao_in_bill`, display name Đakao In Bill; select the permanent Android application ID with the owner before release signing.
- [ ] Review candidate package source, license and open blocking issues; resolve dependencies and commit `pubspec.lock`. Audit printer I/O for UI-thread blocking, raw bytes and timeouts. Choose conditional ESC/POS package only with explicit maintenance decision; otherwise implement the narrow owned encoder within Stage 4.
- [ ] Create `lib/app/app.dart`, `lib/app/router.dart`, `lib/app/theme.dart`, `lib/main.dart`; wire the five approved destinations and dependency injection. Keep production printer binding real; test fakes only in tests.

Gate: `flutter pub get`, `flutter analyze`, scaffold `flutter test`, `flutter build apk --debug` succeed; launch on emulator/phone. Record versions and limitations in `docs/verification/environment.md`. No product acceptance follows from scaffold tests.

## Stage 1 — Database and order invariants

Files: `lib/data/app_database.dart`, `lib/data/tables.dart`, `lib/data/migrations/`, `lib/core/money.dart`, `lib/features/orders/order_repository.dart`, `lib/features/orders/order_service.dart`; matching `test/data/` and `test/orders/`.

Interfaces: `OrderDraft` contains stable submissionToken, optional orderType and `DraftLine` values (productId, reviewedName, reviewedUnitPrice, quantity, note). `Future<int> createOrder(OrderDraft draft)` returns committed existing/new ID; no printer reference in the repository. `Future<SavedOrder> loadOrder(int id)` returns order plus snapshots. `String formatVnd(int amount)` is presentation only.

- [ ] Write failing tests: two 45000 items total 90000; formatter returns `45.000đ`; zero/negative/fractional quantities and negative/overflow money are rejected; partial insertion rolls back; duplicate token returns same ID; concurrent saves have unique numbers.
- [ ] Implement seven tables, constraints/indexes, singleton settings, migrations baseline and approved additions. Use real SQLite in persistence tests rather than mocking SQL.
- [ ] Test renaming/repricing/soft-deleting products and editing shop settings leaves saved receipt snapshots unchanged. Reopen the database to prove persistence; changing catalog after review triggers re-review rather than silent repricing.
- [ ] Implement and test idempotent mark-paid and the approved cancellation transitions with an injected clock.

Gate: `flutter test test/data test/orders` passes; inspect stored integer values and FK checks. Export schema V1 for future upgrade tests; commit the persistence stage.

## Stage 2 — Catalog and receipt settings

Files: `lib/features/products/{product_repository,products_screen,product_editor,categories_screen}.dart`, `lib/features/settings/{settings_repository,settings_screen}.dart`; `test/products/`, `test/settings/`.

- [ ] Build product/category list/search/filter/add/edit, available/sold-out, soft-delete and category activation/order behavior from the prototype. Sold-out/deleted products cannot be newly added to a sale; historical snapshots remain accessible.
- [ ] Validate names and integer price entry. Store chosen product images privately and persist relative paths; use file selection only, without adding a camera workflow.
- [ ] Implement shop name/address/phone/footer singleton editing and restart persistence. Wire printer/backup settings entry points to later stages.
- [ ] Test availability, category filtering, soft deletion, invalid price input, missing local image fallback and restored image path handling.

Gate: `flutter test test/products test/settings` passes and screens match Stitch at the target phone size. Commit catalog/settings stage.

## Stage 3 — Selling and order management

Files: `lib/features/sales/{sales_screen,cart_controller,review_screen}.dart`, `lib/features/orders/{orders_screen,order_details_screen}.dart`; `test/sales/`, `integration_test/order_flow_test.dart`.

Interfaces: `CartController` owns the current draft; `Future<int> submitForPrint(OrderDraft draft)` in order_service commits via Stage 1 then hands the ID to Stage 4 coordinator. Bind a fake coordinator only in tests until Stage 4 is integrated.

- [ ] Implement grid/search/category quick-add, quantities, optional separate notes, total and optional order type. Lines with different notes stay distinct. Retain the cart while navigating tabs.
- [ ] Implement review → save → clear submitted draft → return to selling. Do not wait for printer completion. Double taps share one submission token.
- [ ] Implement All/UNPAID/PAID, details, mark-paid, cancellation and reprint against existing IDs. A saved order is not editable as a new cart.
- [ ] Test transaction failure preserves draft and prints zero bytes; commit precedes coordinator call; second sale can start during first print; delayed first result never clears second cart; reopen exposes saved orders.

Gate: `flutter test test/sales test/orders` and `flutter test integration_test/order_flow_test.dart -d <device-id>` pass. Prototype comparison verifies navigation/back behavior and one-handed controls. Commit sales/orders stage.

## Stage 4 — Real printer integration before hardware arrives

Files: `lib/printing/{printer_transport,bluetooth_transport,receipt_renderer,esc_pos_encoder,print_coordinator}.dart`, `lib/features/settings/printer_screen.dart`, `android/app/src/main/AndroidManifest.xml`; `test/printing/`. Native Kotlin adapter files only if the package gate fails.

Interfaces: `PrinterTransport` exposes `Future<List<PrinterDevice>> pairedDevices()`, `Future<void> connect(String address)`, `Future<void> disconnect()`, `Future<void> write(Uint8List bytes)`. `PrinterDevice` contains name/address. `ReceiptRenderer.render(SavedOrder)` returns bounded monochrome strips; `EscPosEncoder.encode(strips)` returns raw bytes. `Future<void> printOrder(int orderId)` serializes attempts and metadata without creating orders. Test print generates sample bytes without creating sales or changing revenue.

- [ ] Write fake-transport tests for serialization, duplicate taps, connect/write timeout, permission denial, partial write, metadata failure, retry, reconnect and manual disconnect.
- [ ] Implement Android paired-printer selection, Bluetooth enable/pair guidance, permission request, connect/disconnect, remembered device, bounded active-app reconnect and test print. Add scan only if the approved selection flow requires it.
- [ ] Implement ASCII fixtures then Vietnamese font rasterization and 58mm layout. Pin byte fixtures for init/feed/image commands; verify long names/notes, 45.000đ, accent composition and strip boundaries. Prevent arbitrary text from becoming ESC/POS control bytes.
- [ ] Implement attempt insertion before I/O, success bookkeeping, interrupted/unknown recovery and visible retry referencing saved ID. Never automatically retry an uncertain write.
- [ ] Wire the real adapter on `feature/full-pos`; execute Android plugin build/launch and disconnected-printer flows. Label physical output unverified.

Gate: `flutter test test/printing test/orders`, `flutter analyze`, `flutter build apk --debug` pass. Simulated failures show committed order survival and unchanged payment/revenue. Hardware-unverified status persists even if all software checks pass. Commit real printing implementation.

## Stage 5 — Revenue

Files: `lib/features/revenue/{revenue_repository,revenue_screen,revenue_chart}.dart`; `test/revenue/`.

Interface: `Future<RevenueSummary> summarize(DateTime startUtc, DateTime endUtc)` uses half-open ranges derived from Vietnam days. Summary contains paidRevenue, createdOrderCount, unpaidAmount, bestSellers and dailyPaidRevenue. Apply reviewed definitions consistently.

- [ ] Write fixtures spanning midnight/month boundaries, created-yesterday/paid-today, cancelled paid orders, unpaid orders and repeated print attempts.
- [ ] Implement today, seven calendar days and current month queries; aggregate persisted integer data, not transient cart state. Avoid multiplying totals by joining orders to multiple items.
- [ ] Render the prototype's simple chart with Flutter drawing/widgets where adequate; no additional chart dependency by default. Test zero-data view and large VND totals.

Gate: `flutter test test/revenue` passes. A 90000 order counts once, reprints change nothing, marking paid moves the expected amount and cancellation follows approved semantics. Commit revenue stage.

## Stage 6 — Local backup and safe restore

Files: `lib/backup/{backup_manifest,backup_service,restore_service}.dart`, `lib/features/settings/backup_screen.dart`; `test/backup/`, `integration_test/backup_restore_test.dart`.

Interfaces: `Future<StagedBackup> exportBackup()` produces a versioned private archive for local save. `Future<ValidatedBackup> validateBackup(Stream<List<int>> source)` validates before replacement. `Future<void> replaceWith(ValidatedBackup backup)` runs only after explicit user confirmation and exclusive database/print lock.

- [ ] Implement manifest/data/images archive and checksums, consistent export locking, and local Android picker/save cancellation handling. Include all tables, snapshots and image files.
- [ ] Test round-trip equality of orders, items, statuses, attempts, settings, integer money and images; export immediately after a committed order to catch WAL-related data loss designs.
- [ ] Implement staged validation and atomic active-generation switching. Reject unknown version, malformed JSON, duplicate IDs, FK/total mismatches, missing images, traversal paths and oversized expansion.
- [ ] Inject interruption before/after switch, disk-full, corrupted archive and failed reopen. Old data must remain recoverable; canceled restore leaves it intact. Restored orders never print automatically; pairing must be rechecked.

Gate: `flutter test test/backup` and `flutter test integration_test/backup_restore_test.dart -d <device-id>` pass with Internet disabled. Validate export and restore through local Android storage. Commit backup stage.

## Stage 7 — MP-58N hardware lab

Create `debug/mp58n` from the production candidate containing Stage 4's real printer code when hardware is available. Keep lab harness/evidence isolated from sales behavior. Record phone model, OS, printer label/firmware if exposed, package/commit versions, transport, photos and outcomes in `docs/verification/mp58n.md`.

- [ ] Verify pairing/paired selection, discovery if used, actual Classic/SPP endpoint and raw ASCII receipt.
- [ ] Test raster commands, printable dots, margins/feed, Vietnamese accents and đ, long lines and totals. Confirm no truncation, tofu glyphs, unintended cut or accent loss.
- [ ] Run 50 sequential receipts and a burst of 10 queued orders; verify order IDs, totals, paper order and no byte interleaving. Record latency to return to selling; investigate UI stalls.
- [ ] Test printer off at submit, Bluetooth off, out-of-range, mid-write disconnection, permission revoke/deny, reconnect, paper-out, app background/resume and process death after commit/during print. Keep uncertain output explicitly uncertain when printer status is unavailable.
- [ ] Confirm retry references original ID and revenue unchanged; reconnect alone never replays a bill. Recheck backup while printer jobs exist and restore's exclusive lock.

Gate: all required cases have physical evidence; unsupported protocol or Vietnamese output blocks declaring compatibility. Integrate only verified production fixes from `debug/mp58n` into `feature/full-pos` by reviewed cherry-pick/merge; exclude lab-only entry points. Repeat critical hardware tests on the integrated candidate, not only on the lab branch.

## Stage 8 — Production candidate acceptance

- [ ] Run `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, device integration tests and `flutter build apk --release` with approved signing setup. Never commit signing secrets.
- [ ] Confirm restart persistence, full offline sales/payment/reprint/revenue/backup/restore on the target phone; test with Internet disabled and Bluetooth enabled separately.
- [ ] Compare all five destinations to approved Stitch; validate touch targets, keyboard overflow, small screens and Vietnamese text. No invented features.
- [ ] Run saved-schema migration tests for every migration introduced; retain fixture of populated earlier schema. Verify native SQLite compatibility on selected Android API/device configurations.
- [ ] Record candidate commit, lockfile, test outputs and hardware verification status in `docs/verification/release.md`. Distinguish debug APK, signed release candidate and hardware verification. Review before shop use.

## Review focus

1. Crash after paper output but before attempt completion: Stage 4/7 proves unknown status and no automatic resend.
2. Save double tap, lost callback and delayed print result: Stage 1/3 proves one ID and preservation of the next cart.
3. Paid-date revenue versus created-date counts at midnight: Stage 5 proves approved definitions and no print-related inflation.
4. Restore interruption or malformed archive: Stage 6 proves previous database/images survive and unsupported input changes nothing.
5. Vietnamese raster buffer overflow on a long bill: Stage 4/7 proves bounded strips and physical readability.

## Handoff

Current deliverable is documentation only. Toolchain checks are observations; all build/test/hardware gates above remain unexecuted. Review both documents and the explicitly proposed rules before production work. Native execution is the small-project default recommendation; choose another execution approach if desired during review.

