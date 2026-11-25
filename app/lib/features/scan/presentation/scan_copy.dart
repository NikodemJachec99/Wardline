/// Scan texts. Source: design/handoff/copy.md → Scan, plus the artboards
/// `ScanQr`, `ScanSuccess` and `ScanEdge` for strings copy.md doesn't list.
abstract final class ScanCopy {
  static const String title = 'Scan patient'; // scan.title
  static const String titleQr = 'Scan QR code'; // ScanQr, ScanEdge
  static const String hold =
      "Hold your phone near the patient's wristband"; // scan.hold
  static const String holdHintIos =
      'Top edge of the iPhone, 1–2 cm from the band.'; // scan.holdHint.ios
  static const String holdHintAndroid =
      'Hold the back of the phone to the wristband'; // scan.holdHint.android
  static const String rule =
      'Scanning opens the record — it never moves the patient.'; // scan.rule
  static const String start = 'Start scanning'; // scan.start
  static const String iosAlert =
      "Hold near the patient's wristband"; // scan.iosAlert
  static const String identified = 'Patient identified'; // scan.identified

  static const String invalidTitle =
      "This tag doesn't contain a Wardline patient ID"; // scan.invalid.title
  static const String invalidBody =
      'It may be a tag from another system or a damaged wristband. '
      'No record was opened.'; // scan.invalid.body

  /// scan.unknown.title is "{code} isn't registered".
  static const String unknownTitleSuffix = " isn't registered";
  static const String unknownBody =
      'The wristband was read correctly, but no patient has this ID. '
      'Check the band, or find the patient by name.'; // scan.unknown.body

  static const String noNfcTitle =
      "NFC isn't available on this device"; // scan.noNfc.title
  static const String noNfcBody =
      "It's turned off or not supported. Switching to the QR code on the "
      'wristband so you can keep working.'; // scan.noNfc.body

  static const String cameraTitle = 'Camera access is off'; // scan.camera.title
  static const String cameraBody =
      'Wardline needs the camera to read wristband QR codes. '
      'Turn it on in Settings › Wardline › Camera.'; // scan.camera.body

  static const String qrHint =
      'Point at the QR code on the wristband'; // scan.qr.hint
  static const String qrSubHint =
      'It reads automatically. Scanning never moves the patient.'; // ScanQr

  // Artboard labels (ScanNfc, ScanQr, ScanSuccess, ScanEdge).
  static const String close = 'Close scanner';
  static const String cancel = 'Cancel';
  static const String methodGroup = 'Scan method';
  static const String methodNfc = 'NFC wristband';
  static const String methodQr = 'QR code';
  static const String torch = 'Torch';
  static const String switchToNfc = 'Switch to NFC';
  static const String viewfinder = 'Viewfinder';
  static const String scanAgain = 'Scan again';
  static const String useQrInstead = 'Use the QR code instead';
  static const String useNfcInstead = 'Use NFC instead';
  static const String searchPatient = 'Search patient';
  static const String switchingToQr = 'Switching to QR…';
  static const String useQrNow = 'Use QR now';
  static const String openSettings = 'Open Settings';

  /// Android, NFC switched off: platform-and-a11y.md "offer system NFC
  /// settings". Not in copy.md yet (suggested key `scan.noNfc.settings`).
  static const String openNfcSettings = 'Open NFC settings';

  static const String viewProfile = 'View profile';
  static const String history = 'History';
  static const String transfer = 'Transfer →';
  static const String changeStatus = 'Change status →';
  static const String status = 'Status';
  static const String lastLocation = 'Last location';
  static const String nothingChanged = 'Nothing has changed.';
  static const String nurseHint = 'Transfer opens a separate confirm step.';
  static const String doctorHint =
      'Status changes open a separate confirm step.';

  /// Lookup failed (copy.md → Lists: load.failed.title).
  static const String loadFailed = "Couldn't load patients";

  static String unknownTitle(String code) => '$code$unknownTitleSuffix';
}
