# Stage 7B — MP-58N Physical Hardware Verification

## Final status

**PASS — VERIFIED ON REAL MP-58N**

- Verification recorded: 2026-10-04
- Branch: `debug/mp58n`
- Printer: MP-58N 58 mm Bluetooth thermal printer
- Printer firmware/revision: not reported
- Android handset model/version used for acceptance: not recorded
- Scope: the tested printer unit, Android environment, application build, and
  profile described below

This result closes the Stage 7B physical hardware gate. It is evidence for the
tested MP-58N only. It does not establish compatibility with other MP-58N
firmware revisions, printers sold under similar names, other 58 mm printers,
or every Android Bluetooth implementation.

## Verified production candidate profile

| Parameter | Physically accepted value |
| --- | ---: |
| Printable width | 384 dots |
| Raster command | ESC/POS `GS v 0` |
| Raster band height | 160 dots |
| Bluetooth transport | Bluetooth Classic/SPP |
| Bluetooth chunk size | 512 bytes |
| Inter-chunk delay | 0 ms |

No printer parameter change was required after the accepted typography test.

## Physical acceptance results

The following results were observed with the real MP-58N and accepted by the
user:

- Android connected to the paired printer over Bluetooth Classic/SPP.
- ESC/POS receipt payloads reached the printer and produced physical paper.
- `GS v 0` monochrome raster output printed at 384 dots without clipping.
- Rasterized Vietnamese text printed with readable diacritics.
- The final receipt typography, hierarchy, alignment, wrapping, and margins
  were accepted on paper.
- Complete receipt output was produced.
- Five consecutive prints completed successfully.
- Reconnection succeeded after turning the printer off and on.
- Reconnection succeeded after restarting the app.
- Printing remained stable across multiple printer power cycles.
- Attempting to print while the printer was unavailable was handled without an
  app crash.
- An interrupted print was handled without an app crash.
- The saved order remained intact when printing failed.
- No unwanted automatic resend was observed after failure or interruption.

## Failure and interruption semantics

The physical tests support the existing safety behavior: printing is separate
from order persistence, so a transport failure does not delete the saved order.
The application does not automatically resend after an interrupted or
ambiguous transmission. Existing `UNKNOWN_OUTCOME` handling remains necessary
because Bluetooth SPP write completion does not prove that the printer finished
putting every line on paper.

The physical exercise did not change print-attempt persistence, order state,
database transactions, cancellation rules, or revenue behavior.

## Receipt typography accepted on paper

The accepted production receipt uses the following rasterized text sizes:

| Role | Font size |
| --- | ---: |
| Shop name | 30 |
| Address and phone | 18.5 |
| Order heading | 25 |
| Date/time | 17.5 |
| Order type | 18.5 |
| Item name | 25 |
| Item price | 20 |
| Item note | 16 |
| Grand total | 27 |
| Footer | 18.5 |

Text uses an 18-dot safety inset while separators retain the established
16-dot endpoints. Long text wraps within the 384-dot raster. Item prices and
grand totals retain left/right alignment and move to a continuation line when
an unusually large value cannot fit safely on one line.

## Automated closure gate

- `dart format --output=none --set-exit-if-changed lib test integration_test`:
  87 files checked, 0 changed.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 165 tests passed.
- API 36 `integration_test/order_flow_test.dart`: passed.
- API 36 `integration_test/backup_restore_test.dart`: passed.
- `git diff --check`: passed.
- `flutter build apk --debug`: passed.
- `flutter build apk --release`: passed. This confirms buildability only; the
  release artifact is not signed for production and was not the physical test
  artifact.

## Remaining non-blocking limitations

- Compatibility is verified only for the physically tested MP-58N unit. Other
  printers and untested MP-58N firmware revisions remain unverified.
- The specific Android handset model and OS version were not recorded, so this
  result is not evidence for every Android vendor Bluetooth stack.
- Pairing still occurs in Android settings; the application lists bonded
  devices and does not perform active Bluetooth discovery.
- Basic Bluetooth SPP provides no reliable paper-complete acknowledgement.
  Operators must inspect paper after an ambiguous or interrupted transmission
  and choose whether to reprint.
- Long receipts, different paper rolls, low-battery operation, extreme radio
  interference, and printer buffer behavior beyond the accepted tests are not
  universally characterized.
- Release signing and production deployment remain separate release tasks. A
  successful release APK build is not a physical test of that release artifact.

## Compatibility boundary

### VERIFIED ON REAL MP-58N

The connection, Bluetooth Classic/SPP transport, ESC/POS transmission,
`GS v 0` raster output, 384-dot layout, Vietnamese diacritics, accepted receipt
typography, repeated printing, reconnect flows, tested power cycles, and tested
failure/interruption behavior listed above.

### NOT VERIFIED / GENERAL ASSUMPTIONS

Compatibility with other printer models, look-alike 58 mm devices, different
MP-58N firmware or hardware revisions, every Android handset, alternate raster
widths, alternate band heights, alternate chunk sizes, or nonzero inter-chunk
delays. No such compatibility is claimed by Stage 7B.
