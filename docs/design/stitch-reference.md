# Đakao In Bill V1 — Stitch reference map

Status: approved UI/UX reference, inspected 2026-10-01. This document maps the export in [`stitch_akao_in_bill_pos`](stitch_akao_in_bill_pos/) to the approved Flutter application. It does not authorize Stage 1 or change production UI.

## Authority and use

Use the export with this precedence:

1. The approved technical specification and later recorded product decisions control business behavior, persistence, printing, and scope.
2. The exported `screen.png` files control visual composition and appearance.
3. [`DESIGN.md`](stitch_akao_in_bill_pos/modern_street_eatery_pos/DESIGN.md) supports the shared visual system.
4. The generated `code.html` files may clarify spacing, sizes, colors, and component composition only.

The HTML is reference material, not Flutter source. Do not copy its JavaScript state, Tailwind structure, URLs, architecture, dummy data, timers, or simulated behavior. Implement the approved screens with Flutter/Dart and the existing feature, controller, repository, SQLite, printing, and backup boundaries.

Bundle fonts and production assets locally. The HTML loads Google Fonts, Material Symbols, Tailwind, and several images from remote URLs; those URLs cannot become runtime dependencies in this offline application. The only standalone local brand asset in the export is `akao_in_bill_logo/screen.png`. Product and venue photos visible in screenshots are visual references, not a complete local asset pack.

## Export inventory and screen mapping

The export contains 15 PNGs: 14 application views and one logo reference. Every application view also has generated HTML. Folder names are preserved exactly as exported, including their transliterated/missing-diacritic names.

| Export folder | Approved V1 location | Purpose and Flutter implementation guidance |
|---|---|---|
| `akao_in_bill_logo` | Shared brand asset | Orange receipt/check mark. Preserve as a reference and derive any production launcher/brand asset deliberately; do not treat the 120×130 reference raster as a complete Android icon set. |
| `b_n_h_ng` | **Bán hàng** root | Product search, category chips, two-column product grid, current-order summary, printer status, and five-tab navigation. Its PNG is effectively blank except for the bottom navigation, so it is not a usable primary composition reference; use its HTML only as supporting evidence and use `in_bill` for the visible sales layout. |
| `in_bill` | **Bán hàng** root, immediately after a print attempt/new-cart state | Shows the previous saved order summary, explicit reprint/view actions, product grid, optional order-type chip, empty new cart, sticky print action, and bottom navigation. Treat “Đã in” as sample copy only; production status must distinguish a command accepted by transport from proven paper output. |
| `n_hi_n_t_i` | **Bán hàng → Đơn hiện tại** | Cart review: optional order type, line quantities, notes, total, and the explicit **In bill** action. The primary action implements Save → commit order → attempt print. Neither order type may be preselected by default because order type may remain null. |
| `danh_s_ch_n_h_ng` | **Đơn hàng** root | Search/filter shell, All/UNPAID/PAID segments, order cards, mark-paid action, and reprint entry point. The list must remain capable of reaching historical orders; “Đơn hàng hôm nay” in the mockup must not silently limit the approved order history. Include CANCELLED orders in All/details without adding a separate filter. |
| `chi_ti_t_n_bill_58mm` | **Đơn hàng → Chi tiết hóa đơn** | Immutable saved receipt preview and status actions. UNPAID permits mark paid, cancel, and reprint. PAID permits cancel with explicit confirmation and reprint. CANCELLED is terminal and its reprint control is disabled in V1. |
| `doanh_thu` | **Doanh thu** root | Period selector, paid revenue, period order count, current unpaid total, simple chart, and best sellers. Keep the card/chart/list composition while applying the approved query definitions below. |
| `qu_n_l_m_n` | **Món** root | Product search, category filters, availability controls, edit entry point, sold-out treatment, and add-product CTA. Product deletion remains soft deletion; historical snapshots are unaffected. |
| `qu_n_l_danh_m_c` | **Món → Danh mục** | Create, rename, activate/deactivate, order, and safely remove/reassign categories. Preserve the compact reorder rows and explanatory callout. Do not cascade category changes into saved orders. |
| `th_m_m_n_m_i` | **Món → Thêm món** | Name, integer price, quick price chips, category, optional description, optional image file selection, availability, and receipt preview. Do not add camera capture or payment-method features. |
| `s_a_m_n` | **Món → Sửa món** | Edit the same catalog fields, replace/remove a chosen image, toggle availability, preview receipt line, and soft-delete/archive. Replace permanent-delete wording and behavior with the approved soft-delete semantics. |
| `c_i_t` | **Cài đặt** root | Entry cards for the paired 58mm printer, test print, receipt settings, and backup/restore, plus local/offline information and bottom navigation. App version and printer state are dynamic data, not the sample literals. |
| `c_i_t_m_y_in_58mm` | **Cài đặt → Máy in Bluetooth 58mm** | Selected/paired device, connect/disconnect/reconnect, test print, connection status, and other paired devices. Keep `auto_reconnect` if implemented. Omit the “In bill ngay khi tạo đơn”/auto-print toggle from V1. Do not claim MP-58N compatibility until physical testing passes. |
| `th_ng_tin_qu_n_bill` | **Cài đặt → Thông tin quán & Bill** | Shop name, optional address/phone/footer, live on-screen 58mm preview, and save. Saved orders use their receipt-settings snapshot, so later edits affect new orders only and must not alter historical reprints. |
| `sao_l_u_kh_i_ph_c` | **Cài đặt → Sao lưu & Khôi phục** | Local export, last-backup metadata, file selection, validation summary, destructive replacement warning, and explicit restore confirmation. Implement the approved `.dakbackup` versioned ZIP workflow rather than the generated `.json`/`.bak` behavior. |

Root destinations use the persistent bottom navigation in this order: **Bán hàng, Đơn hàng, Doanh thu, Món, Cài đặt**. Child views use a back affordance and normally omit the bottom navigation. Preserve Android safe areas and keep primary actions reachable in the lower thumb zone.

## Reusable visual system

### Color

The screenshots and the structured palette at the top of `DESIGN.md` align on this semantic family:

| Role | Reference value | Use |
|---|---:|---|
| Primary | `#A33900` | Main print/save actions, selected controls, prices, and active navigation |
| Primary container | `#CC4900` | Strong orange container where the screenshot calls for a brighter treatment |
| On primary | `#FFFFFF` | Labels/icons on orange actions |
| Success/connected | `#006E2D` | Paid, available, connected, and successful states |
| Success container | `#7CF994` | Low-emphasis green pills and status surfaces |
| Warning/unpaid | `#8D4B00` | Unpaid and caution emphasis |
| Warning container | `#FFDCC3` / the exported tertiary-fixed family | Unpaid pills and warm callouts |
| Error/destructive | `#BA1A1A` | Cancel, remove, validation errors, and destructive confirmations |
| Canvas | `#F9F9FF` | Page background |
| Card | `#FFFFFF` | Product, order, form, and settings cards |
| Low containers | `#F1F3FF`, `#E9EDFF`, `#E1E8FD`, `#DCE2F7` | Inputs, chips, secondary buttons, summary bands, and selected soft surfaces |
| Primary text | `#141B2B` | Headings and core values |
| Secondary text | `#5A4138` | Supporting copy and metadata |
| Outline | `#8E7166` / `#E2BFB2` | Strong and subtle outlines |

Use semantic names in Flutter rather than scattering hex literals. The `DESIGN.md` prose separately names brighter web-style colors such as `#EA580C`, `#16A34A`, and `#D97706`, while its structured palette, generated HTML, and application screenshots consistently use the darker Material-derived palette above. The logo itself uses `#EA580C`. For application components, match the PNGs and structured tokens; retain the brighter orange within the supplied logo unless a later approved brand asset supersedes it.

### Typography

Bundle **Plus Jakarta Sans** with weights 500, 600, 700, and 800 and verify Vietnamese glyph coverage offline. Use tabular lining figures for prices and aligned counts.

| Style | Size / line | Weight | Typical use |
|---|---:|---:|---|
| Headline large | 30 / 38 px | 800 | Rare top-level emphasis |
| Headline medium | 22 / 28 px | 700 | Screen/section titles |
| Headline small | 18 / 24 px | 700 | Card headings and app bars |
| Body large | 16 / 22 px | 600 | Prominent body values |
| Body medium | 14 / 20 px | 500 | Default copy |
| Body small | 12 / 16 px | 500 | Secondary metadata |
| Label large | 15 / 20 px | 700 | Primary buttons |
| Label medium | 13 / 18 px | 600 | Chips and compact actions |
| Label small | 11 / 14 px | 700 | Status badges and navigation labels |
| Price display | 24 / 30 px | 800 | Totals and headline prices |
| Receipt price | 15 / 20 px | 700 | Dense rows and receipt values |

VND is integer-only and displayed with Vietnamese thousand separators and a lower-case symbol, for example `45.000đ` and `180.000đ`. Receipt previews use a bundled monospaced Vietnamese-capable font or the actual raster renderer, while application UI remains Plus Jakarta Sans.

### Spacing, layout, and shape

- Use a 4 px base rhythm. The principal tokens are 4, 8, 12, 16, and 24 px.
- Use 16 px horizontal screen margins and 12 px internal grid gutters at phone widths.
- Target portrait Android widths from 360–430 logical pixels, then verify narrower, larger, and font-scaled layouts. Exported PNG widths vary from 430 to 617 pixels and are references, not fixed Flutter dimensions.
- Sales products use a fluid two-column grid. Dense order/product management views use full-width stacked cards.
- Keep root navigation and sticky action trays above the system safe area. Scrolling content must remain visible above them.
- Cards and inputs visually read as approximately 16 px rounded; primary controls use the same soft rectangular shape; chips and badges are pills. Receipt previews may use a torn/zigzag paper edge.
- Prefer flat white containment with hairline borders and restrained shadows. Reserve the upward ambient shadow for sticky bottom trays and navigation.
- Primary actions have a minimum 52 px height. General interactive targets must be at least 48×48 logical pixels even when the visible icon is smaller.
- Touch feedback may use subtle surface darkening and slight scale compression. It cannot substitute for disabled, loading, success, or error state semantics.

`DESIGN.md` is internally inconsistent about radii: its front matter defines 4/8/12/16/24 px, its prose calls cards and buttons 16 px, while generated HTML remaps several `rounded-*` names to 4/8/12 px. Match the PNG curvature and use semantic Flutter radius tokens rather than porting Tailwind class names.

### Common components

- **Root app bar:** title or brand at left; compact printer status at right where operationally useful. Sample person/avatar icons do not create login, employee, or profile features.
- **Child app bar:** 48 px minimum back target, title, optional passive brand mark. Do not wire the sample avatar to a new destination.
- **Bottom navigation:** five equal destinations, icon above 11 px label, selected state in primary orange, safe-area aware.
- **Printer status pill:** dot/icon plus short state such as disconnected, connecting, connected, sending, failed, or uncertain. Device name is dynamic.
- **Filter chips/segmented controls:** 38–48 px high, pill/rounded container, high-contrast active state, horizontal scrolling only where needed.
- **Cards:** white surface, low-contrast outline or very light elevation, 12–16 px internal padding, clear primary/secondary hierarchy.
- **Status badges:** UNPAID uses amber/warm tint; PAID uses green tint; CANCELLED uses error tint. Status must also be communicated in text/icon, not color alone.
- **Product cards:** image or intentional placeholder, name, price, and quick-add affordance. Availability state is visible before selection.
- **Order cards:** number/time/type, concise item summary, total, status, and context-valid actions. Use snapshots for saved content.
- **Quantity stepper:** 36–48 px decrement/increment targets around a bold count; zero/removal behavior must be explicit.
- **Sticky action tray:** white or soft-container surface above safe area with current total and one dominant action.
- **Receipt preview:** narrow white thermal-paper metaphor, monospaced alignment, dashed separators, wrapped Vietnamese text, and no implied proof that paper printed.
- **Forms:** large filled fields, optional/required labels, integer price entry, quick value chips, inline validation, and a sticky save action on long screens.
- **Confirmation surfaces:** dimmed modal or bottom sheet with a specific consequence and separate cancel/confirm controls for cancellation, soft deletion, and restore replacement.
- **Feedback:** short snackbars/toasts for completed local operations; persistent actionable state for print failures or uncertainty.

## Screen and content inconsistencies

These differences should be resolved through shared Flutter components and the authority rules above, without redesigning the screens:

1. `b_n_h_ng/screen.png` is almost entirely blank although its HTML contains a populated selling screen. Use `in_bill/screen.png` as the primary visible sales reference and the blank export only as evidence of the bottom-navigation proportions.
2. Primary color definitions conflict (`#A33900` in structured tokens and most screenshots versus `#EA580C` in prose and the logo). Use the darker application palette and preserve the supplied logo color.
3. Radius token names disagree between `DESIGN.md` and the generated HTML. Use semantic 16 px card/button radii, smaller field/chip radii where visibly shown, and full pills.
4. App-bar heights, title capitalization, logo thumbnails, profile circles, printer labels, and connection indicators vary by screen. Consolidate them into root and child app-bar variants while retaining each screen's information hierarchy.
5. Terminology varies: “Chưa trả”/“Chưa thanh toán,” “Đã trả”/“Đã thanh toán,” “Bill”/“Hóa đơn,” and several capitalization styles. Prefer **Chưa thanh toán**, **Đã thanh toán**, **Đã hủy**, **In bill**, and sentence-case Vietnamese labels, while preserving “Bill” where it is part of the approved screen title or shop-facing phrase.
6. Printer samples use `MP-58N`, `Printer-58`, `POS-58`, “Quầy Bar,” and `BT-203`. These are sample values; show the selected paired device name/address and its real state.
7. Dates, order numbers, counts, prices, app version `v1.2.0`, backup size, and “Sẵn sàng” statuses are fixture content. Bind them to local data and actual package/device state.
8. Some root screenshots show a device-style status bar and others start at the app bar. Flutter should consistently honor system insets rather than recreating a fake status bar.
9. The product list represents sold-out state with both reduced opacity/strike-through and a switch. Preserve the unmistakable state but ensure text remains readable and the switch has an accessible label.
10. Long-form exports use several different capture widths/heights. Layouts must scroll and adapt; do not encode screenshot pixel sizes.

## Generated content that must not define V1 behavior

The following generated text or behavior conflicts with, exceeds, or misstates the approved product requirements:

| Generated reference | Required V1 interpretation |
|---|---|
| Printer toggle “In bill ngay khi tạo đơn” / “Tự động in bill…” | Do not expose an auto-print toggle. The explicit **In bill** action performs Save → Print. `auto_print` may remain persisted internally. |
| “Tiền mặt / Chuyển khoản,” split-payment/discount keypad notes in `DESIGN.md`, QR references | Payment methods, cash/change, split payment, discounts, and payment QR are excluded. Price input is simply integer VND. |
| “Chụp trực tiếp” / camera affordance | V1 uses file selection only. No camera workflow or camera permission. |
| “Xóa vĩnh viễn” product behavior | Products are soft-deleted. Categories are deactivated or safely reorganized. Saved order/item snapshots remain available. |
| “Đang đồng bộ… với máy in bếp,” kitchen-send/draft language | V1 has one receipt-printer flow. No kitchen printer, kitchen send, draft workflow, or multi-printer synchronization. |
| Default selected “Mang về”/“Tại quán” | Order type is optional and initially null; the user may choose DINE_IN or TAKEAWAY. |
| “Đã in,” “Vừa in,” or “máy in hoạt động bình thường” after a simulated write | A completed transport write is not proof of paper output. Use accurate sent/failed/uncertain language and never automatically resend an uncertain job. |
| Reprint buttons shown without cancelled-state treatment | Reprint operates on the existing order only and never changes revenue. It is disabled for CANCELLED orders in V1. |
| Order list titled only “Đơn hàng hôm nay” | The approved order area needs All/UNPAID/PAID access to retained orders; a day view must not hide history or redefine the filters. |
| Revenue “Thực thu ước tính” | Revenue is an exact local sum of currently PAID orders whose `paid_at` is in the selected period. It is not an estimate and excludes CANCELLED orders. |
| “Tiền chưa thu (Bàn 4, Mang về)” | Tables are excluded. Unpaid amount is **all current UNPAID orders**, independent of the selected period and order type. Label that scope clearly. |
| Shift report, closed shift, “Giả lập ca mới,” peak-hour story, and custom period | Shift management/simulation is not approved. V1 periods are today, seven days, and current month. Retain only a simple visualization backed by approved data. |
| Revenue total-order fixture | Order count is noncancelled orders created in the selected period; revenue uses `paid_at`. Keep these different time bases explicit. |
| Payment/cancellation shortcuts without full states | Allow UNPAID → PAID/CANCELLED and PAID → CANCELLED with explicit confirmation and optional reason. CANCELLED is terminal. There is no refund ledger. |
| Receipt-settings text saying edits immediately appear on the printer | The on-screen preview may update live, but saved settings affect future orders. Historical reprints use `receipt_settings_snapshot`. |
| Backup formats `.json` or `.bak` and JavaScript dummy download | Use the approved `.dakbackup` ZIP with manifest, checksums, all seven tables, snapshots, settings, and referenced images. Export uses Android local save selection. |
| Restore warning that only today's receipts are replaced | Restore replaces the complete local dataset after validation and explicit confirmation. Cancellation or failed validation changes nothing. Pairing must be rechecked, and restored orders never auto-print. |
| “100% bảo mật,” “không lo rò rỉ,” or similar absolute claims | The backup integrity checks are not encryption or authentication. Describe local/offline storage factually without promising absolute confidentiality. |
| Always-visible `MP-58N Sẵn sàng` and successful test state | Show real connection/test state. MP-58N support remains hardware-unverified until the physical lab gate passes. |
| Sample avatar/person controls | Login, employees, roles, and profiles are excluded. Keep them decorative only if visually necessary, or omit the action semantics. |
| Remote Google fonts, Material icon fonts, Tailwind CDN, and remote photo URLs | Production must operate offline. Bundle approved fonts/icons and use local/product-selected images with a missing-image fallback. |

## Implementation checkpoints for later UI stages

This reference does not start those stages. When UI implementation is authorized:

- Build shared Flutter tokens/components first, then compare each implemented state against its PNG at representative 360, 390, and 430 logical-pixel widths.
- Test Vietnamese diacritics, text scaling, keyboard insets, safe areas, scrolling, and minimum touch targets.
- Model loading, empty, disabled, error, print-failed, and print-uncertain states using the same visual language; do not infer new business flows from generated JavaScript.
- Keep fixture imagery and sample data out of production persistence. Use deterministic test fixtures for visual tests.
- Verify state-specific actions: optional order type, UNPAID/PAID/CANCELLED transitions, cancelled reprint disabled, exact paid-at revenue, global current unpaid amount, soft deletion, receipt snapshots, and safe full-dataset restore.
- Keep MP-58N claims marked hardware-unverified until physical evidence exists.

No production Dart/Flutter files were changed during this reference inspection, and Stage 1 remains unstarted.
