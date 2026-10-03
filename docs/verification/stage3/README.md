# Stage 3 verification — Sales and Order Management

Verified on 2026-10-02 against `Dakao_API_36` (`emulator-5554`, Android 16 / API 36).

## Implemented boundary

- `CartController` owns the transient cart, stable line identities, nullable order type, integer totals, submission token, in-flight submission lock, retry state, and cart clearing.
- Sales reads catalog data through its own auto-disposed presentation provider, so sales search/category choices cannot leak into Stage 2 product-management filters.
- The UI calls the controller; submission calls `OrderService.submitForPrint`; the service delegates to the Stage 1 atomic repository transaction. Stage 3 performs no printer I/O and writes no print attempt.
- A failed save retains the cart and token. A successful save clears the submitted cart, rotates the token, invalidates the order list, and returns to selling.
- Orders are loaded from Drift and filtered as All, UNPAID, or PAID. CANCELLED remains visible in All.
- Detail uses saved item and receipt-setting snapshots. UNPAID may become PAID or CANCELLED. PAID cancellation has explicit paid-order copy. CANCELLED is terminal and reprint is disabled.

## Automated gate

Commands run from the repository root:

```text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/order_flow_test.dart -d emulator-5554
flutter build apk --debug
```

Results:

- Formatter: pass, 40 files checked, 0 changed.
- Static analysis: pass, no issues.
- Unit/widget suite: 73 tests passed.
- API 36 integration flow: 1 test passed. It creates a sale, checks the snapshot/note, marks paid, rebuilds the app tree, and verifies persisted status.
- Debug build: pass at `build/app/outputs/flutter-apk/app-debug.apk`.

The tests cover the 31 required Stage 3 behaviors through Stage 1 repository/service tests, new cart/controller tests, query tests, widget tests, and the device integration flow. They include retry token retention, in-flight double-submit sharing, snapshot immutability after catalog/settings changes, paid-at idempotency, terminal cancellation, and 360/390/430 logical-pixel layouts.

## Manual API 36 happy path

Using the normal production entry point and file-backed application database:

1. Created a real category and product through the Stage 2 screens.
2. Added the product twice, reduced the quantity, added a note, selected TAKEAWAY, and reviewed the integer total.
3. Tapped **In bill** rapidly. One UNPAID order and one item set appeared as order `#0001`; the cart returned empty and selling remained available.
4. Opened Orders and its receipt-style detail. The saved name, unit price, quantity, note, type, line total, total, and receipt snapshot were displayed.
5. Marked `#0001` paid, force-stopped/restarted the application, and verified PAID persisted.
6. Created `#0002`, cancelled it from UNPAID, and verified the terminal CANCELLED state, absent pay action, and disabled reprint action.
7. A manual per-keystroke note check exposed cursor reversal. A failing regression test reproduced `LessIce` becoming `ecIsseL`; the row now owns a stable text controller and the regression passes.
8. Resized the API 36 display to 360, 390, and 430 logical-pixel widths. Populated Sales/review widget tests showed no overflow. Manual shell captures confirmed safe areas, the sticky sales action, and five-tab navigation remained reachable at each width.

## Stitch comparison

Compared against `in_bill`, `n_hi_n_t_i`, `danh_s_ch_n_h_ng`, and `chi_ti_t_n_bill_58mm` PNG/HTML references using `docs/design/stitch-reference.md` precedence.

Preserved: two-column product cards, search and category chips, low-thumb cart summary, review type selector, dense quantity/note card, sticky **In bill** action, segmented order filters, status badges, stacked order cards, receipt metaphor, snapshot totals, and bottom navigation proportions.

Required deviations:

- Omitted sample printer-ready indicators and all “Đã in”/successful-print copy because Stage 4 owns Bluetooth and ESC/POS.
- **In bill** reports `Đã lưu đơn #NNNN`; it does not claim paper output.
- Reprint is visibly disabled as “Chưa kết nối” for active orders and “Không thể in lại đơn đã hủy” for cancelled orders.
- Omitted tables, payment methods, cash/change, discounts, shifts, staff, kitchen sync, and default order type.
- Orders are retained history rather than a hidden “today only” list. CANCELLED appears only in All without a new payment-status filter.

## Evidence

- `sales-catalog.png` — populated selling grid.
- `current-order.png` — quantity, note, order type, total, and sticky action.
- `keyboard-note-fixed.png` — final stable per-item note entry after the cursor regression fix.
- `sale-cleared.png` — sales-ready empty cart after persistence.
- `orders-unpaid.png` — real UNPAID order in All.
- `order-detail-unpaid.png` — saved `LessIce` snapshot detail and Stage 4-ready actions.
- `order-detail-paid.png` and `persistence-restart.png` — paid state and restart persistence.
- `cancel-confirm.png` and `order-cancelled.png` — explicit cancellation and terminal state.
- `sales-360.png`, `sales-390.png`, `sales-430.png` — shell, safe-area, and navigation width captures; populated Sales/review coverage is automated.

## Residual risk

- Physical printing remains intentionally unimplemented and unverified until Stage 4 and the MP-58N hardware gate.
- The manual ADB “double tap” was sequential enough that its second coordinate arrived after navigation; the persisted list still contained exactly one order. True in-flight duplication is covered deterministically by controller and Stage 1 database-idempotency tests.
