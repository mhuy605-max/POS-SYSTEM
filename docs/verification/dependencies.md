# Stage 0 dependency review — 2026-09-30

Resolved against Flutter 3.47.5 / Dart 3.13.4. Direct versions are pinned in pubspec.yaml; transitive versions and archive hashes are in pubspec.lock. No dependency overrides or replacement package registries are used. Pub reports newer transitive releases outside current constraints; this is informational, not a failed solve.

| Dependency | Version | License | Stage 0 decision |
|---|---|---|---|
| drift | 2.35.0 | MIT | Accepted; typed SQLite, no tables implemented yet |
| drift_flutter | 0.3.1 | MIT | Accepted; current sqlite3 native-asset integration |
| flutter_riverpod | 3.4.3 | MIT | Accepted; handwritten Provider and ProviderScope only |
| go_router | 18.0.2 | BSD-3-Clause | Accepted; explicit NoTransitionPage for the neutral tab shell |
| file_picker | 13.1.0 | MIT | Accepted; Android local open/save support, feature usage deferred |
| path_provider | 2.1.6 | BSD-3-Clause | Accepted; private files, feature usage deferred |
| archive | 4.3.0 | MIT | Accepted; backup implementation deferred |
| drift_dev | 2.35.0 | MIT | Development only; generator matches Drift |
| build_runner | 2.16.1 | BSD-3-Clause | Development only; no data code generated in Stage 0 |
| flutter_lints | 6.0.0 | BSD-3-Clause | Development only |

flutter_test and integration_test come from the pinned Flutter SDK. Reviewed installed package LICENSE and CHANGELOG files, package manifests and relevant source entry points. These are suitability checks, not a complete audit of every transitive dependency.

## Printer gate: rejected package, approved architectural fallback

Downloaded `print_bluetooth_thermal` 1.2.5 from the [official pub archive](https://pub.dev/packages/print_bluetooth_thermal) and verified SHA-256 `2b26ba9328c52ad9d0caaefaf94b40f754005677b3c5ac899f56b857cbaec645` before reading its Android source.

In `android/src/main/kotlin/app/web/groons/print_bluetooth_thermal/PrintBluetoothThermalPlugin.kt`:

- `handleWriteBytes` performs blocking write/flush directly from the main-thread MethodChannel handler.
- It prepends LF to every supplied raw payload, including potential chunk boundaries.
- `checkConnectionStatus` writes a space to the printer, so checking status changes output.
- Connect uses Dispatchers.IO but the socket is only a local variable and there is no explicit timeout/cancellation path to close a pending connection.
- Permission checks require SCAN as well as CONNECT even for paired-only operations.

This fails the Stage 0 transport requirements. It is **not** in pubspec or the lockfile. The design already authorizes a small owned Kotlin RFCOMM adapter when this gate fails; implement that in Stage 4 with background I/O, socket cancellation, byte-preserving writes and non-writing connection state. No fake production transport or printer behavior was added to the scaffold.

`esc_pos_utils_plus` 2.0.4 (last release 2024-09-01) and `flutter_esc_pos_utils` 1.0.1 (2024-05-03) do not meet the requested actively-maintained preference. Do not lock them. Stage 4 will own the narrow init/raster/feed encoder described in the plan, with byte fixtures and physical command verification. This costs a small amount of maintained protocol code and avoids relying on stale generators. No ESC/POS implementation occurs in Stage 0.

## Open issue assessment and later verification

- [Drift issues](https://github.com/simolus3/drift/issues): sampled current reports concern web/macOS and query/generator enhancements; no observed Stage 0 Android blocker. Stage 1 must validate real transactions/migrations.
- [Riverpod #4882](https://github.com/rrousselGit/riverpod/issues/4882): TickerMode/diamond-dependency resume issue. Current shell uses a single router provider; async feature controllers must receive lifecycle tests later. Do not use experimental Riverpod persistence in place of SQLite.
- [go_router #192761](https://github.com/flutter/flutter/issues/192761): SDK MaterialApp transitions versus new material_ui route behavior. The tab shell explicitly uses NoTransitionPage; future detail-screen transitions require tests.
- [file_picker #1258](https://github.com/vicajilau/flutter_file_picker/issues/1258): activity destruction during a picker. Backup/restore must stage and recover independently of picker callbacks. [#2225](https://github.com/vicajilau/flutter_file_picker/issues/2225) concerns Android encoded paths; use file byte/stream APIs and verify local storage rather than blindly treating URI strings as paths.
- [archive #411](https://github.com/brendan-duncan/archive/issues/411): Windows ZIP separator handling. Construct portable slash-separated archive entries and test traversal and relative-path validation in Stage 6.
- [path_provider Android reports](https://github.com/flutter/flutter/issues?q=is%3Aissue+is%3Aopen+path_provider+android): external/SD-card limitations do not replace Android SAF export; use app-private paths for live files.
- [Printer tracker](https://github.com/andresperezmelo/print_bluetooth_termal/issues): build compatibility and error/status reports support requiring source inspection rather than relying on recent publication alone.

All physical printer assertions remain unverified until the MP-58N lab gate.
