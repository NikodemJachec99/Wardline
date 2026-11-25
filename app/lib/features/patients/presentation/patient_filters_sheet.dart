import 'package:flutter/material.dart';

import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import 'patient_list_model.dart';

/// Filters sheet (artboard `PatientsList` 6 "Advanced filters"): age range,
/// departments, statuses; "Show N patients" counts live. Returns the new
/// filter, or null when dismissed.
Future<PatientFilter?> showPatientFiltersSheet(
  BuildContext context, {
  required HospitalSnapshot snapshot,
  required PatientFilter initial,
  required String query,
}) {
  return showWlBottomSheet<PatientFilter>(
    context: context,
    builder: (context) =>
        PatientFiltersSheet(snapshot: snapshot, initial: initial, query: query),
  );
}

class PatientFiltersSheet extends StatefulWidget {
  const PatientFiltersSheet({
    required this.snapshot,
    required this.initial,
    required this.query,
    super.key,
  });

  final HospitalSnapshot snapshot;
  final PatientFilter initial;
  final String query;

  @override
  State<PatientFiltersSheet> createState() => _PatientFiltersSheetState();
}

class _PatientFiltersSheetState extends State<PatientFiltersSheet> {
  late PatientFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final count = visiblePatients(widget.snapshot, _draft, widget.query).length;

    Widget section(String title, Widget child, {String? value}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  style: t.typography.overline.copyWith(color: c.textSecondary),
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: t.typography
                    .tabular(t.typography.subhead)
                    .copyWith(color: c.text, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        SizedBox(height: t.space.xxs),
        child,
      ],
    );

    Widget chipWrap(List<WlFilterChipData> chips) => Wrap(
      spacing: t.space.xs,
      children: [
        for (final chip in chips)
          WlFilterChips(chips: [chip], padding: EdgeInsets.zero),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Filters',
                  style: t.typography.title2.copyWith(color: c.text),
                ),
              ),
            ),
            WlButton(
              label: 'Reset',
              variant: WlButtonVariant.text,
              dense: true,
              fullWidth: false,
              onPressed: () => setState(() => _draft = const PatientFilter()),
            ),
          ],
        ),
        SizedBox(height: t.space.xs),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section(
                  'Age',
                  value: '${_draft.minAge} – ${_draft.maxAge}',
                  RangeSlider(
                    min: kAgeMin.toDouble(),
                    max: kAgeMax.toDouble(),
                    divisions: kAgeMax - kAgeMin,
                    activeColor: c.primaryInk,
                    inactiveColor: c.border,
                    values: RangeValues(
                      _draft.minAge.toDouble(),
                      _draft.maxAge.toDouble(),
                    ),
                    semanticFormatterCallback: (v) => '${v.round()} years',
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(
                        minAge: v.start.round(),
                        maxAge: v.end.round(),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: t.space.md),
                section(
                  'Department',
                  chipWrap([
                    for (final d in widget.snapshot.departments)
                      WlFilterChipData(
                        label: d.code,
                        selected: _draft.departments.contains(d.code),
                        onTap: () => setState(
                          () => _draft = _draft.toggleDepartment(d.code),
                        ),
                      ),
                  ]),
                ),
                SizedBox(height: t.space.md),
                section(
                  'Status',
                  chipWrap([
                    for (final s in PatientStatus.values)
                      WlFilterChipData(
                        label: WlStatusLabels.of(s),
                        selected: _draft.statuses.contains(s),
                        onTap: () =>
                            setState(() => _draft = _draft.toggleStatus(s)),
                      ),
                  ]),
                ),
                SizedBox(height: t.space.lg),
              ],
            ),
          ),
        ),
        WlButton(
          label: count == 1 ? 'Show 1 patient' : 'Show $count patients',
          onPressed: () => Navigator.of(context).pop(_draft),
        ),
      ],
    );
  }
}
