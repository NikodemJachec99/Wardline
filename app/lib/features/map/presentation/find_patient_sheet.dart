import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';

/// "Find a patient on the map" (MapStates "Patient list pinned to the
/// map"): search by name, ID or department; picking a patient pops the
/// sheet with the patient id, and the map opens the route view.
class FindPatientSheet extends ConsumerStatefulWidget {
  const FindPatientSheet({super.key});

  @override
  ConsumerState<FindPatientSheet> createState() => _FindPatientSheetState();
}

class _FindPatientSheetState extends ConsumerState<FindPatientSheet> {
  String _query = '';
  static const int _limit = 30;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final q = _query.trim().toLowerCase();
    String deptName(String code) => s.department(code)?.shortName ?? code;
    final all = s.patients
        .where((p) => p.status != PatientStatus.discharged)
        .toList();
    final matches = q.isEmpty
        ? all
        : all
              .where(
                (p) =>
                    p.fullName.toLowerCase().contains(q) ||
                    p.code.toLowerCase().contains(q) ||
                    p.location.toLowerCase() == q ||
                    deptName(p.location).toLowerCase().contains(q),
              )
              .toList();
    final shown = matches.take(_limit).toList();
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.xs,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: t.space.xs,
            children: [
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    text: 'Patients ',
                    children: [
                      TextSpan(
                        text: '· ${all.length} in house',
                        style: t.typography
                            .tabular(t.typography.callout)
                            .copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                  style: t.typography.title3.copyWith(
                    fontSize: 17,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          WlSearchBar(
            hint: 'Find a patient on the map',
            semanticsLabel: 'Find a patient on the map',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: shown.isEmpty
                ? WlEmptyState(
                    icon: WlIcons.search,
                    title: 'No patients match "$_query"',
                    body: 'Check the spelling, or search by patient ID, e.g. HPT-7K3M9QX2.',
                  )
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final p = shown[i];
                      final st = c.status(p.status);
                      return Semantics(
                        button: true,
                        label:
                            '${p.fullName}, ${deptName(p.location)}, ${st.label}. Show route today',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(p.id),
                          child: Container(
                            constraints: BoxConstraints(
                              minHeight: t.space.action - t.space.xxs,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: t.space.sm - 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: c.border),
                              ),
                            ),
                            child: Row(
                              spacing: t.space.sm - 2,
                              children: [
                                Container(
                                  width: t.space.xxs,
                                  height: t.space.lg,
                                  decoration: BoxDecoration(
                                    color: st.base,
                                    borderRadius: BorderRadius.circular(
                                      t.space.xxs / 2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    p.fullName,
                                    style: t.typography.callout.copyWith(
                                      color: c.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  deptName(p.location),
                                  style: t.typography.caption.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
