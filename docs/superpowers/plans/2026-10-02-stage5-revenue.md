# Stage 5 Revenue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved Doanh thu destination from persisted Drift orders, recognizing only PAID orders by `paid_at` and reporting the current global UNPAID amount.

**Architecture:** A focused revenue repository executes aggregate Drift/SQL queries and exposes a reactive summary stream. Riverpod owns period selection and binds repository results to a Stitch-aligned Flutter screen. Calendar periods are half-open epoch ranges derived from local device dates; widgets never calculate financial metrics.

**Tech Stack:** Flutter, Dart, Riverpod, Drift/SQLite, Flutter widget tests, API 36 emulator.

**Spec:** `C:/Users/ACER/.codex/attachments/fd1878f3-dbad-4931-8dd0-b1c4cc9e5029/Pasted text.txt`

## Global Constraints

- Stage 5 Revenue only; do not start Backup/Restore or physical printer testing.
- Recognized revenue is the integer-VND sum of current PAID orders filtered by `paid_at`.
- Current unpaid is the integer-VND sum of all current UNPAID orders, independent of selected period.
- CANCELLED orders, print attempts, and print counts never contribute.
- Preserve the approved Stitch composition and existing five-destination shell without adding unapproved accounting features.
- Produce one focused Stage 5 commit and stop before Stage 6.

## Review Focus

- Local-day boundaries and inclusive UI dates must map to a half-open epoch range without using `created_at`.
- PAID to CANCELLED must remove both revenue and best-seller quantities while preserving no unpaid balance.
- Order-item joins must not multiply order totals.
- Empty and large integer totals must render safely at 360, 390, and 430 logical pixels.
- Print-attempt mutations must not trigger or change revenue results.

---

### Task 1: Complete Stage 5 revenue slice

**Files:**
- Create: `lib/features/revenue/revenue_repository.dart`
- Create: `lib/features/revenue/revenue_providers.dart`
- Create: `lib/features/revenue/revenue_chart.dart`
- Create: `lib/features/revenue/revenue_screen.dart`
- Create: `test/revenue/revenue_repository_test.dart`
- Create: `test/revenue/revenue_widget_test.dart`
- Modify: `lib/app/router.dart`
- Modify: `integration_test/order_flow_test.dart`
- Create: `docs/verification/stage5/README.md`

**Interfaces:**
- Produces `RevenuePeriod`, `RevenueSummary`, `RevenueRepository.summarize`, and `RevenueRepository.watchSummary`.
- Produces Riverpod period-selection and reactive-summary providers consumed by `RevenueScreen`.
- Consumes existing `AppDatabase`, integer VND formatting, order state transitions, and root navigation.

- [x] **Step 1: Write repository tests first** for PAID/`paid_at`, period exclusion, cancelled removal, global unpaid, transition movement, integer sums, empty data, persistence after reopen, and print-attempt invariance.
- [x] **Step 2: Run `flutter test test/revenue/revenue_repository_test.dart`** and verify it fails because the revenue API does not exist.
- [x] **Step 3: Implement the focused repository and local half-open period model** using aggregate queries for revenue/count/unpaid, snapshot item aggregation for best sellers, and daily paid totals.
- [x] **Step 4: Run the repository tests** and verify they pass.
- [x] **Step 5: Write widget/provider tests first** for reactive payment/cancellation updates, empty state, period controls, and 360/390/430 layouts.
- [x] **Step 6: Run `flutter test test/revenue/revenue_widget_test.dart`** and verify it fails because the screen/providers are absent.
- [x] **Step 7: Implement Riverpod providers, simple dependency-free revenue bars, the Stitch-aligned screen, and router integration.** Include Today, 7 days, and This month period selection; paid-order count, recognized revenue, current unpaid, daily bars, and best sellers only. Omit the Stitch-generated custom-period control because the approved reference mapping excludes it from V1.
- [x] **Step 8: Extend the API 36 integration flow** to prove UNPAID → PAID → CANCELLED recalculation and restart persistence without changing revenue through printing.
- [x] **Step 9: Run the complete verification gate**: formatter, analyze, full tests, API 36 integration, debug APK build, launch, manual state transitions, and responsive/Stitch comparison.
- [x] **Step 10: Request a fresh whole-change review, fix validated findings with tests, update `docs/verification/stage5/README.md`, and make one focused Stage 5 commit.**
