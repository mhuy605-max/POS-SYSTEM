# Stage 5 verification — Revenue

Date: 2026-10-02

Branch: `feature/full-pos`

## Implemented architecture

The Revenue destination follows the production data path `RevenueScreen` → Riverpod period/summary providers → `RevenueRepository` → Drift/SQLite. Widgets receive a ready-to-render `RevenueSummary`; they do not load the order list or calculate financial totals.

`RevenueRepository` uses focused SQL queries for recognized revenue and paid-order count, the current global unpaid amount, daily paid totals, and the top five historical item snapshots. Order totals are aggregated directly from `orders`, so joining order items cannot multiply recognized revenue. Best sellers are aggregated separately from immutable `order_items` snapshots.

The reactive summary watches only `orders` and `order_items`. Changes to print attempts do not trigger or alter the revenue result.

## Revenue and date semantics

Recognized revenue is the integer-VND sum of orders whose current status is `PAID` and whose `paid_at` falls in the selected period. `created_at`, UNPAID orders, CANCELLED orders, receipt activity, `print_count`, and print-attempt rows are excluded.

Current unpaid is the integer-VND sum of all orders whose current status is `UNPAID`. It is intentionally independent of the selected period. Cancelling an UNPAID order removes it from unpaid without adding revenue. Cancelling a PAID order removes it from recognized revenue and does not make it unpaid.

Today, the last seven calendar days including today, and the current calendar month are supported. Each device-local calendar period is converted to a half-open `[start, next-day/month)` epoch-millisecond range. This keeps midnight boundaries consistent while allowing an inclusive date label in the UI.

## UI and Stitch comparison

The implemented screen preserves the approved orange/white shell, Plus Jakarta Sans typography, rounded cards, hierarchy, five-destination bottom navigation, and compact period controls. It includes:

- exact recognized revenue;
- paid-order count for the selected period;
- clearly labelled current unpaid total;
- a simple daily revenue bar view backed by PAID/`paid_at` data;
- the top five selling item snapshots for the selected period;
- loading, error, and empty states.

The generated Stitch wording “Thực thu ước tính” was replaced by “Thực thu đã thanh toán” because the value is an exact sum. Shift simulation, peak-hour stories, most-expensive-order cards, forecasts, profit, tax, expenses, employees, and accounting exports were omitted. The generated custom-period control was also omitted because `docs/design/stitch-reference.md` limits approved V1 periods to Today, 7 days, and This month. The visualization uses daily bars instead of the generated hourly fixture so all three approved periods have one consistent real-data view.

Responsive widget tests cover 360, 390, and 430 logical pixels without overflow.

## Automated verification

TDD evidence was recorded during implementation: repository tests first failed because the revenue API did not exist, and widget tests first failed because the providers/screen did not exist. A responsive test also exposed a 360-pixel header overflow, which was corrected before the final gate.

The repository and provider tests cover:

- UNPAID, PAID, and CANCELLED inclusion rules;
- `paid_at` rather than `created_at`, including creation yesterday and payment today;
- exclusion outside the selected period;
- UNPAID → PAID, UNPAID → CANCELLED, and PAID → CANCELLED recalculation;
- global current unpaid semantics;
- exact integer sums, empty periods, daily totals, and snapshot best sellers;
- failed and successful print-attempt rows having no effect;
- recalculation after closing and reopening a file-backed database;
- reactive UI updates and the approved period controls.
- local-midnight rollover when the user refreshes the screen;
- production sent/failed reprints, including the successful `print_count` and `printed_at` order-row mutation, leaving reactive revenue unchanged.

Final command results:

- `dart format --output=none --set-exit-if-changed lib test integration_test`: 60 files checked, 0 changed.
- `flutter analyze`: no issues found.
- `flutter test`: all 107 tests passed.
- `flutter test integration_test/order_flow_test.dart -d emulator-5554`: 1 API 36 integration test passed.
- `flutter build apk --debug`: succeeded and produced `build/app/outputs/flutter-apk/app-debug.apk`.

A fresh whole-change review found two P2 gaps: stale calendar periods after midnight and missing real-reprint mutation coverage. Both were corrected with regression tests. The reviewer's narrow re-check found no remaining Critical, Important, or P2 findings.

The integration test creates an UNPAID order after a successful fake software send, confirms zero recognized revenue and 25,000đ unpaid, marks it PAID, confirms 25,000đ recognized and zero unpaid, rebuilds the app scope, then cancels the PAID order and confirms both values return to zero. The order is queryable before the fake transport sends, so the test also retains Stage 4's save-before-print guarantee.

## API 36 normal-app verification

The final normal debug APK was installed on `Dakao_API_36` (`emulator-5554`) and launched with `com.example.dakao_in_bill/.MainActivity` as the focused activity. Verification used the production database and production printer channel.

Starting from empty app data, a `RevenueTest` category and a 35,000đ `RevenueItem` were created through the normal UI. The following flow passed:

1. Saving order `#0001` as UNPAID with no configured printer left recognized revenue at 0đ and raised current unpaid to 35,000đ.
2. Marking `#0001` PAID moved the amount to recognized revenue: 35,000đ, one paid order, and 0đ unpaid.
3. Force-stopping and relaunching the normal app preserved those values.
4. Saving and cancelling UNPAID order `#0002` left recognized revenue at 35,000đ and unpaid at 0đ.
5. Reprinting paid order `#0001` through the no-printer failure path left revenue at 35,000đ.
6. Cancelling paid order `#0001` with confirmation removed it from recognized revenue and left unpaid at 0đ.

Screenshots in this directory record the empty, UNPAID, PAID, and cancelled-PAID states. Automated repository tests provide the cross-day proof that an order created yesterday and paid today counts today, and the integration fake-send path provides the successful software-send isolation proof. Physical paper output remains outside Stage 5.

## Remaining risk

Calendar ranges intentionally follow the Android device's local time zone. A later device time-zone change can therefore alter which local calendar bucket contains an existing epoch timestamp; V1 has no separate business-time-zone setting. MP-58N compatibility remains hardware-unverified until Stage 7.
