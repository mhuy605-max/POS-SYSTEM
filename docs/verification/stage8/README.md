# Stage 8 — Production Acceptance Candidate

## Candidate identity

- Branch: `stage8/production-candidate`
- Android application ID and namespace: `com.dakao.inbill`
- Visible application name: `Đakao In Bill`
- Version: `1.0.0+1` (`versionName` 1.0.0, `versionCode` 1)
- Launcher artwork source: `assets/branding/dakao_app_icon.png`

The launcher provides density-specific legacy square and round icons plus an
adaptive icon for Android 8 and later. The approved startup and splash resources
remain unchanged.

## Accepted production scope

This candidate retains UI + Motion V2.1 and the production-only Stage 7 receipt
and Bluetooth changes. Hardware Lab routes, screens, controllers, diagnostic
MethodChannel calls, diagnostic generators, adjustable diagnostic parameters,
and diagnostic logging are excluded.

The physically verified printer profile remains 384 dots, 160-dot raster bands,
512-byte Bluetooth writes, and 0 ms inter-chunk delay. Physical verification
applies only to the tested MP-58N and does not claim compatibility with other
printers or MP-58N revisions. See the
[Stage 7B verification record](../stage7b/README.md).

## Release signing boundary

The current Gradle release build intentionally uses the Android debug signing
configuration. It is suitable for candidate installation and validation, but
the resulting release APK is **not the final distributable V1 APK**.

No keystore, key properties file, password, or other signing secret is committed
to the repository. Before distributing V1:

1. Generate the permanent production keystore outside the repository.
2. Store the keystore and credentials in secure, backed-up release storage.
3. Supply signing values through untracked local configuration or CI secrets.
4. Configure the Gradle `release` build type to use that release signing setup.
5. Build a fresh release artifact and verify its certificate with `apksigner`.
6. Install and run the permanently signed artifact on the target Android device,
   including one MP-58N print.
7. Preserve the signing key for all future updates and increment `versionCode`
   for every later distributed build.

## Automated gate

Verified on 2026-10-04:

- Dart formatting: 82 files checked, 0 changed.
- Flutter analysis: passed with no issues.
- Full Flutter suite: all 163 tests passed.
- Focused printing suite: all 23 tests passed.
- API 36 order-flow integration test: passed.
- API 36 backup/restore integration test: passed.
- Git whitespace check: passed.
- Debug and release APK builds: passed.
- APK metadata inspection confirmed `com.dakao.inbill`, version name `1.0.0`,
  version code `1`, label `Đakao In Bill`, and
  `com.dakao.inbill.MainActivity` in both artifacts.
- `apksigner` verified both artifacts and confirmed that the release candidate
  uses the Android Debug certificate.

Artifacts:

- Debug SHA-256:
  `0D68F671FF97080904C48B8E1390EA47BF9B749043218D5E09AB4B47F02A75D6`
- Release-candidate SHA-256:
  `DA02F4A7D5D25E19A77464F1A3B43C58EEED23E1BC20D090BF42C27DDADB2F79`

The repository remains uncommitted until final real-device acceptance is
complete.

## Final real-device V1 candidate acceptance

**FINAL REAL-DEVICE V1 CANDIDATE ACCEPTANCE: PASS**

The owner accepted the final candidate on a real Android device on 2026-10-04.
The accepted checks covered:

- permanent application identity `com.dakao.inbill`;
- visible name `Đakao In Bill`;
- final launcher icon and startup experience;
- core sales flow and UNPAID-to-PAID transition;
- revenue behavior and persistence across restart;
- backup flow;
- normal production printing on the physically tested MP-58N; and
- Vietnamese receipt output.

The Đakao In Bill V1 feature scope is frozen at this accepted candidate. Final
distribution still requires permanent production signing and one installation
and MP-58N smoke print of the permanently signed APK before tagging V1.0.0.
