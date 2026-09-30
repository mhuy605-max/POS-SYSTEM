# Đakao In Bill

Offline-first Android app for a Vietnamese food shop. This repository currently contains the **Stage 0 bootstrap only**: app entry point, Riverpod scope, router, theme seed, and five empty navigation destinations. It does not implement orders, SQLite tables, revenue, backup or printing yet.

## Development

Verified SDK versions and gate results are recorded in [environment.md](docs/verification/environment.md). Use Flutter **3.47.5** / Dart **3.13.4** and the committed `pubspec.lock`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d emulator-5554
```

On the configured Windows workstation, Flutter is installed at `C:\Users\ACER\develop\flutter`, Android SDK at `%LOCALAPPDATA%\Android\Sdk`, and Java at `C:\Program Files\Java\jdk-21.0.11`. User PATH, ANDROID_HOME and JAVA_HOME are configured. Restart existing terminals/IDEs to inherit them.

The Android application ID is temporarily `com.example.dakao_in_bill`; select a permanent ID before release signing. Android minimum API 24 follows this Flutter version; confirm the shop phone before release. The scaffold's release signing is still Flutter's debug default, so no production release is prepared.

## Project references

- [Approved technical design](docs/superpowers/specs/2026-09-30-dakao-in-bill-design.md)
- [Implementation plan](docs/superpowers/plans/2026-09-30-dakao-in-bill.md)
- [Dependency review](docs/verification/dependencies.md)

`feature/full-pos` is the production-candidate development line. Create `debug/mp58n` when physical printer testing starts. MP-58N compatibility remains **hardware-unverified**.

The approved Stitch reference is still needed before product UI work; the current shell is not a recreation of that prototype. Stage 1 requires a passed Stage 0 gate and a subsequent instruction to proceed.
