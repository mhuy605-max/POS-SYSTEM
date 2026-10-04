# Stage 0 environment and verification — 2026-09-30

Status: **Stage 0 PASS**. Stage 1 has not started.

## Installed baseline

- Windows 11 25H2, x64.
- Flutter 3.47.5 stable, revision 6a19cca56475dbfba1478ee68d7bd0c2ef891da1; Dart 3.13.4.
- Flutter root: `C:\Users\ACER\develop\flutter`.
- Android SDK: `C:\Users\ACER\AppData\Local\Android\Sdk`.
- Java: existing Oracle JDK 21.0.11, configured explicitly in Flutter.
- Android platform API 36 rev 2 and API 35 rev 2 (JNI dependencies); Build Tools 36.0.0; Platform Tools 37.0.1; NDK 28.2.13676358; CMake 3.22.1.
- Android command-line tools 22.0; Emulator 37.3.2; Google APIs x86_64 API 36 image revision 7.
- Flutter-generated Gradle 9.3.1, Android Gradle Plugin 9.1.0, Kotlin plugin declaration 2.4.0; Java/Kotlin bytecode target 17.
- Generated minSdk 24, targetSdk/compileSdk 36. MinSdk 23 proposed during planning is superseded by this stable Flutter baseline.
- Emulator `Dakao_API_36` (Pixel 7 profile), WHPX acceleration verified. No physical Android phone connected at initial adb check.

## Installation evidence and scope

Flutter archive SHA-256 verified against the official release manifest: `0ccd71931f49c2fbe394b1eeb6d79af3d624058a043ea0d03d34160581624fb8`.
Android CLI archive SHA-256 verified against the official Android download page: `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`.
Android package downloads stalled in sdkmanager's Java network reader. Official Google archives were downloaded with curl and verified against repository metadata before extraction. SDK Manager subsequently recognized the installed packages; emulator/NDK package metadata was reconstructed from Google's matching version metadata so avdmanager could recognize the installed binary. Slow Gradle Maven artifacts were also fetched via curl, checksum-verified against the official .sha1 files, and reused by Gradle with matching checksums. Flutter engine JARs were verified against Google Storage object MD5 headers. Because that repository has no SHA-1 sidecars, Gradle did not reuse manually seeded engine cache entries. The successful build used a temporary, project-scoped local Maven mirror containing only the three official engine JARs and their official POMs; no versions were substituted. The temporary Gradle init hook was removed after the build. The mirror and reusable init script remain under `C:\Users\ACER\develop\downloads\flutter-engine-maven` and `C:\Users\ACER\develop\downloads\dakao-stage0-verified-engine.gradle`. Future builds without the hook may need to finish the slow official engine downloads; the project itself retains standard repositories. No certificate checks were disabled. AVD creation reports missing optional system-image devices.xml but exits 0; actual boot/launch is the acceptance check.

Android SDK licenses accepted through sdkmanager. Full Android Studio was not installed; CLI tools are sufficient for this stage. User PATH was extended without removing existing entries; ANDROID_HOME and JAVA_HOME were set. Flutter analytics disabled. Existing processes need a restart or refreshed PATH to see the new tools.

## Gate results

- Dependency resolution: PASS (`flutter pub get`, lockfile included in the Stage 0 commit).
- Static analysis: PASS, no issues.
- Scaffold widget test: PASS, 1 test covers brand and navigation through all five destinations. Recorded expected red result against the original counter scaffold first.
- Debug APK build: PASS (`flutter --verbose build apk --debug --no-pub`), exit 0, BUILD SUCCESSFUL in 55s using the verified local engine mirror described above; all three default ABIs included.
- Emulator app launch: PASS. `adb install -r` returned Success; launching the then-temporary application ID's `.MainActivity` returned Status: ok, LaunchState: COLD, TotalTime: 5677 ms. UI hierarchy and screenshot confirm the brand, Bán hàng destination, and all five navigation tabs on API 36. See [launch screenshot](stage0-emulator.png).
- Flutter Doctor: Android toolchain and licenses pass; refreshed-PATH run passes Flutter and Android. Its only warning is the unrelated incomplete Windows desktop Visual Studio installation.

- Formatting: PASS (`dart format --output=none --set-exit-if-changed lib test`).
- Read-only Stage 0 review: no important or critical findings. Stale handoff wording corrected.
- Build warnings: generated Kotlin compatibility flags and plugin APIs report deprecations, including future Gradle 10 incompatibility; current Gradle 9.3.1 build passes. These are not physical-device or production-release acceptance results.

## Artifact and evidence

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk` (ignored build artifact).
SHA-256: `bb4846b97a6f5615d0fa842670614eb397443533be2b8ebb69c3e4bb004ee11c`.

Local detailed logs are retained in `.superpowers/sdd/2026-09-30-dakao-in-bill/` (ignored): `pub-get-final.log`, `analyze.log`, `test-red.log`, `test-green.log`, `doctor-final.log`, `build-debug-verified-mirror.log`, `emulator-ui.xml`, and `emulator-launch.png`. Earlier interrupted download/build logs are diagnostic history, not the final gate result.

## Decisions and limits

Only Stage 0 shell/configuration is implemented. No database/schema, business logic, sales, printing, revenue or backup implementation. Native Kotlin transport and narrow ESC/POS encoding were selected for Stage 4 after the package source gate failed; see dependencies.md.

Stage 0 used a temporary template application ID. Permanent identity and release signing remained later release prerequisites. The Flutter-generated release configuration used debug signing; that artifact was not a production release.

Stitch reference and shop phone model/Android version remain needed before their dependent UI/device acceptance stages. Current destinations are empty bootstrap screens, not approved prototype reproductions. MP-58N hardware compatibility is unverified.
