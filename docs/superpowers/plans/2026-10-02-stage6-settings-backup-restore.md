# Stage 6 Settings and Backup/Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the approved Settings experience and a safe, versioned `.dakbackup` export/restore workflow covering all seven Drift tables and referenced product images.

**Architecture:** Settings remain a small Riverpod/repository feature. Backup exports a canonical JSON snapshot from a Drift read transaction, packages it with referenced image bytes and a SHA-256 manifest in a ZIP, and hands bytes to Android's Storage Access Framework through `file_picker`. Restore validates and stages the complete archive before mutation, replaces all tables in one Drift transaction, activates staged images, and uses a private recovery journal containing the previous canonical data/images so startup can finish or roll back an interrupted operation without copying an open SQLite file.

**Tech Stack:** Flutter/Dart, Riverpod, Drift/SQLite, `archive` 4.3.0, `file_picker` 13.1.0, `crypto` 3.0.7, Android API 36.

**Spec:** `docs/superpowers/specs/2026-09-30-dakao-in-bill-design.md`, Stage 6 of `docs/superpowers/plans/2026-09-30-dakao-in-bill.md`, and `C:/Users/ACER/.codex/attachments/f6ba291c-fd17-49ce-af0e-1ade2b13c780/Pasted text.txt`.

## Global Constraints

- Stage 6 only; do not start physical MP-58N testing or production acceptance.
- Include all seven V1 tables, immutable order/receipt snapshots, statuses/timestamps/print metadata, singleton settings, and referenced app-owned product images.
- Preserve IDs and foreign-key relationships; restore replaces the dataset and never merges or prints.
- `.dakbackup` is a ZIP with `manifest.json`, canonical `data.json`, and portable `images/` entries; format version is exactly `1`.
- Validate magic, versions, required entries, SHA-256/size metadata, safe paths, bounded expansion, IDs, enums, totals, singletons, image references, and relationships before live mutation.
- Integrity checks are not encryption or authentication; UI copy must not claim either.
- Use Android document open/save APIs without broad storage permissions or unrestricted external paths.
- Existing receipt snapshots remain immutable; edited shop settings affect future orders only.
- Produce one focused Stage 6 commit and leave the working tree clean.

## Review Focus

- A ZIP with duplicate/traversal/oversized entries must be rejected before any table or image mutation.
- A crash or injected failure after the database transaction but before image activation must be recoverable from the private journal without leaving mixed data.
- Restore row ordering must satisfy foreign keys and preserve explicit IDs, order numbers, submission tokens, snapshots, singleton IDs, and print attempts.
- Missing, extra, corrupted, or aliased image paths must not escape the private image root or silently produce a partial restore.
- Backup/restore must not call `PrinterTransport`, reconnect, or reinterpret restored orders for revenue.

---

### Task 1: Complete Stage 6 settings and safe local backup/restore

**Files:**
- Create: `lib/features/settings/shop_settings_repository.dart`
- Create: `lib/features/settings/shop_settings_controller.dart`
- Create: `lib/features/settings/shop_settings_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/app/router.dart`
- Create: `lib/backup/backup_models.dart`
- Create: `lib/backup/backup_data_codec.dart`
- Create: `lib/backup/backup_service.dart`
- Create: `lib/backup/backup_validator.dart`
- Create: `lib/backup/restore_service.dart`
- Create: `lib/backup/backup_file_gateway.dart`
- Create: `lib/backup/backup_providers.dart`
- Create: `lib/features/settings/backup_screen.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `test/settings/shop_settings_test.dart`
- Create: `test/settings/settings_widget_test.dart`
- Create: `test/backup/backup_service_test.dart`
- Create: `test/backup/backup_validation_test.dart`
- Create: `test/backup/restore_service_test.dart`
- Create: `test/backup/backup_widget_test.dart`
- Create: `integration_test/backup_restore_test.dart`
- Create: `docs/verification/stage6/README.md`

**Interfaces:**
- `ShopSettingsRepository.load()`, `watch()`, and `save(ShopSettingsDraft)` read/update singleton `app_settings` row `id=1`.
- `BackupDataCodec.exportCanonical()` returns stable UTF-8 JSON for all seven tables ordered by ID; `replaceWithCanonical(Uint8List)` validates/imports explicit IDs in one transaction.
- `BackupService.createArchive()` returns `StagedBackup(bytes, suggestedFileName, manifest)` without modifying live data.
- `BackupValidator.validateBytes(Uint8List)` returns `ValidatedBackup` only after complete archive/data/image validation.
- `RestoreService.replaceWith(ValidatedBackup)` journals old state, stages target images, replaces data transactionally, activates images, and invokes recovery on failure.
- `BackupFileGateway.saveBackup(...)` and `pickBackup()` isolate Android document APIs from controllers/tests.
- Startup calls recovery before `runApp`; a present journal compares the canonical live-data SHA-256 with the target and either finishes target image activation or restores the old canonical state/images.

- [ ] **Step 1: Write failing shop-settings repository and snapshot tests.** Assert persistence after reopen, trimmed sensible validation, old order `receipt_settings_snapshot` remains byte-for-byte unchanged, and a new order captures updated fields.
- [ ] **Step 2: Run `flutter test test/settings/shop_settings_test.dart`.** Expected: compile failure because the repository API does not exist.
- [ ] **Step 3: Implement the settings repository/controller.** Save only the singleton row and leave historical order rows untouched.
- [ ] **Step 4: Run the focused settings tests.** Expected: all pass.
- [ ] **Step 5: Write failing backup creation tests.** Use a real Drift database and real temp image root; assert deterministic seven-table data, format version `1`, exact IDs/snapshots/statuses/print metadata, soft deletion, referenced images, SHA-256 entries, and no database/image/printer mutation.
- [ ] **Step 6: Run `flutter test test/backup/backup_service_test.dart`.** Expected: compile failure because backup APIs do not exist.
- [ ] **Step 7: Implement canonical data export, models, manifest, and ZIP creation.** Add direct `crypto: 3.0.7`; use portable slash paths and bounded app-owned relative image paths.
- [ ] **Step 8: Run backup creation tests.** Expected: all pass.
- [ ] **Step 9: Write failing validation tests.** Cover malformed ZIP/JSON, wrong magic, unsupported future version, missing required table/entry, duplicate/traversal path, checksum/size mismatch, unknown image, missing image, oversized entry/archive, duplicate IDs/tokens/numbers, bad FK/enums/totals/singletons, and corrupt image bytes.
- [ ] **Step 10: Run `flutter test test/backup/backup_validation_test.dart`.** Expected: compile failures or validation assertions fail because validation/import is absent.
- [ ] **Step 11: Implement archive and business-content validation.** Validate in memory and through a temporary real SQLite database with foreign keys before producing `ValidatedBackup`; never mutate the live database.
- [ ] **Step 12: Run validation tests.** Expected: all pass.
- [ ] **Step 13: Write failing restore/recovery tests.** Round-trip categories/products/images/orders/items/attempts/settings, all statuses and timestamps, order numbers/tokens/snapshots, revenue equivalence, reopen persistence, immutable restored history after catalog edits, zero printer calls, injected failures before/after DB replacement, and startup journal recovery.
- [ ] **Step 14: Run `flutter test test/backup/restore_service_test.dart`.** Expected: compile failure because restore/recovery APIs do not exist.
- [ ] **Step 15: Implement transactional replacement, staged image activation, and the private recovery journal.** Import parents before children, delete children before parents, preserve singleton rows, use an explicit confirmation only in UI, and invalidate affected Riverpod state after success.
- [ ] **Step 16: Run restore tests and reopen checks.** Expected: all pass.
- [ ] **Step 17: Write failing Settings/backup widget tests.** Cover the three Settings entries, shop form/preview/save, destructive restore confirmation, validation summary/error, picker cancellation, busy states, Vietnamese text, keyboard/scroll behavior, and 360/390/430 logical pixels.
- [ ] **Step 18: Run `flutter test test/settings test/backup/backup_widget_test.dart`.** Expected: compile/navigation failures because screens/routes/controllers are absent.
- [ ] **Step 19: Implement Stitch-aligned Settings, shop/receipt, and backup/restore screens plus file gateway.** Reuse Stage 4 printer route; omit auto-print and generated `.json`/`.bak`, security absolutes, scheduled-backup claims, and simulated success states.
- [ ] **Step 20: Run widget tests.** Expected: all pass without overflow.
- [ ] **Step 21: Add the API 36 integration test.** Exercise real file bytes and production database/image services for export → mutate → validate → confirm restore → persistence/revenue/snapshot/no-print assertions; document any Android picker interaction that the emulator provider cannot automate.
- [ ] **Step 22: Run the complete verification gate.** Format, analyze, full Flutter suite, Stage 6 API 36 integration, debug APK build/install/launch, normal-app manual flow, invalid-file survival, restart persistence, and Stitch comparison must pass.
- [ ] **Step 23: Request one fresh whole-change review.** Fix validated Critical/Important findings in one TDD pass, record rulings/deferred minors, and rerun the full gate.
- [ ] **Step 24: Update `docs/verification/stage6/README.md`, make the single focused Stage 6 commit, verify a clean tree, and stop before Stage 7.**
