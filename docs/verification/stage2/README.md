# Stage 2 catalog visual verification

Verified on 2026-10-01 with `Dakao_API_36` (`emulator-5554`), Android 16 / API 36.

The catalog was exercised against the production Drift database through the Flutter UI: category create, product create, product edit and repricing, availability presentation, soft-delete confirmation, undo/restore, scrolling, keyboard resizing, and process stop/reopen persistence. The emulator display override was reset to its original `1080x2400` at `420 dpi` after the width checks.

## Responsive captures

- [`catalog-360.png`](catalog-360.png) — 360 logical px wide
- [`catalog-390.png`](catalog-390.png) — 390 logical px wide
- [`catalog-430.png`](catalog-430.png) — 430 logical px wide

## Flow captures

- [`stage2-add-final.png`](stage2-add-final.png) — add-product form
- [`stage2-category-final.png`](stage2-category-final.png) — category management
- [`stage2-edit-lower.png`](stage2-edit-lower.png) — edit form, availability, receipt preview, and archive action
- [`stage2-delete-confirm.png`](stage2-delete-confirm.png) — soft-delete confirmation
- [`stage2-undo-restored.png`](stage2-undo-restored.png) — restored product after undo
- [`stage2-keyboard.png`](stage2-keyboard.png) — form while the emulator IME/stylus input surface is active
- [`stage2-persistence-reopen.png`](stage2-persistence-reopen.png) — catalog after force-stop and process restart

The screenshots were compared with the approved Stitch references for `qu_n_l_m_n`, `th_m_m_n_m_i`, `s_a_m_n`, and `qu_n_l_danh_m_c`. The implementation retains the orange/white hierarchy, filled inputs, rounded cards, category chips, product rows, sticky actions, bottom navigation, and explicit status controls while adapting vertically to a normal Android viewport.

Intentional differences follow the approved product rules: the false printer-ready badge and profile affordance are omitted, camera copy/action is replaced by local file selection, permanent-delete wording is replaced by reversible soft deletion, and category removal is represented by activation state so product references remain valid.
