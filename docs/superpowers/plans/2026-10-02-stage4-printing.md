# Stage 4 Bluetooth and ESC/POS Printing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the software printing stack for saved orders through a replaceable Flutter printer abstraction and native Android Bluetooth Classic SPP transport, without claiming physical MP-58N compatibility.

**Architecture:** Dart owns receipt rasterization, print orchestration, attempt persistence, and UI state. A narrow method-channel transport sends already encoded ESC/POS bytes to Kotlin, where Android handles permissions, paired-device enumeration, RFCOMM connection, chunked writes, disconnect, and ambiguous-write errors. Order creation commits and clears the cart before printing begins.

**Tech Stack:** Flutter/Dart, Riverpod, Drift/SQLite, `dart:ui` raster rendering, Android Kotlin, Bluetooth Classic RFCOMM/SPP, ESC/POS `GS v 0` raster commands.

**Spec:** `C:/Users/ACER/.codex/attachments/5062fded-6a9f-4b5f-81ea-34e1bbb9a641/Pasted text.txt`

## Global Constraints

- Keep all work on `feature/full-pos`; do not start Revenue, Backup/Restore, or Stage 7 hardware acceptance.
- Persist the order transaction before any Bluetooth call; printer failure never rolls back or removes the order.
- Use saved product and receipt-setting snapshots for initial prints and reprints.
- Treat successful Bluetooth writes as software-level transmission only, never proof of paper output.
- Never automatically resend an ambiguous transmission.
- Do not expose `auto_print`; do not introduce a Bluetooth package without a demonstrated need.
- CANCELLED orders cannot print or reprint.

## Review Focus

- A write that may have started then fails returns an unknown outcome, records it without incrementing `print_count`, and never auto-retries.
- Attempt persistence failure after byte transmission remains visible as uncertain and does not cause an automatic resend.
- Rapid **In bill** taps share one save/print operation and allocate one order number.
- Android 12+ permission denial and unavailable/disabled adapters produce stable error states without crashes or silent enabling.
- Long Vietnamese receipts remain 384 dots wide, banded into bounded ESC/POS raster writes, and use snapshot data only.

---

### Task 1: Printer domain, receipt rasterizer, and attempt repository

**Files:**
- Create: `lib/features/printing/printer_models.dart`
- Create: `lib/features/printing/receipt_renderer.dart`
- Create: `lib/features/printing/print_attempt_repository.dart`
- Test: `test/printing/receipt_renderer_test.dart`
- Test: `test/printing/print_attempt_repository_test.dart`

**Interfaces:**
- Produces: `ReceiptRenderer.renderOrder(SavedOrder)`, `ReceiptRenderer.renderTestPage()`, and `PrintAttemptRepository.record(orderId, result)`.
- Produces: typed sent, failed, and unknown outcomes plus stable printer error codes.

- [ ] Write failing renderer tests for Vietnamese snapshot text, deterministic non-empty 384-dot raster payloads, and bounded bands.
- [ ] Run the focused tests and confirm failure because the APIs do not exist.
- [ ] Implement the raster layout and ESC/POS encoder using bundled Plus Jakarta Sans glyphs and 48-byte raster rows.
- [ ] Write failing persistence tests for sent/failed/unknown attempts and `print_count` semantics.
- [ ] Implement independent attempt insertion; update `print_count`/`printed_at` only for sent results.
- [ ] Run both focused test files and confirm they pass.

### Task 2: Replaceable transport and save-then-print orchestration

**Files:**
- Create: `lib/features/printing/printer_transport.dart`
- Create: `lib/features/printing/printer_service.dart`
- Create: `lib/features/printing/printer_providers.dart`
- Modify: `lib/features/sales/cart_controller.dart`
- Modify: `lib/features/sales/review_screen.dart`
- Modify: `lib/features/sales/sales_screen.dart`
- Test: `test/printing/printer_service_test.dart`
- Modify: `test/sales/cart_controller_test.dart`
- Modify: `test/sales/sales_widget_test.dart`

**Interfaces:**
- Consumes: renderer and attempt repository from Task 1.
- Produces: `PrinterService.printOrder`, `PrinterService.reprintOrder`, `PrinterService.testPrint`, and `OrderSubmissionResult`.

- [ ] Write failing tests proving persistence and cart clear precede transport, failures preserve UNPAID orders, retries/reprints create no order, cancelled orders reject reprint, snapshot mutations do not affect payloads, test print creates no order, and rapid submits share one operation.
- [ ] Run tests and confirm behavioral failures.
- [ ] Implement the fake-friendly transport contract and printer service with no automatic retry.
- [ ] Adapt cart submission to commit, clear, print, then return an accurate transmission result for feedback.
- [ ] Run focused service/cart/widget tests and confirm they pass.

### Task 3: Printer settings UI and persistence

**Files:**
- Create: `lib/features/printing/printer_settings_repository.dart`
- Create: `lib/features/printing/printer_settings_controller.dart`
- Create: `lib/features/settings/settings_screen.dart`
- Create: `lib/features/settings/printer_settings_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/orders/order_details_screen.dart`
- Test: `test/printing/printer_settings_test.dart`
- Modify: `test/orders/orders_widget_test.dart`

**Interfaces:**
- Consumes: transport discovery/state and `PrinterService`.
- Produces: saved device name/address, paired-device selection, permission request, reconnect, test print, and explicit eligible-order reprint UI.

- [ ] Write failing controller/widget tests for no printer, denied permission, unavailable/disabled Bluetooth, selection persistence, reconnect, test print, explicit reprint, cancelled disabled state, and accurate sent/failed/unknown copy.
- [ ] Implement repository/controller and Stitch-aligned settings screens without an auto-print toggle.
- [ ] Connect order-detail reprint to the existing saved order and refresh attempt/count state.
- [ ] Run focused settings and order widget tests and confirm they pass.

### Task 4: Native Android Bluetooth Classic transport

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/example/dakao_in_bill/MainActivity.kt`

**Interfaces:**
- Consumes: method-channel calls `getState`, `requestPermissions`, `listPairedDevices`, `connect`, `write`, and `disconnect`.
- Produces: adapter/permission/device states and typed success/failure/unknown results.

- [ ] Add Android 12+ `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` declarations plus legacy permissions capped at API 30.
- [ ] Implement paired-device enumeration and RFCOMM SPP connection without continuous discovery or silent Bluetooth enablement.
- [ ] Implement bounded chunk writes; any error after a write begins is returned as unknown outcome.
- [ ] Build the debug APK to verify Kotlin and manifest integration.

### Task 5: Emulator verification, documentation, and commit

**Files:**
- Create: `docs/verification/stage4/README.md`
- Create: `docs/verification/stage4/*.png`
- Modify: `integration_test/order_flow_test.dart`

**Interfaces:**
- Consumes: all Stage 4 production surfaces.
- Produces: reproducible automated and API 36 evidence, exact hardware assumptions, and one focused commit.

- [ ] Add an integration path with injected fake transport proving save-before-print and persistence across app rebuild.
- [ ] Run formatter, analyzer, all tests, API 36 integration, and debug APK build.
- [ ] On API 36 verify settings/no-printer/permission states, failed print retaining the order, explicit retry, cancelled reprint disablement, restart persistence, and no crashes.
- [ ] Document software-level success semantics, emulator limitations, paired-device-only strategy, and every Stage 7 hardware assumption.
- [ ] Obtain a fresh whole-change review, fix all critical/important findings with regression tests, rerun the gate, commit once, verify a clean worktree, and stop before Stage 5.
