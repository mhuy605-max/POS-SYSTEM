# UI + Motion Polish V2 verification

## Source

- Branch: `polish/ui-v2`
- Base: `9204482642d10c17ac60213e15d8b605408a5b18` (`feat: complete settings and backup restore`)
- Final commit: `feat: polish UI and motion system` (the commit containing this record; its immutable SHA is reported at handoff)
- UI + Motion V2 changes presentation only.
- Stage 7B physical MP-58N verification remains pending.

## Art direction and shared system

The V2 direction is **Warm Utility**: warm neutral canvas and fields, white primary surfaces, burnt-orange brand actions, restrained semantic colors, minimal elevation, and tighter POS-oriented hierarchy. Plus Jakarta Sans remains the application typeface.

The centralized palette uses `#B9470B` for brand/action/selection, `#923607` for strong brand states, `#FBE9DE` for soft brand surfaces, `#FAF8F5` for the canvas, `#F3F0EB` for secondary surfaces, and `#E8E2DC` for borders. Paid/success uses muted green, unpaid/pending uses warm amber, and cancelled/error uses muted red.

`lib/app/design_system.dart` centralizes the 4 px spacing scale, radii, touch and icon sizes, motion durations and curve, semantic status tones, loading/error/empty states, animated values, bottom action surfaces, and tactile press feedback. `lib/app/theme.dart` supplies coherent component themes for cards, fields, buttons, chips, segmented controls, navigation, dialogs, sheets, snackbars, progress, and switches.

Motion uses Flutter built-ins only: 120 ms fast feedback, 180 ms standard state transitions, and 220 ms spatial transitions with restrained ease-out timing. Product cards provide immediate press feedback; cart count/totals and revenue values transition without delaying state updates; order-type, chip, status, and period selections animate their visual state. Reduced-motion settings resolve shared transition durations to zero.

## Screen changes

- **Bán hàng:** warm search/filter styling, orange selection, quieter product cards, intentional empty states, tactile product taps, and animated sticky-cart values.
- **Đơn hiện tại:** animated order-type selection, calmer item/note controls, animated quantity and totals, and a stable bottom print action.
- **Đơn hàng / Chi tiết đơn:** one clear heading, scan-friendly cards, semantic status badges, grouped receipt content, and distinct primary/destructive/secondary actions.
- **Doanh thu:** revenue is the hero metric, period selection uses the brand color, secondary metrics recede, and period content crossfades without changing calculations.
- **Món / product form / categories:** simplified hierarchy, distinct catalog-empty and filtered-empty guidance, neutral forms, restrained chips, quieter image selection, and reduced decorative feedback.
- **Cài đặt / receipt / backup / printer:** consistent row and icon treatment, neutral forms, stronger receipt preview, calm local-backup language, and unchanged operational controls.
- **Navigation:** the same five destinations remain, with a warm selected indicator and neutral unselected states.

## Accessibility and responsive checks

- Existing widget coverage verifies representative screens at 360 and 430 logical px; the API 36 emulator capture is approximately 411 logical px and covers the intermediate range near 390 px.
- A focused test verifies the shared empty state at 360 px with 1.3x system text scaling and a long Vietnamese message.
- Shared button sizing preserves approximately 48 px minimum touch targets.
- Vietnamese labels, scrollable forms, safe areas, bottom actions, navigation labels, semantic disabled/error states, and long content were reviewed for clipping and reachability.

## Automated verification

Run on 2026-10-03:

- `dart format --output=none --set-exit-if-changed lib test integration_test` — 80 files, 0 changes.
- `flutter analyze` — no issues.
- `flutter test` — 150 tests passed.
- `flutter test integration_test\order_flow_test.dart -d emulator-5554` — passed on API 36.
- `flutter test integration_test\backup_restore_test.dart -d emulator-5554` — passed on API 36.
- `flutter build apk --debug` — passed; output: `build/app/outputs/flutter-apk/app-debug.apk`.

Focused V2 assertions cover exact palette tokens, semantic-color contrast, semantic order-status mapping, order-type accessibility semantics, brand revenue selection, narrow-width action reachability, large-text behavior, reduced motion, catalog empty-state differences, neutral optional-image metadata, and all five navigation destinations.

The existing Drift multiple-database warning still appears in restore tests and remains unchanged; all tests pass.

## Visual evidence

The current build was installed and reviewed on the `Dakao_API_36` emulator. Representative evidence:

| Area | Evidence |
| --- | --- |
| Sales empty | [01-sales-empty.png](screenshots/01-sales-empty.png) |
| Sales products and cart | [02-sales-products.png](screenshots/02-sales-products.png), [03-sales-cart.png](screenshots/03-sales-cart.png) |
| Current order | [04-current-order.png](screenshots/04-current-order.png) |
| Save-before-print feedback | [05-after-save.png](screenshots/05-after-save.png) |
| Orders | [05-orders.png](screenshots/05-orders.png) |
| Order detail | [05b-order-detail-unpaid.png](screenshots/05b-order-detail-unpaid.png), [05c-order-detail-paid.png](screenshots/05c-order-detail-paid.png) |
| Revenue | [06-revenue.png](screenshots/06-revenue.png) |
| Products | [07-products.png](screenshots/07-products.png) |
| Add product | [08-add-product.png](screenshots/08-add-product.png) |
| Categories | [09-categories-empty.png](screenshots/09-categories-empty.png) |
| Settings | [10-settings.png](screenshots/10-settings.png) |
| Shop / receipt | [11-shop-receipt.png](screenshots/11-shop-receipt.png) |
| Backup / restore | [12-backup-restore.png](screenshots/12-backup-restore.png) |
| Printer settings | [13-printer-settings.png](screenshots/13-printer-settings.png) |

The system review found and corrected three presentation issues before completion: a duplicate add-product CTA in the true empty catalog, success-green styling on optional image metadata, and a narrow receipt-preview row overflow. The final review found no accidental neon colors, lavender fields, fake-success UI, clipped critical actions, or inconsistent semantic status colors.

## Regression checks and limitations

The diff is limited to theme/design-system code, presentation widgets, focused widget tests, this verification record, and screenshots. It does not change Drift schema or migrations, repositories, Android/native configuration, backup format or validation, printer protocol/transport, revenue calculations, order persistence/lifecycle, receipt snapshots, or navigation destinations. No Stage 7A Hardware Lab or `debug/mp58n` change is present.

Physical MP-58N output remains hardware-unverified. Emulator review cannot prove printed paper output, Bluetooth transport success, or performance characteristics of the target printer hardware.

## MOTION REFINEMENT V2.1

Physical-device feedback after V2 reported that repeated POS interactions still felt stiff. The audit found that timing alone was not the main cause: Sales and Current Order watched the complete cart, Revenue replaced a large report subtree through one opacity transition, Orders coupled filters to the whole async screen, and the original shell discarded destination trees. Every cart change could therefore rebuild search, categories, the product grid, and product images; quantity and note changes could rebuild every cart line; and changing tabs recreated destination state.

V2.1 makes these targeted presentation changes:

- `AppMotion` now names the interaction intent: 80 ms press-down, 120 ms release, 160 ms selection and number changes, 180 ms order-type movement, 190 ms dialog guidance, and 200 ms navigation/content/startup transitions. The curve remains restrained `easeOutCubic`, and reduced motion resolves transition durations to zero.
- Sales watches only the catalog at screen scope. A separate cart bar selects only item count and total, so cart mutation no longer rebuilds search, categories, the product grid, or product images. Count and total use a local 160 ms crossfade with 5 px vertical translation, and the switcher retains at most one outgoing value during rapid input.
- Current Order watches stable line identities at page scope. Each line selects its own data, the order-type selector selects only type/submission state, and the summary selects only total/empty/submission state. Quantity, note, and total changes therefore stay within the affected subtrees.
- The independent order-type buttons were replaced by one segmented control with a 180 ms sliding indicator and concurrent 160 ms text/icon emphasis. The domain value changes on tap, before the visual transition finishes.
- The five root destinations now use `StatefulShellRoute.indexedStack`. Their search/scroll/widget identity survives tab switching, while the navigation indicator uses 200 ms feedback. Root content changes immediately rather than through a full-screen opacity layer.
- Orders now holds the selected filter in a reactive provider and splits filter controls from results. Revenue splits its header, period selector, and summary and removes the large report-level `AnimatedSwitcher`. Category, order, revenue, and product-form chips share the 160 ms selection style.
- Retaining Sales revealed a stale one-shot catalog snapshot during profile QA. A narrow catalog revision provider now refreshes Sales after a successful product/category mutation while preserving the retained destination state. Persistence and repository semantics remain unchanged.

Independent review found the same retained snapshot could survive a successful Stage 6 restore because restore invalidation predated the new revision signal. The restore controller now bumps that presentation-only signal alongside its existing provider invalidations, and a restore-through-Settings widget test proves the already-mounted Sales destination replaces its old catalog. No archive, validation, transaction, recovery, or restore behavior changed.

Behavior-focused coverage verifies 20 rapid product taps, repeated `+`/`-`, rapid order-type toggling, exact final count/quantity/total/type, retained Sales search state, live catalog refresh in a retained Sales destination, and reduced-motion final state without waiting for animation. The suite avoids assertions on intermediate animation frames.

Profile-mode API 36 review exercised rapid category selection, ten rapid product additions, repeated quantity changes, order-type toggles, repeated bottom-tab switching, order filters, revenue periods, product-form focus/scroll, and a destructive confirmation dialog. Ten rapid additions converged to 10 items / 350,000đ. Eight increments followed by three decrements converged from quantity 10 to 15 / 525,000đ. No tap was lost, no control remained in a stale visual state, and the retained destinations changed without a full-screen transition. These are qualitative emulator observations; no Flutter frame-timing trace or physical-device frame measurement was captured, so real modest-hardware smoothness remains the next QA gate.

Profile evidence: [order type and quantity](evidence-v2.1/profile-order-type-and-quantity.png) and [confirmation dialog](evidence-v2.1/profile-dialog.png).

## STARTUP EXPERIENCE

Previously, `main()` awaited the production database, application-support path, and Stage 6 pending-restore recovery before `runApp`, leaving Android's default white/black launch surfaces responsible for the full delay and providing no Flutter failure or retry state.

The native Android launch theme now uses the V2 warm canvas `#FAF8F5` in light, night, pre-Android-12, and Android-12 resources. It centers a byte-identical copy of the approved Stitch logo; the original design asset remains unchanged. Android 12 uses the platform splash attributes, while older configurations use the matching layer-list background. `minSdk`, manifest permissions, and Android application behavior are unchanged.

Flutter now mounts `StartupHost` immediately. Its production initializer performs only real work: open the Drift production database, resolve the application-support directory, construct the existing restore service, and await the existing `recoverPendingRestore()` logic. A visible initialization uses the same warm background, approved logo, title, and one small brand-colored progress indicator. There is no `Future.delayed`, minimum splash duration, fake stage, or fake progress. When work completes, the application becomes usable immediately with at most a 200 ms content fade; reduced motion skips that fade.

An initialization exception closes any database opened by that failed attempt and replaces the spinner with the actionable V2 error state `Không thể khởi động ứng dụng` and a safe `Thử lại` action. Attempts are identified so stale results are disposed rather than installed. Focused tests prove loading is backed by a real incomplete future, immediate completion enters the app without an artificial wait, failure cannot remain an infinite loader, and retry can recover. The existing restore unit and API 36 backup/restore integration coverage continue to verify Stage 6 recovery semantics.

The final profile APK was installed on `Dakao_API_36`. Android Activity Manager reported a force-stop cold launch of 2,158 ms and a warm task bring-forward of 68 ms; these are emulator activity timings, not Flutter frame-render measurements. A captured cold sequence showed the warm native surface and approved logo followed by the matching warm app surface, with no white frame, black frame, background-color jump, or second branded Flutter splash. Initialization completed quickly enough that the intermediate Flutter loader was not retained in the capture, which confirms the app did not prolong startup to display it. The created category/product remained present after reinstall and force-stop launch, providing a settings/data reopen check. Cold, warm, and force-stop paths all reached usable Sales UI.

Startup evidence: [native launch](evidence-v2.1/profile-native-launch.png), [first ready app surface](evidence-v2.1/profile-startup-ready.png), and [cold ready state](evidence-v2.1/profile-cold-ready.png).

The launch resources compile in debug, profile, and release APKs. Runtime launch review was performed on API 36; older API resource selection is build-verified but was not visually exercised on a second emulator. Physical-device launch composition and motion still require real-device QA.

### V2.1 final verification

Run on 2026-10-03 from the independently reviewed tree:

- `dart format --output=none --set-exit-if-changed lib test integration_test` — 82 files, 0 changes.
- `flutter analyze` — no issues.
- `flutter test` — 158 tests passed.
- `flutter test integration_test/order_flow_test.dart -d emulator-5554` — passed on Android API 36.
- `flutter test integration_test/backup_restore_test.dart -d emulator-5554` — passed on Android API 36.
- `flutter build apk --debug` — passed.
- `flutter build apk --profile` — passed.
- `flutter build apk --release` — passed.
- `git diff --check` — passed.

Independent review reported no Critical findings. Its one Important finding, stale retained Sales data after a successful restore, was fixed and re-reviewed; no Critical or Important findings remain. The existing Drift multiple-database debug warning remains limited to restore test construction and did not fail the suite.
