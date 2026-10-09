# Đakao In Bill

Offline-first Android point-of-sale app for a Vietnamese food shop.

**Latest release: V1.1.0** — [Download APK](https://github.com/mhuy605-max/POS-SYSTEM/releases/tag/v1.1.0)

Đakao In Bill supports product catalog management, reusable optional product add-ons, manual product ordering, sales and order workflows, revenue reporting, Bluetooth thermal receipt printing, shop settings, and local backup/restore.

## Features

- **Product catalog:** Manage products, categories, prices, and availability.
- **Reusable product options:** Configure optional add-ons such as extra pork, egg, and other toppings. Attach option groups to multiple products.
- **Manual product ordering:** Reorder products and preserve the order across app restarts.
- **Sales and orders:** Build orders, edit configured cart items, save orders locally, and mark orders as paid.
- **Revenue reporting:** Calculate paid revenue using the existing order-payment timestamps and status rules.
- **Bluetooth receipt printing:** Print Vietnamese receipts on the verified MP-58N thermal printer profile.
- **Multiline receipt footer:** Preserve multiple footer lines and intentional blank lines.
- **Local backup and restore:** Back up and restore app data, with compatibility for V1.0 backups.
- **Historical snapshots:** Preserve sold-product details, option prices, and receipt settings for existing orders.

## Download

Get the latest stable release from GitHub:

**[Đakao In Bill v1.1.0 — APK and release notes](https://github.com/mhuy605-max/POS-SYSTEM/releases/tag/v1.1.0)**

| Release detail | Value |
|---|---|
| Version | `1.1.0` |
| Android application ID | `com.dakao.inbill` |
| Android version code | `2` |
| Minimum Android API | `24` |
| Release channel | Stable |

Install the APK over an existing installation to upgrade while preserving local app data. Do not uninstall the existing app or clear its data when upgrading.

## Development

Verified SDK versions and gate results are recorded in [environment.md](docs/verification/environment.md).

Use Flutter **3.47.5** / Dart **3.13.4** and the committed `pubspec.lock`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d emulator-5554
```

On the original configured Windows workstation:

- Flutter: `C:\Users\ACER\develop\flutter\`
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`
- Java: `C:\Program Files\Java\jdk-21.0.11`

User `PATH`, `ANDROID_HOME`, and `JAVA_HOME` were configured on that workstation. Restart existing terminals or IDEs after changing environment variables.

## Printer compatibility

The production receipt profile was physically verified with the **MP-58N** printer:

- Bluetooth Classic / SPP
- ESC/POS raster printing (`GS v 0`)
- 384-dot receipt width
- Vietnamese text rendered as raster graphics
- Deterministic raster banding and final paper feed

Compatibility is claimed only for the tested MP-58N and configuration. Other printer models, firmware revisions, and Android Bluetooth stacks have not been universally verified.

See the [Stage 7B verification record](docs/verification/stage7b/README.md).

## Project references

- [Approved technical design](docs/superpowers/specs/2026-09-30-dakao-in-bill-design.md)
- [Implementation plan](docs/superpowers/plans/2026-09-30-dakao-in-bill.md)
- [Dependency review](docs/verification/dependencies.md)
- [Environment verification](docs/verification/environment.md)
- [Stage 7B printer verification](docs/verification/stage7b/README.md)

The production UI follows the approved Stitch reference and UI + Motion V2.1.

## Production and data safety

- The app stores its operational data locally.
- Order data is committed before receipt printing.
- A printing failure does not automatically create a duplicate order.
- Historical order and receipt snapshots remain independent of subsequent catalog or shop-setting changes.
- V1.0 database migration and backup compatibility were verified as part of the V1.1 release.

Keep a secure backup of important business data and the exported `.dakbackup` files.

## Release history

- **V1.1.0:** Reusable optional product options, manual product ordering, multiline receipt footer support, improved MP-58N final paper-feed clearance, and V1.0 database/backup compatibility.
- **V1.0.0:** Initial production release with catalog management, sales and order workflows, revenue reporting, Bluetooth receipt printing, settings, and local backup/restore.
