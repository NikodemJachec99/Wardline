// Program wristband (Admin artboard, "Program NFC tag" steps 1–3).
// SIMULATION: nothing is written to a tag. The flow screens show what the
// real one does: pick a patient, hold a blank tag, write the ID only, read
// it back and compare.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';
import '../../dashboard/presentation/widgets/dashboard_parts.dart';
import 'widgets/admin_widgets.dart';

enum _Step { patient, write, verify }

class ProgramTagScreen extends ConsumerStatefulWidget {
  const ProgramTagScreen({super.key});

  @override
  ConsumerState<ProgramTagScreen> createState() => _ProgramTagScreenState();
}

class _ProgramTagScreenState extends ConsumerState<ProgramTagScreen> {
  _Step _step = _Step.patient;
  Patient? _patient;
  bool _writing = false;
  String _query = '';

  Future<void> _write() async {
    if (_writing) return;
    setState(() => _writing = true);
    final latency =
        ref.read(demoRepositoryProvider)?.knobs.latency ??
        const Duration(seconds: 1);
    // Write, then read back: two simulated round trips.
    await Future<void>.delayed(latency * 2);
    if (!mounted) return;
    setState(() {
      _writing = false;
      _step = _Step.verify;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final step = _step.index;

    final Widget body = switch (_step) {
      _Step.patient => _choosePatient(context),
      _Step.write => _writeStep(context),
      _Step.verify => _verifyStep(context),
    };

    final Widget? actions = switch (_step) {
      _Step.patient => null,
      _Step.write => WlButton(
        label: 'Start writing',
        loading: _writing,
        loadingLabel: 'Writing…',
        icon: WlIcons.nfc,
        onPressed: _write,
      ),
      _Step.verify => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WlButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
          SizedBox(height: t.space.xs),
          WlButton(
            label: 'Program another',
            variant: WlButtonVariant.secondary,
            dense: true,
            onPressed: () => setState(() {
              _patient = null;
              _step = _Step.patient;
            }),
          ),
        ],
      ),
    };

    return PopScope(
      canPop: !_writing,
      child: Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step != _Step.verify)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: LinkButton(
                    label: 'Cancel',
                    onTap: () {
                      if (!_writing) Navigator.of(context).maybePop();
                    },
                  ),
                )
              else
                SizedBox(height: t.space.touchMin),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Program wristband',
                    style: t.typography.title1.copyWith(color: c.text),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.gutter,
                  t.space.xs,
                  t.space.gutter,
                  0,
                ),
                child: StepBar(
                  labels: const ['Patient', 'Write', 'Verify'],
                  current: _step == _Step.verify ? 3 : step,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.gutter,
                  t.space.sm,
                  t.space.gutter,
                  0,
                ),
                child: const SimulationNote(
                  'Simulation: no tag is written. These screens show the '
                  'real flow.',
                ),
              ),
              Expanded(child: body),
              if (actions != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.gutter,
                    t.space.sm,
                    t.space.gutter,
                    t.space.md + bottom,
                  ),
                  child: actions,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choosePatient(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final q = _query.trim().toLowerCase();
    final patients =
        ref
            .watch(hospitalProvider)
            .patients
            .where((p) => p.status != PatientStatus.discharged)
            .where(
              (p) =>
                  q.isEmpty ||
                  p.fullName.toLowerCase().contains(q) ||
                  p.code.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => b.admittedAt.compareTo(a.admittedAt));
    return ListView(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        t.space.md,
        t.space.gutter,
        t.space.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Choose the patient for this wristband',
          style: t.typography.callout.copyWith(color: c.text),
        ),
        SizedBox(height: t.space.sm - 2),
        WlSearchBar(onChanged: (v) => setState(() => _query = v)),
        SizedBox(height: t.space.sm),
        DashCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, p) in patients.take(20).indexed) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: c.border),
                _PatientRow(
                  patient: p,
                  onTap: () => setState(() {
                    _patient = p;
                    _step = _Step.write;
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _writeStep(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final p = _patient!;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        t.space.md,
        t.space.gutter,
        0,
      ),
      children: [
        DashCard(
          padding: EdgeInsets.fromLTRB(
            t.space.sm + 2,
            t.space.xxs,
            t.space.xxs,
            t.space.xxs,
          ),
          child: Row(
            children: [
              WlInitialsAvatar.patient(p.fullName),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.fullName}, ${p.age}',
                      style: t.typography.callout.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      p.code,
                      style: t.typography.id.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!_writing)
                LinkButton(
                  label: 'Change',
                  semanticsLabel: 'Change patient',
                  onTap: () => setState(() => _step = _Step.patient),
                ),
            ],
          ),
        ),
        const SizedBox(height: 280, child: _Rings()),
        Text(
          _writing
              ? 'Writing… keep the tag still'
              : 'Hold a blank wristband to the phone',
          textAlign: TextAlign.center,
          style: t.typography.title3.copyWith(color: c.text),
        ),
        SizedBox(height: t.space.xxs + 2),
        Text(
          'Only the patient ID is written. Tags that already hold an ID are '
          'never overwritten.',
          textAlign: TextAlign.center,
          style: t.typography.subhead.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: t.space.lg),
      ],
    );
  }

  Widget _verifyStep(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final ok = c.status(PatientStatus.readyForDischarge);
    final p = _patient!;
    Widget row(String k, Widget v, {bool last = false}) => Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm + 2,
        vertical: t.space.sm,
      ),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: t.space.xs,
        children: [
          Text(k, style: t.typography.subhead.copyWith(color: c.textSecondary)),
          v,
        ],
      ),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        t.space.xl,
        t.space.gutter,
        t.space.md,
      ),
      children: [
        Semantics(
          liveRegion: true,
          label: 'Wristband ready. Read back and matched.',
          excludeSemantics: true,
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: ok.bg, shape: BoxShape.circle),
                child: Icon(WlIcons.check, size: 40, color: ok.fg),
              ),
              SizedBox(height: t.space.sm),
              Text(
                'Wristband ready',
                style: t.typography.title2.copyWith(color: c.text),
              ),
              SizedBox(height: t.space.xxs),
              Text(
                'Read back and matched.',
                style: t.typography.callout.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.space.md + 4),
        DashCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(
                'Patient',
                Text(
                  p.fullName,
                  style: t.typography.subhead.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              row(
                'Written',
                Text(
                  p.code,
                  style: t.typography.id.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              row(
                'Read back',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.code,
                      style: t.typography.id.copyWith(
                        color: ok.fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: t.space.xxs),
                    Icon(WlIcons.check, size: 16, color: ok.fg),
                  ],
                ),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      label: '${patient.fullName}, ${patient.code}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.space.action),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.sm + 2,
              vertical: t.space.xs,
            ),
            child: Row(
              children: [
                WlInitialsAvatar.patient(patient.fullName, size: 32),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${patient.fullName}, ${patient.age}',
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
                Icon(WlIcons.chevronRight, size: 18, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two rings expanding from the tag icon (3s loop, offset 1.5s). Reduced
/// motion: static faint rings. Stops on dispose.
class _Rings extends StatefulWidget {
  const _Rings();

  @override
  State<_Rings> createState() => _RingsState();
}

class _RingsState extends State<_Rings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WlMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return ExcludeSemantics(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _RingPainter(
                  color: c.primary,
                  value: _c.isAnimating ? _c.value : null,
                ),
              ),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: Icon(WlIcons.nfc, size: 40, color: c.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.value});

  final Color color;
  final double? value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = math.min(110.0, size.shortestSide / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (value == null) {
      for (final (scale, alpha) in [(0.55, 0.18), (0.8, 0.12)]) {
        canvas.drawCircle(
          center,
          maxR * scale,
          paint..color = color.withValues(alpha: alpha),
        );
      }
      return;
    }
    for (final offset in [0.0, 0.5]) {
      final v = (value! + offset) % 1;
      final eased = Curves.easeOutCubic.transform(v);
      canvas.drawCircle(
        center,
        maxR * (0.45 + 0.55 * eased),
        paint..color = color.withValues(alpha: 0.55 * (1 - eased)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
