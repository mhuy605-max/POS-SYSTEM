# Đakao In Bill

Offline-first Android point-of-sale app for a Vietnamese food shop. The V1
production candidate includes catalog management, sales and order workflows,
revenue reporting, Bluetooth receipt printing, settings, and local
backup/restore.

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

The permanent Android application ID is `com.dakao.inbill`, and the V1
candidate version is `1.0.0+1`. Android minimum API 24 follows this Flutter
version. The current release build still uses debug signing for candidate
validation, so it is not the final distributable V1 artifact.

## Project references

- [Approved technical design](docs/superpowers/specs/2026-09-30-dakao-in-bill-design.md)
- [Implementation plan](docs/superpowers/plans/2026-09-30-dakao-in-bill.md)
- [Dependency review](docs/verification/dependencies.md)

`feature/full-pos` is the production-candidate development line. Stage 7B on
`debug/mp58n` physically verified the accepted 384-dot receipt profile on the
tested MP-58N. This result does not claim compatibility with other printer
models or untested MP-58N revisions; see the
[Stage 7B verification record](docs/verification/stage7b/README.md).

The production UI follows the approved Stitch reference and UI + Motion V2.1.
