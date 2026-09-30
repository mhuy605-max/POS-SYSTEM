# Đakao In Bill — technical design for review

Status: approved with user decisions, 2026-09-30. Stage 0 only is authorized; stop and report before Stage 1. Companion: [implementation plan](../plans/2026-09-30-dakao-in-bill.md).

## Purpose and scope

Offline-first Flutter/Dart Android application for a small Vietnamese food shop: select food → review → save locally → attempt 58mm Bluetooth printing → return to selling → mark the saved order paid later. Persistence takes precedence over printing. All new orders are UNPAID. VND is integer-only; 45000 displays as 45.000đ.

Five destinations: **Bán hàng, Đơn hàng, Doanh thu, Món, Cài đặt**. Reproduce the existing approved Google Stitch prototype with orange/white styling, large touch targets, and one-handed phone use. The prototype was not supplied or found locally; layouts, assets, and exact interaction details cannot yet be verified. Do not invent a redesign.

Included: product grid/search/category filters, quantities and item notes, optional dine-in/takeaway, review/print; All/UNPAID/PAID order filters, details, payment marking, cancellation and reprint; today/7 days/month revenue, order count, unpaid amount, best sellers and simple visualization; product/category maintenance, availability, soft deletion; printer selection/connect/disconnect/reconnect/test/retry; receipt settings and local backup/restore.

Excluded: login, employees, cloud/backend, payment gateway or methods, cash/change, inventory/ingredients, tax/VAT, tables, subscriptions, server deployment. No Internet dependency at runtime; fonts/assets must be bundled. No refund or saved-order editing workflow is added.

## Environment inspection

Observed in `C:\Users\ACER\Documents\WEB_PROJECT\DAKAOINBILL` before writing these documents:

| Check | Result |
|---|---|
| Folder, including hidden entries | 0 entries; no scaffold, pubspec, source, prototype or local AGENTS.md |
| Git status / repository root | Both report not a Git repository; no branches, history or remote to inspect |
| Git executable | 2.49.0.windows.1 at `C:\Program Files\Git\cmd\git.exe` |
| Java | Oracle Java 21.0.11; `C:\Program Files\Java\jdk-21.0.11` exists |
| Flutter, Dart, adb, sdkmanager, Gradle, FVM | Not found on PATH |
| ANDROID_HOME / ANDROID_SDK_ROOT / JAVA_HOME | Unset |
| Common Flutter/Android locations | No SDK found in checked user, C:\src, C:\tools, C:\dev, C:\development, D:\flutter/D:\development or standard Android Studio/SDK locations |
| Pub cache | `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev` exists; a cache is not proof of a usable SDK |

These are bounded discovery results, not proof that no SDK exists anywhere on disk. `flutter doctor`, package resolution, emulator/device enumeration, analysis, tests and Android builds could not run. Java alone does not establish Android toolchain compatibility. No installations, Git initialization, branch creation or product scaffolding were performed.

## Dependency assessment

Versions and publication dates below were read from the official pub.dev API on 2026-09-30. They are research candidates, **not locked dependencies**. Recheck source, changelog/issues, licenses, SDK constraints and Android build behavior when implementing; then commit the application's lockfile. Release recency alone is not proof of reliability.

| Concern | Proposed choice / evidence | Alternatives and gate |
|---|---|---|
| Typed SQLite | [drift](https://pub.dev/packages/drift) 2.35.0 (2026-09-09), [drift_flutter](https://pub.dev/packages/drift_flutter) 0.3.1 (2026-07-11); Dart ≥3.10. Typed queries, transactions, migration tooling | [sqflite](https://pub.dev/packages/sqflite) 2.4.4 (2026-09-10) is viable but requires manual mapping/migration discipline. Prefer Drift for historical-data safety; accept its small code-generation cost |
| State | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3.4.3 (2026-09-03), Dart ^3.12; handwritten providers/controllers, no Riverpod generator | [provider](https://pub.dev/packages/provider) 6.1.5+1 (2025-08-19) or built-in notifiers reduce dependencies but require more manual async wiring. Avoid redundant service locator |
| Navigation | [go_router](https://pub.dev/packages/go_router) 18.0.2 (2026-09-28), Flutter ≥3.44 / Dart ^3.12; Flutter publisher | Built-in Navigator is viable. Prefer router shell for five destinations and details; no auth/deep-link product feature implied |
| Bluetooth transport | First build candidate: [print_bluetooth_thermal](https://pub.dev/packages/print_bluetooth_thermal) 1.2.5 (2026-09-28), Flutter ≥3.44, BSD-3-Clause. Paired-device list, connection and raw bytes fit V1 | Pair using Android settings, then select paired printer. Audit native I/O threading, timeouts and lifecycle before acceptance. App-side discovery is optional under the brief. Small Kotlin RFCOMM adapter is fallback if plugin fails |
| Other Classic options | [flutter_blue_classic](https://pub.dev/packages/flutter_blue_classic) 0.1.1 (2026-06-26) exposes discovery, bonding and byte output | GPL-3.0 and pre-1.0 maturity require a deliberate distribution/license decision; not default. [flutter_classic_bluetooth](https://pub.dev/packages/flutter_classic_bluetooth) is another recently released candidate, but rapid release history needs source review |
| Reject old default | [flutter_bluetooth_serial](https://pub.dev/packages/flutter_bluetooth_serial) 0.4.0 (2021-08-17), Dart <3 | Cannot resolve on the proposed modern Dart stack. BLE-only packages do not implement Classic SPP |
| ESC/POS | Conditional candidate: [esc_pos_utils_plus](https://pub.dev/packages/esc_pos_utils_plus) 2.0.4 (2024-09-01), BSD-3-Clause; text/raster generation | Not demonstrably actively releasing. [flutter_esc_pos_utils](https://pub.dev/packages/flutter_esc_pos_utils) 1.0.1 (2024-05-03) is not a freshness improvement. Do not silently lock either: source/fixture review or a narrowly scoped owned encoder for init/raster/feed must precede acceptance |
| Local file I/O | [file_picker](https://pub.dev/packages/file_picker) 13.1.0 (2026-09-15), Android open/save support; [path_provider](https://pub.dev/packages/path_provider) 2.1.6 (2026-06-15) for private storage | [file_selector](https://pub.dev/packages/file_selector) 1.1.0 is Flutter-maintained but its support matrix lacks Android save-location selection, so it does not cover backup export alone |
| Backup container | [archive](https://pub.dev/packages/archive) 4.3.0 (2026-09-13), ZIP containing versioned JSON plus images | Dart JSON only is simpler but does not conveniently bundle local product images. No live database-file copying |

Proposed compatible baseline: a stable Flutter release satisfying Flutter ≥3.44 and Dart ≥3.12, verified locally rather than inferred from cache. Propose Android minSdk 23 subject to the actual shop phone and resolved native dependencies; choose compile/target SDK, AGP, Gradle and JDK as a tested combination from that Flutter release. No arbitrary Java/Gradle upgrade here. Permission helper, image encoder, checksum and font dependencies are chosen only when the accepted adapters require them.

Three implementation approaches considered: (1) recommended small Flutter feature modules with Drift/Riverpod and replaceable printer adapter; (2) sqflite plus notifiers for fewer tools but more handwritten data logic; (3) the same app with native Kotlin printing from day one, giving tighter I/O control but more platform code. Start with (1), use (3) only if the package acceptance gate fails. Do not build multiple production transports speculatively.

## Small architecture

`lib/app/` owns bootstrap, theme and navigation. `lib/data/` owns one Drift database, schema and migrations. `lib/features/{sales,orders,revenue,products,settings}/` owns screens and small controllers/repositories. `lib/printing/` owns receipt rendering, one print coordinator and the hardware adapter. `lib/backup/` owns export/validation/restore. Shared money/date helpers live in `lib/core/` only when used across features.

Flow: widgets → feature controller → concrete repository → SQLite. A small order service coordinates saving and printing. Database query streams refresh order/revenue/product screens. Printer-specific objects never enter order logic. Inject the clock, database and `PrinterTransport` for deterministic tests. No generic repository hierarchy, event bus, domain layer per entity, network client or server.

## Data contract

Preserve every requested V1 field:

| Table | Fields |
|---|---|
| categories | id INTEGER PK, name TEXT NOT NULL, sort_order INTEGER, is_active BOOLEAN, created_at, updated_at |
| products | id INTEGER PK, category_id FK, name TEXT NOT NULL, description nullable, price INTEGER NOT NULL, image_path nullable, is_available BOOLEAN, sort_order INTEGER, created_at, updated_at, deleted_at nullable |
| orders | id INTEGER PK, order_number INTEGER NOT NULL, order_type DINE_IN/TAKEAWAY, status UNPAID/PAID/CANCELLED, subtotal INTEGER NOT NULL, total INTEGER NOT NULL, created_at, paid_at nullable, cancelled_at nullable, printed_at nullable, print_count INTEGER DEFAULT 0, cancellation_reason nullable |
| order_items | id INTEGER PK, order_id FK, product_id nullable FK, product_name_snapshot TEXT NOT NULL, unit_price_snapshot INTEGER NOT NULL, quantity INTEGER NOT NULL, note nullable, line_total INTEGER NOT NULL |
| print_attempts | id INTEGER PK, order_id FK, attempted_at, success BOOLEAN, error_message nullable |
| app_settings | singleton id=1; shop_name, address, phone, receipt_footer |
| printer_settings | singleton id=1; printer_name, printer_address nullable, auto_reconnect, auto_print |

SQLite BOOLEAN is INTEGER constrained to 0/1. Store times as UTC epoch milliseconds and use explicit Vietnam UTC+07 day boundaries for reporting. Foreign keys enabled on every connection. Require nonblank names, nonnegative integer prices/totals, positive integral quantities, allowed enums, and checked arithmetic within SQLite signed-64-bit limits. Reject invalid values before SQL and constrain persisted values. `line_total = unit_price_snapshot * quantity`; `subtotal = sum(line_total)`; `total = subtotal` because there are no discounts/taxes/fees. Validate cross-row invariants inside the order transaction.

Use UNPAID default, globally increasing unique `order_number` within the database, allocated inside the serialized write transaction (no daily reset). Cancelled orders keep their number. Index orders(status, created_at), orders(paid_at), order_items(order_id), print_attempts(order_id, attempted_at), products(category_id, deleted_at, is_available). Singletons use CHECK(id=1). Products are soft-deleted, categories deactivated; never cascade product/category changes into history. Optional product references never replace receipt snapshots. Saved line contents and totals are immutable; only allowed status/print metadata can change.

Approved technical additions: unique `orders.submission_token TEXT NOT NULL` for save idempotency, and `orders.receipt_settings_snapshot TEXT NOT NULL` containing the four shop fields so later receipt-setting edits cannot change reprints. These add reliability, not product features. Without the latter, the supplied schema preserves food lines but not the original receipt header/footer. No separate draft-persistence feature is introduced.

Version schema from V1; export schema snapshots and test every future upgrade using [Drift migration tooling](https://drift.simonbinder.eu/migrations/). Never delete/recreate a shop database to handle migration failure.

## Save, print, recover

1. Freeze the reviewed draft and its stable submission token; suppress duplicate taps while saving. Validate quantities, notes, availability and prices. If catalog data changed since review, require another review rather than silently charging a new price.
2. In one transaction, return an existing order for that token or allocate a number and insert UNPAID order, receipt settings and all item snapshots. COMMIT before any Bluetooth operation. Save failure retains the draft and sends zero bytes.
3. After commit, clear only that submitted draft and return to selling. Pass the saved ID to the serialized print coordinator; printing does not block entry of the next sale. Show saved order number and actionable print result using the prototype's interaction pattern.
4. Print/retry/reprint load that existing order's snapshots. They never invoke create-order or alter status/revenue. Only one job writes to the connection at a time. Suppress concurrent duplicate requests for the same order; an explicit later reprint is allowed.
5. Before I/O insert an attempt with `success=false` and `error_message=IN_PROGRESS`. Completion updates it, and successful full transport writes increment print_count and set printed_at in one transaction. Here success means bytes accepted by transport, **not proof of paper output**. Failures retain UNPAID unless a separate user action has marked the order paid.
6. On restart, unfinished attempts become `INTERRUPTED_UNKNOWN`; a crash after commit but before attempt creation still leaves the order visible and reprintable. Never automatically resend an uncertain job. A crash after physical printing but before metadata update cannot be made exactly-once with ordinary ESC/POS; retry may print a second paper receipt, but never a second order.

Auto reconnect reconnects a remembered device with bounded attempts while the app is active; it does not replay jobs. Manual disconnect stops reconnect until the user reconnects. No background service or persistent spooler. Pending in-memory jobs interrupted by process death remain recoverable from saved orders. Printer timeout/disconnection/permission denial never blocks selling.

## Printing and MP-58N risk

The listing's Bluetooth 3.0/4.0 and POS/ESC claims do not establish a working SPP endpoint or exact command set. Confirm on the physical unit: pairing, exposed Classic service, RFCOMM connection, raw bytes and raster command support. USB is not an additional V1 transport. Do not claim the advertised 90 mm/s was verified.

Follow [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions): paired-device connect on Android 12+ needs runtime CONNECT; add SCAN only for actual app discovery. Older discovery may require location permission, which paired-only selection avoids. Do not request ADVERTISE for a printer client. Follow [Android RFCOMM guidance](https://developer.android.com/develop/connectivity/bluetooth/connect-bluetooth-devices): blocking connection/I/O belongs off the UI thread; cancel discovery before connection. Audit the plugin for both.

Receipt content: shop snapshot, order number/date, optional order type, snapshot item names/quantities/prices/notes, total and footer. Do not label a new bill paid. Use 58mm paper profile with **384 printable dots as an initial assumption**, measured on hardware; paper width is not printhead width. No cut command unless supported. Wrap long Vietnamese names/notes and right-align integer money without clipping.

Vietnamese is the highest encoding risk. UTF-8 bytes are not universally supported by ESC/POS; neither CP1258 nor a named code page is guaranteed on this unit. Recommended initial Vietnamese route: render bundled Vietnamese-capable font to monochrome raster strips and encode supported ESC/POS image commands. That avoids printer-font code pages but still needs raster-command, memory, speed and chunk-size verification. ASCII first proves transport. Never silently remove accents in production. Compare precomposed/decomposed accents, Đ/đ, all vowel/tone combinations, and 45.000đ on paper. Package capability profiles are hints, not MP-58N proof.

## Backup and restore

Propose a `.dakbackup` ZIP: manifest with formatVersion=1, schemaVersion, appVersion, exportedAt UTC and entry checksums; data.json with all seven tables and integer money; images/ with referenced private images using relative paths. Export consistent rows in one read transaction under a short application write/asset-mutation lock, stage images, then release lock before the Android local save dialog. No Internet required; cloud file providers are not required to complete export.

Restore replaces the local dataset; it does not merge. Show backup date/order count and require explicit replacement confirmation in the app. Cancel or failed validation changes nothing. Validate manifest, supported versions, checksums, bounded archive sizes, safe relative paths, IDs/FKs, enum/timestamp/money invariants and totals before activation. Unknown future versions are rejected. This integrity check is not encryption or authentication.

Stage images in a new private generation and validate a temporary database. Pause writes/printing and close the old database. Switch an atomic local active-generation pointer only after staging is complete; retain previous generation until the new one reopens and passes integrity/FK checks. Startup recovers old/new generation after interruption. Never copy only an open SQLite main file while WAL may contain transactions. Restore settings/address but verify pairing locally before connecting; never auto-print restored orders. Document that restoring an older backup replaces newer sales and can reuse numbers that existed only in the discarded dataset.

## Approved business rules

The user approved these decisions on 2026-09-30 (order-count and period conventions retain the reviewed design defaults):

1. Revenue = totals of currently PAID orders whose paid_at falls in the period; no unpaid/cancelled totals. Example: order created yesterday and paid today contributes today. Best sellers use the same paid cohort and sum quantity, grouped by product ID with snapshot display labels; null references group by snapshot name.
2. Order count = noncancelled orders created in the period. Unpaid amount = all currently UNPAID orders, regardless of creation date or selected revenue period. Labels must distinguish period order count/revenue from current total unpaid amount. Seven days means today plus six preceding Vietnam calendar days; month means first of this month through now.
3. UNPAID → PAID or CANCELLED; PAID → CANCELLED allowed with confirmation and optional reason, preserving paid_at for history but excluding the order from current revenue calculations. CANCELLED is terminal. This is cancellation, not a refund ledger. Repeated mark-paid preserves the original paid_at. Cancelled orders remain in All/details; no new filter needed. Reprint is disabled for cancelled orders in V1.
4. Optional order type is nullable when not selected; selecting it stores DINE_IN or TAKEAWAY. This resolves optional UI against the listed enum without inventing a mandatory default.
5. Explicit Print Bill always saves and attempts printing. `auto_print` has no defined separate save trigger in the brief: retain it default true in schema if useful, with no auto-print toggle exposed in V1. Do not silently turn Print Bill into save-only.

## Review and release gates

Business rules and both schema additions are approved. Verify minimum Android support and the conditional printer dependency decision during implementation. Obtain the Stitch reference before UI implementation. Establish a working Flutter/Android toolchain before resolving versions. Software tests can validate order safety before hardware arrives; release cannot claim MP-58N support until the lab checklist passes on the actual unit.

No production code, tests, installs or builds were run in this planning task. The companion plan separates software-complete/hardware-unverified from hardware-verified.

