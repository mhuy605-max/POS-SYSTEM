# Motion and startup audit V2.1

Audit source: `polish/ui-v2` at `eeffdb9c0fd3784b907702897be11c0a9ac3aa89`.

## Motion inventory

1. **Motion tokens:** `AppMotion.fast` is 120 ms, `standard` is 180 ms, and `spatial` is 220 ms. All use `Curves.easeOutCubic`; `AppMotion.duration` resolves to zero when `MediaQuery.disableAnimations` is true. Press-down and release currently share the same duration.
2. **AnimatedContainer:** used by semantic status badges and each independent order-type button. It animates color/border changes locally.
3. **AnimatedSwitcher:** used by `AppAnimatedValue` for compact totals/quantities and by Revenue for the entire report content. The shared value switcher uses stable `ValueKey(value)` identities, but the default layout may retain multiple outgoing children during rapid changes.
4. **AnimatedOpacity:** used only to dim disabled order-type controls.
5. **AnimatedScale:** used by `AppPressable`; it scales product cards to 0.985 from `InkWell.onHighlightChanged`. Its one 120 ms timing makes press-down feel less immediate than necessary.
6. **TweenAnimationBuilder:** none.
7. **AnimationController:** none, so there are no controller lifecycle leaks in the current presentation layer.
8. **Page/navigation transitions:** root destinations use `NoTransitionPage`, while detail/form routes use GoRouter's default Material transition. There is no explicit dialog transition override.
9. **Bottom navigation:** a `ShellRoute` creates the selected root page as its child. Switching roots replaces that route subtree instead of retaining all five destination trees, so scroll/search state can be discarded and providers/screens can be reconstructed.

## Rebuild and interaction scope

10. **Provider breadth:** `SalesScreen` watches the complete `CartState`; `ReviewScreen` also watches the complete state. Orders and Revenue each watch their full asynchronous presentation state at screen root.
11. **Cart/product grid:** every add/remove/quantity/note/order-type/submission update rebuilds `SalesScreen`, including search, category chips, the `CustomScrollView`, and every visible product card. Product images are therefore rebuilt even though the catalog did not change.
12. **Quantity controls:** every increment/decrement rebuilds `ReviewScreen`, the list, all keyed line-card widgets, order-type controls, and the bottom action area. Keys preserve state objects, but build work remains broad. Tap handlers mutate state immediately and do not wait for animation.
13. **Revenue period:** selecting a period rebuilds the screen through selection, derived period, and stream providers. The resulting report is wrapped in one large `AnimatedSwitcher`, creating a large opacity layer and replacing the chart/cards together.
14. **Order filter:** the async order-list provider rebuilds filter and list together. Filter state is stored on the notifier and becomes visible because refresh emits loading; content replacement is immediate apart from Material control styling.
15. **Form validation:** forms use standard Flutter field validation. No explicit validation animation exists; errors can change layout abruptly. There is no whole-form animation.
16. **Dialogs:** dialogs use Flutter's default route transition and the V2 dialog surface theme. Confirmation state changes remain tied to completed operations.

## Startup

17. **Android launch theme:** pre-Android-12 launch drawables are the Flutter template: white in light mode and dynamic/black in dark mode. `NormalTheme` also uses dynamic system backgrounds. There is no Android 12-specific branded splash. These surfaces do not match `#FAF8F5` and explain observed white/black launch flashes. The approved logo reference exists at `docs/design/stitch_akao_in_bill_pos/akao_in_bill_logo/screen.png` but is not used by the application.
18. **Flutter initialization:** `main()` awaits application-support lookup, database directory creation/open, a second support-directory lookup, restore-service construction, and `recoverPendingRestore()` before `runApp`. The native launch surface stays visible during real work, but Flutter has no branded initialization state, actionable failure state, or safe retry. A thrown initialization/recovery error prevents the first Flutter frame. No artificial delay exists.

## Root causes and targeted response

Perceived stiffness is caused primarily by broad synchronous rebuild scope, discarded destination trees, a large revenue opacity transition, and identical press-down/release timing. Duration changes alone would not resolve these issues.

The implementation will therefore:

- split sales catalog and cart-summary watches so cart taps do not rebuild the grid;
- select cart structure, individual lines, totals, and order type separately in the current-order screen;
- prevent stale outgoing value widgets from accumulating during rapid changes;
- use shorter press-down/release and selection-specific timings;
- replace the two independent order-type surfaces with one lightweight sliding segmented indicator;
- retain root destination state with an indexed navigation shell and keep root content changes immediate;
- remove the large Revenue content crossfade and narrow Revenue/Orders consumers;
- add a matching native launch surface using a copied approved logo asset;
- run real initialization after Flutter can render, with a minimal branded state, actionable failure, safe retry, and no artificial delay;
- preserve all Stage 1–6 domain, recovery, persistence, printing, backup, and revenue behavior.
