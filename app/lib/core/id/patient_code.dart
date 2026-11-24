/// Patient identifier stored on NFC wristbands and in QR codes.
///
/// Format: `HPT-` + 8 characters of Crockford Base32 (digits and letters
/// without I, L, O, U), e.g. `HPT-7K3M9QXA`. The same parser is used for NFC
/// and QR, so both paths accept and reject exactly the same input.
/// See docs/ID_FORMAT.md.
library;

/// A validated patient code, always in canonical upper-case form.
extension type const PatientCode._(String value) {
  /// The format, anchored. Matches canonical (upper-case) codes only.
  static final RegExp pattern = RegExp(r'^HPT-[0-9A-HJKMNP-TV-Z]{8}$');

  /// Normalises raw scanner input and validates it.
  ///
  /// Trims surrounding whitespace (NFC text records and QR scanners often add
  /// a newline) and upper-cases, so `hpt-7k3m9qxa` is accepted. Returns null
  /// for anything else: wrong prefix, wrong length, forbidden letters
  /// (I, L, O, U), inner spaces, empty input. Never guesses: `O` is not read
  /// as `0`.
  static PatientCode? tryParse(String? raw) {
    if (raw == null) return null;
    final normalised = raw.trim().toUpperCase();
    if (!pattern.hasMatch(normalised)) return null;
    return PatientCode._(normalised);
  }

  /// Whether [raw] would parse.
  static bool isValid(String? raw) => tryParse(raw) != null;
}
