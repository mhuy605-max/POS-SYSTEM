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
