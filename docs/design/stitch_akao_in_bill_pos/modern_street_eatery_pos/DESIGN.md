---
name: Modern Street Eatery POS
colors:
  surface: '#f9f9ff'
  surface-dim: '#d3daef'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f3ff'
  surface-container: '#e9edff'
  surface-container-high: '#e1e8fd'
  surface-container-highest: '#dce2f7'
  on-surface: '#141b2b'
  on-surface-variant: '#5a4138'
  inverse-surface: '#293040'
  inverse-on-surface: '#edf0ff'
  outline: '#8e7166'
  outline-variant: '#e2bfb2'
  surface-tint: '#a73a00'
  primary: '#a33900'
  on-primary: '#ffffff'
  primary-container: '#cc4900'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb599'
  secondary: '#006e2d'
  on-secondary: '#ffffff'
  secondary-container: '#7cf994'
  on-secondary-container: '#007230'
  tertiary: '#8d4b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#b15f00'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbce'
  primary-fixed-dim: '#ffb599'
  on-primary-fixed: '#370e00'
  on-primary-fixed-variant: '#7f2b00'
  secondary-fixed: '#7ffc97'
  secondary-fixed-dim: '#62df7d'
  on-secondary-fixed: '#002109'
  on-secondary-fixed-variant: '#005320'
  tertiary-fixed: '#ffdcc3'
  tertiary-fixed-dim: '#ffb77d'
  on-tertiary-fixed: '#2f1500'
  on-tertiary-fixed-variant: '#6e3900'
  background: '#f9f9ff'
  on-background: '#141b2b'
  surface-variant: '#dce2f7'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '800'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
  price-display:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 30px
    letterSpacing: -0.03em
  price-receipt:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: -0.01em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system is tailored for fast-paced, tactile, high-throughput food service environments—specifically Vietnamese dining concepts, street stalls, and cơm tấm eateries. The brand atmosphere balances functional utility with culinary warmth: energetic, organized, highly dependable, and welcoming. 

The aesthetic marries **Tactile Minimalism** with **Industrial Utility**:
- **Tactile Ergonomics:** Controls are engineered for grease-prone fingers, one-handed thumb navigation, and rapid-fire checkout workflows during peak rush hours.
- **Utilitarian Speed:** Visual bloat, gratuitous decorative illustrations, and complex layered nesting are eliminated. High-frequency actions prioritize maximum legibility, immediate state recognition, and sub-second feedback.
- **Modern Local Craft:** Clean thermal paper metaphors, crisp monospaced price structures, and deep appetizing citrus accents avoid generic SaaS sterility while projecting professional order and hygiene.

## Colors

The palette is engineered for indoor, outdoor, and high-glare lighting conditions on mid-range to flagship Android displays:

- **Primary Accent (`#EA580C`):** A deep, saturated culinary flame orange. Used for primary checkout actions, selected order counters, and urgent interactions.
- **Secondary / Success (`#16A34A`):** Vietnamese emerald green. Denotes "Đã thanh toán" (Paid), active Bluetooth thermal printer connections, and transaction successes. Paired with soft tint `#DCFCE7` for low-fatigue badge backgrounds.
- **Tertiary / Warning (`#D97706`):** Warm amber. Dictates "Chưa thanh toán" (Unpaid), pending ticket queues, or low printer paper warnings. Paired with `#FEF3C7` background container fill.
- **Neutrals & Surfaces:**
  - Canvas background: `#F8F9FA` to `#F3F4F6` (warm chalk/stone base that mitigates blue light strain).
  - Component card surfaces: `#FFFFFF` pure white to simulate clean receipt stock.
  - Text: High-contrast `#111827` (almost black charcoal) for primary data and `#4B5563` for secondary descriptors.
  - Borders: Crisp, hairline `#E5E7EB` dividers maintaining rigid structural clarity without visual heaviness.

## Typography

The type scale relies entirely on **Plus Jakarta Sans**, chosen for its tall x-height, clear open apertures, and crisp geometric legibility when rendering Vietnamese diacritics (dấu ngã, hỏi, nặng) on lower-DPI Android touchscreens.

- **VND Price Conventions:** Currency values must always render with standard Vietnamese thousand delimiters and the lower-case currency symbol: `45.000đ`, `120.000đ`. Prices leverage `tnum` (tabular lining figures) to guarantee precise vertical alignment in lists and on-screen receipt previews.
- **Visual Hierarchy:** Heavy weights (700 and 800) are reserved for dish names, order totals, and button triggers to ensure quick scanning from arm's-length distances. Body copy remains at 500-weight to prevent muddy anti-aliasing.

## Layout & Spacing

The layout is optimized specifically for portrait Android smartphones with viewports ranging between 360px and 430px wide.

- **Thumb-Zone Architecture:** Crucial navigational tabs, action sheets, and the global order summary bar are pinned to the bottom 35% of the screen. Menus and catalogue selection live in the middle scroll area, while static meta-info (table number, printer status) occupies the top header.
- **Grid Structure:** A tight 4-column fluid layout on mobile viewports using 12px (`0.75rem`) gutters and 16px (`1rem`) screen margins. Food item grid spans 2 columns each, maintaining symmetric square touch targets.
- **Vertical Density:** Spacing utilizes multiples of 4px. Compact 8px (`space-sm`) and 12px (`space-md`) paddings are prioritized within order item strips to display 6-8 line items simultaneously without demanding endless vertical scrolling.

## Elevation & Depth

To maintain high rendering performance and battery efficiency on budget-friendly Android terminals, the system eschews heavy multi-layered shadows in favor of **structural containment and low-contrast borders**:

- **Ground Level (Canvas):** Deep flat surface (`#F8F9FA`).
- **Surface Level (Cards, Order Rows):** Flat `#FFFFFF` with a 1px solid `#E5E7EB` boundary outline. No drop shadow.
- **Floating Overlays (Bottom Print Tray, Quick Pay Dock):** 
  - Ambient shadow: `0px -4px 16px rgba(17, 24, 39, 0.06)`.
  - Top border: 1px solid `#E5E7EB`.
- **Modals & Bottom Sheets:** Crisp elevation backed by a 50% opacity dim scrim (`rgba(17, 24, 39, 0.5)`).
- **Physical Touch Feedback:** Clickable items transition on touch down (`:active`) via scale compression (`scale(0.97)`) and subtle surface darkening (`#F3F4F6`), creating an immediate hardware-like feel.

## Shapes

The interface implements **Level 2 (Rounded)** curvature with specific semantic scales:
- **Base Components (Inputs, Menu Cards, Modals):** `rounded-lg` (16px / 1rem) for an approachable, modern profile.
- **Interactive Buttons:** `rounded-lg` (16px / 1rem) to match card radii.
- **Status Tags, Badges & Counter Chips:** Full-pill execution (`rounded-full` / 9999px) to contrast against structural rectilinear product rows.
- **Receipt Visual Containers:** Upper corners rounded at 16px, bottom edge styled with an optional flat-toothed geometric zigzag border evoking 58mm thermal roll cut lines.

## Components

### Buttons
- **Primary Order / Print Trigger:** Full-width, minimum height 52px (well exceeding the 48px mobile touch minimum). Solid `#EA580C` background, white label in `label-lg`, rounded-xl (16px). Accompanied by haptic vibration on trigger.
- **Secondary Actions (Kitchen Send, Draft):** White background, 1.5px border `#E5E7EB`, text `#111827`, active fill `#F3F4F6`.
- **Destructive (Cancel Bill, Remove Item):** Ghost styling with text `#DC2626` and active background `#FEE2E2`.

### Status Badges & Chips
- **"Chưa thanh toán" (Unpaid):** Amber background `#FEF3C7`, text `#B45309`, 1px border `#FDE68A`, rounded-full, `label-sm`, uppercase tracking.
- **"Đã thanh toán" (Paid):** Green background `#DCFCE7`, text `#15803D`, 1px border `#BBF7D0`, rounded-full, `label-sm`, uppercase tracking.
- **Filter Chips (Rice, Soup, Drinks, Extras):** Inactive: `#FFFFFF` card with `#E5E7EB` border. Active: Solid `#111827` dark fill with pure `#FFFFFF` label. Height 38px.

### Order Row & Lists
- Dense list layout: Left section features vertical quantity adjuster (`+` and `-` square buttons 36x36px with tactile grey stroke). Center contains dish title and modifier labels. Right contains bold right-aligned tabular price (`price-receipt`).

### Input Fields & Steppers
- Numeric touch pad inputs for custom discounts and split VND payments: Large 56px keypad cells with 16px typography and instant tactile grey inset highlights.
- Search input: 48px height, rounded-xl, left-anchored magnifying glass icon, light grey canvas interior (`#F3F4F6`), zero exterior outline unless focused (transitions to 1.5px `#EA580C`).

### Bluetooth 58mm Receipt Preview
- Simulated narrow width (fixed 280px representation on mobile screen), centered on a slight warm-grey contrast. Displays mono-spaced alignment lines, dash dividers, QR code container, and a real-time status pill indicating ESC/POS printer hardware link status.