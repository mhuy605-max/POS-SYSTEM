# Stage 6 verification — Settings and backup/restore

- Date: 2026-10-02
- Branch: `feature/full-pos`
- Stage 5 base: `1913eb6cae567fc87e1370b375e70b057734dc8d`
- Stage 6 commit: this commit
- Scope: Settings, shop/receipt settings, local backup, validation, restore, and startup recovery only

## Delivered behavior

Settings now exposes the three approved V1 destinations: shop and receipt information, Bluetooth 58 mm printer settings, and backup/restore. There is no auto-print toggle. Shop name, address, phone, and receipt footer persist through the singleton settings row. The form trims values, requires a shop name, presents a live 58 mm preview, and states that changes apply only to future orders. Existing order receipt snapshots remain unchanged.

Backup uses Android's document picker and Storage Access Framework. It does not request broad storage access. The generated `.dakbackup` file is a deterministic ZIP archive with:

- `manifest.json`: magic `DAKAO_IN_BILL_BACKUP`, format version 1, database schema version 1, app version, UTC creation time, and SHA-256/byte-size metadata for every payload entry.
- `data.json`: canonical ID-ordered rows for categories, products, orders, order items, print attempts, app settings, and printer settings.
- `images/product-images/...`: every product image referenced by the exported catalog.

The archive preserves immutable order data including IDs, order numbers, submission tokens, statuses and timestamps, product snapshots, receipt settings snapshots, print counts, and print-attempt metadata. It excludes cache files, temporary files, recovery journals, Android platform state, and Bluetooth connection state. The archive is integrity checked but is not encrypted or authenticated; the UI tells the user to store it in a trusted location.

## Validation and restore safety

Restore validates the complete archive before replacing live data. Validation rejects malformed ZIP/JSON, duplicate or unsafe paths, symlinks, undeclared or missing entries, unsupported format/schema versions, size/hash mismatches, archive/entry/expanded/row-limit violations, understated ZIP expansion, invalid table sets, duplicate identifiers, bad foreign keys/enums/totals/status timestamps, invalid singleton settings, invalid receipt snapshots, missing/unknown images, corrupt image payloads, and image dimension/pixel bombs. Product images are fully decoded after an 8192-pixel edge and 16,777,216-pixel total limit.

Database replacement runs in one Drift transaction, deleting children before parents and inserting parents before children while preserving explicit IDs and rebuilding SQLite sequences. The app writes a flushed recovery journal before replacement. Image activation copies to a sibling staging directory and swaps directories by rename. The marker is atomically retired before journal cleanup. Startup either completes the target state or restores the old canonical database and complete old-image snapshot. Interrupted journal cleanup and partial sibling cleanup cannot become recovery authority.

After a successful restore, Riverpod invalidates catalog, order, revenue, shop, printer, and cart state. A cart created from pre-restore products receives a new submission token. A live Bluetooth connection whose address differs from the restored printer identity is disconnected and shown as unverified.

Restore never connects to or prints through Bluetooth.

## Automated verification

Final results on the completed Stage 6 tree:

- `dart format --output=none --set-exit-if-changed lib test integration_test`
- `flutter analyze` — no issues.
- `flutter test` — all 141 tests passed, including archive format, hostile input, full seven-table round trip, historical snapshots, revenue equivalence, rollback/recovery crash windows, responsive settings UI, cart reset, and printer identity reconciliation.
- `flutter test integration_test/backup_restore_test.dart -d emulator-5554` — passed with a file-backed Drift database and app-private image files on Android API 36; covers export, mutation, validation, restore, reopen, statuses, revenue, and snapshots.
- `flutter build apk --debug` — passed and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — passed; Git reported only the repository's Windows line-ending conversion notices.

Independent final review reported no remaining Critical or Important findings.

## Manual API 36 verification

Manual checks used `Dakao_API_36` through the normal Flutter/ADB toolchain:

- normal production-provider launch;
- Settings root at Android phone width, with three approved entries and no auto-print control;
- printer entry showing the real permission state without connecting;
- shop form, live receipt preview, save, force-stop/relaunch persistence, and future-orders-only wording;
- real Android DocumentsUI save and open flows;
- compatible backup summary before confirmation;
- explicit destructive restore confirmation and completion state;
- malformed `.dakbackup` rejection without replacing live settings;
- catalog/category/product with a selected app-private product image;
- PAID and CANCELLED orders using the saved product and immutable receipt snapshot.

The Android integration test supplies the complete UNPAID/PAID/CANCELLED data set and verifies restored image bytes, revenue, snapshots, tokens, print metadata, and reopen persistence. Physical MP-58N connectivity and receipt output remain intentionally unverified until Stage 7.

## Stitch comparison

The Settings and backup screens use the approved Stitch reference documented in `docs/design/stitch-reference.md`: Plus Jakarta Sans, the warm orange primary action, pale blue surfaces, rounded cards, bold section hierarchy, bottom navigation, and Vietnamese labels. Flutter widgets and Android document pickers implement the approved behavior; generated Stitch HTML was not used as application code or architecture.

## Evidence

- `stage6-settings-root.png`
- `stage6-shop-settings.png`
- `stage6-shop-saved.png`
- `stage6-shop-persisted.png`
- `stage6-backup-screen.png`
- `stage6-save-picker.png`
- `stage6-backup-saved.png`
- `stage6-open-picker.png`
- `stage6-backup-validation.png`
- `stage6-restore-confirmation.png`
- `stage6-restore-complete.png`
- `stage6-invalid-rejected.png`
- `stage6-catalog-with-image.png`
- `stage6-orders-mixed-status.png`

## Remaining limits

- MP-58N behavior remains hardware-unverified until physical Stage 7 testing.
- SHA-256 detects accidental or malicious modification but does not prove who created an archive and does not hide its contents.
- Restore supports only backup format 1 and database schema 1. A future migration requires an explicit compatibility path.
- The emulator briefly disconnected during the broader session and was relaunched; final API 36 integration verification was run against a connected `emulator-5554`.
