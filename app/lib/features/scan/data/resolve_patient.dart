import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/id/patient_code.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';

/// Result of turning raw scanner text (NFC NDEF Text or QR) into a patient.
sealed class ScanResolution {
  const ScanResolution();
}

/// Not a Wardline ID (`scan.invalid.*`).
final class ScanInvalid extends ScanResolution {
  const ScanInvalid();
}

/// Valid format, no patient with it (`scan.unknown.*`).
final class ScanUnknown extends ScanResolution {
  const ScanUnknown(this.code);
  final PatientCode code;
}

final class ScanFound extends ScanResolution {
  const ScanFound(this.patient);
  final Patient patient;
}

/// `resolvePatient(raw)` from platform-and-a11y.md: one path for NFC and QR.
/// Read only: `select … where patient_code = :code`. Never writes.
Future<ScanResolution> resolvePatient(
  HospitalRepository repo,
  String? raw,
) async {
  final code = PatientCode.tryParse(raw);
  if (code == null) return const ScanInvalid();
  final patient = await repo.findByCode(code.value);
  return patient == null ? ScanUnknown(code) : ScanFound(patient);
}

/// "Now" for the scan time on the summary ("NFC · 10:44"). Tests pin it.
final scanClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
