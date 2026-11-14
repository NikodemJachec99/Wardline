# Platform specifics and accessibility

## iOS
- NFC only through `NFCNDEFReaderSession` (via `nfc_manager`), started by a user tap on **Start scanning**. The system "Ready to Scan" sheet covers the app while reading; we only control its `alertMessage`: "Hold near the patient's wristband".
- On a successful read: stop the session (iOS shows its own tick), then run our brighten + haptic + quick summary sheet. User cancel → silent return to the pre-scan screen (no error, no toast).
- Entitlement `com.apple.developer.nfc.readersession.formats` (NDEF), `NFCReaderUsageDescription`, `NSCameraUsageDescription` in Info.plist. See `docs/BACKEND.md` for the manual entitlement step.
- Keep the Cupertino swipe-back on pushed pages. Sheets dismiss by drag except while a request is in flight.
- Safe areas: top inset ≈ 59pt (Dynamic Island), home indicator 34pt inside the 98pt tab bar. Use `SafeArea` / `MediaQuery.paddingOf`, never hard-coded numbers.

## Android
- Scan screen enables NFC reader mode while it is in the foreground and listens immediately: no Start button, no system sheet. Disable reader mode in `dispose` and when leaving the route.
- NFC off or missing (`NfcManager.isAvailable()` false): "NFC isn't available on this device. Switching to QR…", auto-switch after 2s, offer system NFC settings.
- Predictive back: `android:enableOnBackInvokedCallback="true"`. Back closes the scanner and any sheet; on a root tab it goes to Dashboard first, then leaves the app (`PopScope`).
- Edge-to-edge (Android 15+): draw behind system bars; bottom nav 80dp + gesture inset; status bar icons dark.
- Material ripple is fine, but colours and the 0.98 press scale come from `WlTokens`.

## Both
- One parser `resolvePatient(String raw)` for NFC (NDEF Text) and QR: trim, uppercase, regex `^HPT-[0-9A-HJKMNP-TV-Z]{8}$` → else "invalid tag"; lookup → else "unknown ID". The chip UID is never an identifier.
- Camera denied → explanation + **Open Settings** (`openAppSettings()`), plus "Use NFC instead".
- Bundle Inter as an asset (works offline). Tabular figures for every time, count, % and ID.
- Tablet layouts (Analytics, Ward monitor) at width ≥ 900dp. Phones keep the same order, stacked.
- Keyboard: sheets with inputs resize with `MediaQuery.viewInsetsOf`.

## Accessibility
- **Contrast AA.** Text only in `text`, `textSecondary`, `primaryInk` or status `fg` tokens (all ≥ 4.5:1 on their backgrounds). Brand teal `#0E9FA6` (3.2:1) is never used for text.
- **Occupancy colours** are below 3:1 as graphics, so the % label is mandatory and full / bottleneck wards also say "Full" / "Bottleneck" in words.
- **Touch targets** ≥ 48×48dp; primary actions 56dp. Chips 36dp visual with a 48dp hit area (`materialTapTargetSize: padded` or extra padding).
- **Status chip**: `Semantics(label: 'Status: In Treatment', excludeSemantics: true)`. The short "Ready" still reads "Ready for Discharge".
- **Patient card**: one merged node, e.g. "Jan Kowalczyk, 54, Laboratory, In Treatment, button". Swipe actions also as `customSemanticsActions` (View profile, Show on map).
- **Transfer path**: "From Laboratory to Radiology". Success, conflict, offline/online and toasts are live regions (announce once, not on every rebuild).
- **Map**: every department label is a real button ("Internal Medicine, 29 of 32 beds, 91 percent, bottleneck"). Add a "List view" toggle that shows the same data as a list. Route stops are focusable in order.
- **Charts**: one-sentence `Semantics` summary per chart ("Peak 09:00–10:00 with 11 transfers") and a "Show as table" option. KPIs announce the final value, never count-up frames.
- **Text scale**: support up to 200%. When `textScaler.scale(1) > 1.3`, side-by-side label/value rows become stacked; nothing truncates names, IDs or locations. Golden-test every screen at 2.0.
- **Reduced motion**: follow `motion.md` fallbacks via `WlMotion.reduced(context)`.
- **Focus**: order follows visual order; sheets trap focus and return it to the opener; focus ring is the 2px `primary` ring with a 2px white gap.
- **Never colour alone**: status = colour + icon + text; occupancy = colour + %; roles = ring colour + role label.
