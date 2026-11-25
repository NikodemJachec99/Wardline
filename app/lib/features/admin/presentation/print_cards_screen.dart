// Print patient cards & QR (Admin artboard, last phone). SIMULATION: no
// printer is contacted and the QR preview is a placeholder pattern, not a
// scannable code. The real QR holds the patient ID only, no medical data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';
import '../../dashboard/presentation/widgets/dashboard_parts.dart';
import 'widgets/admin_widgets.dart';

class PrintCardsScreen extends ConsumerStatefulWidget {
  const PrintCardsScreen({super.key});

  @override
  ConsumerState<PrintCardsScreen> createState() => _PrintCardsScreenState();
}

class _PrintCardsScreenState extends ConsumerState<PrintCardsScreen> {
  bool _wristband = false;
  Set<String>? _selected;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final patients =
        ref
            .watch(hospitalProvider)
            .patients
            .where((p) => p.status != PatientStatus.discharged)
            .toList()
          ..sort((a, b) => b.admittedAt.compareTo(a.admittedAt));
    final recent = patients.take(8).toList();
    final selected = _selected ??= recent.take(3).map((p) => p.id).toSet();
    final chosen = recent.where((p) => selected.contains(p.id)).toList();
    final preview = chosen.firstOrNull ?? recent.firstOrNull;
    final n = chosen.length;
    final what = _wristband ? 'label' : 'card';

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WlLargeTitle(title: 'Print cards', showBack: true),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
                children: [
                  _Segments(
                    wristband: _wristband,
                    onChanged: (v) => setState(() => _wristband = v),
                  ),
                  SizedBox(height: t.space.sm + 2),
                  if (preview != null)
                    _CardPreview(patient: preview, months: _months),
                  SizedBox(height: t.space.sm),
                  const SimulationNote(
                    'Simulation: nothing is printed and the QR is a '
                    'placeholder. The real code holds the patient ID only.',
                  ),
                  SizedBox(height: t.space.md),
                  GroupLabel('Patients · $n selected'),
                  SizedBox(height: t.space.xs - 2),
                  DashCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, p) in recent.indexed) ...[
                          if (i > 0)
                            Divider(height: 1, thickness: 1, color: c.border),
                          _CheckRow(
                            patient: p,
                            checked: selected.contains(p.id),
                            onChanged: (v) => setState(() {
                              v ? selected.add(p.id) : selected.remove(p.id);
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: t.space.md),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.xs,
                t.space.gutter,
                t.space.md + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Printer: Ward printer INT-02',
                    textAlign: TextAlign.center,
                    style: t.typography.caption.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: t.space.xs),
                  WlButton(
                    label: 'Print $n ${n == 1 ? what : '${what}s'}',
                    icon: WlIcons.printer,
                    // Disabled only while the form is invalid (none picked).
                    onPressed: n == 0
                        ? null
                        : () => showWlToast(
                            context,
                            title: 'Simulation · nothing was printed',
                            body:
                                '$n ${n == 1 ? what : '${what}s'} would go to '
                                'Ward printer INT-02.',
                            tone: WlToastTone.info,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.wristband, required this.onChanged});

  final bool wristband;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    Widget seg(String label, bool value) {
      final on = wristband == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Container(
              constraints: BoxConstraints(
                minHeight: t.space.touchMin - 2 * (t.space.xxs - 1),
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
              decoration: BoxDecoration(
                color: on ? c.surface : null,
                borderRadius: t.radius.chipBr,
                boxShadow: on ? t.elevation.e1 : null,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: t.typography.subhead.copyWith(
                  color: on ? c.text : c.textSecondary,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(t.space.xxs - 1),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: BorderRadius.circular(t.radius.input - 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [seg('Card 85×54 mm', false), seg('Wristband label', true)],
        ),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.patient, required this.months});

  final Patient patient;
  final List<String> months;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final a = patient.admittedAt;
    return Container(
      padding: EdgeInsets.all(t.space.sm + 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: t.radius.inputBr,
        border: Border.all(color: c.borderStrong),
        boxShadow: t.elevation.e2,
      ),
      child: Row(
        children: [
          Semantics(
            image: true,
            label: 'QR code preview for ${patient.code}',
            child: SizedBox.square(
              dimension: 105,
              child: CustomPaint(
                painter: _QrPlaceholderPainter(patient.code, c.text),
              ),
            ),
          ),
          SizedBox(width: t.space.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WARDLINE',
                  style: t.typography.overline.copyWith(
                    color: c.primaryInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: t.space.xxs),
                Text(
                  patient.fullName,
                  style: t.typography.title3.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${patient.age} · Admitted ${a.day} ${months[a.month - 1]} '
                  '${a.year}',
                  style: t.typography
                      .tabular(t.typography.caption)
                      .copyWith(color: c.textSecondary),
                ),
                SizedBox(height: t.space.xxs),
                Text(
                  patient.code,
                  style: t.typography.id.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.patient,
    required this.checked,
    required this.onChanged,
  });

  final Patient patient;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      checked: checked,
      label: '${patient.fullName}, ${patient.code}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.sm + 2,
              vertical: t.space.xs - 2,
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: checked ? c.primaryInk : null,
                    borderRadius: BorderRadius.circular(t.radius.chip - 2),
                    border: Border.all(
                      color: checked ? c.primaryInk : c.borderStrong,
                      width: 2,
                    ),
                  ),
                  child: checked
                      ? Icon(WlIcons.check, size: 14, color: c.onPrimary)
                      : null,
                ),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: t.typography.callout.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        patient.code,
                        style: t.typography.id.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 21×21 placeholder with the three finder squares, seeded by the code so
/// it is stable. NOT a real QR code (simulation).
class _QrPlaceholderPainter extends CustomPainter {
  _QrPlaceholderPainter(this.code, this.color);

  final String code;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 21;
    final cell = size.width / n;
    final paint = Paint()..color = color;
    bool? finder(int r, int c) {
      for (final (r0, c0) in [(0, 0), (0, n - 7), (n - 7, 0)]) {
        if (r >= r0 && r < r0 + 7 && c >= c0 && c < c0 + 7) {
          final rr = r - r0, cc = c - c0;
          final ring = rr == 0 || rr == 6 || cc == 0 || cc == 6;
          final core = rr >= 2 && rr <= 4 && cc >= 2 && cc <= 4;
          return ring || core;
        }
      }
      return null;
    }

    var seed = code.codeUnits.fold<int>(
      7919,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        final f = finder(r, c);
        final sep =
            (r == 7 && (c < 8 || c > n - 9)) ||
            (c == 7 && (r < 8 || r > n - 9)) ||
            (r == n - 8 && c < 8) ||
            (c == n - 8 && r < 8);
        final on = f ?? (sep ? false : seed % 100 < 47);
        if (on) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPlaceholderPainter old) =>
      old.code != code || old.color != color;
}
