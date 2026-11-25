import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import '../application/client_request.dart';

/// Nurse only. Destination sheet with search; current department marked and
/// not selectable. Choosing one closes the sheet and pushes the confirm
/// screen (`Routes.transferConfirm`).
///
/// [identifiedBy] ("NFC", "QR", "Search") travels to the confirm screen as
/// the go_router `extra` of that push; the confirm screen reads it from
/// `GoRouterState.extra` and sends it with the RPC.
///
/// Any other role: nothing opens (the UI never offers the action; RLS and
/// the RPC enforce it again).
Future<void> showChooseDestinationSheet(
  BuildContext context, {
  required Patient patient,
  String? identifiedBy,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(sessionProvider)?.role != UserRole.nurse) return;

  final code = await showWlBottomSheet<String>(
    context: context,
    builder: (context) => _DestinationSheet(patient: patient),
  );
  if (code == null || !context.mounted) return;
  unawaited(
    GoRouter.of(
      context,
    ).push<void>(Routes.transferConfirm(patient.id, code), extra: identifiedBy),
  );
}

class _DestinationSheet extends ConsumerStatefulWidget {
  const _DestinationSheet({required this.patient});

  final Patient patient;

  @override
  ConsumerState<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends ConsumerState<_DestinationSheet> {
  String _query = '';

  void _choose(String code) => Navigator.of(context).pop(code);

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final snap = ref.watch(hospitalProvider);
    final patient = snap.patient(widget.patient.id) ?? widget.patient;
    final current = snap.department(patient.location);
    final q = _query.trim().toLowerCase();

    final rows = <Widget>[];
    if (q.isEmpty) {
      final suggested = _suggestions(snap, patient.location);
      if (suggested.isNotEmpty) {
        rows
          ..add(const _Overline('Suggested'))
          ..add(
            Padding(
              padding: EdgeInsets.only(bottom: t.space.xs),
              child: Wrap(
                spacing: t.space.xs,
                runSpacing: t.space.xs,
                children: [
                  for (final d in suggested)
                    // IntrinsicWidth: WlButton's aligned container would
                    // otherwise take the whole row.
                    IntrinsicWidth(
                      child: WlButton(
                        key: ValueKey('suggested-${d.code}'),
                        label: d.shortName,
                        variant: WlButtonVariant.secondary,
                        dense: true,
                        fullWidth: false,
                        onPressed: () => _choose(d.code),
                      ),
                    ),
                ],
              ),
            ),
          );
      }
      final floors = snap.departments.map((d) => d.floor).toSet().toList()
        ..sort();
      for (final f in floors) {
        rows.add(_Overline(floorName(f)));
        for (final d in snap.departments.where((d) => d.floor == f)) {
          rows.add(
            _DeptRow(
              department: d,
              occupied: snap.occupancy(d.code),
              current: d.code == patient.location,
              onTap: () => _choose(d.code),
            ),
          );
        }
      }
    } else {
      final matches = snap.departments.where((d) {
        return d.name.toLowerCase().contains(q) ||
            d.shortName.toLowerCase().contains(q) ||
            d.code.toLowerCase().contains(q);
      }).toList();
      rows.add(
        _Overline(
          matches.length == 1 ? '1 match' : '${matches.length} matches',
        ),
      );
      for (final d in matches) {
        rows.add(
          _DeptRow(
            department: d,
            occupied: snap.occupancy(d.code),
            current: d.code == patient.location,
            query: q,
            showFloor: true,
            onTap: () => _choose(d.code),
          ),
        );
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: t.space.sm),
          child: Text(
            'Not here? Search by code, e.g. "ICU"',
            textAlign: TextAlign.center,
            style: t.typography.subhead.copyWith(color: c.textSecondary),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Move ${patient.fullName}',
                          style: t.typography.title2.copyWith(color: c.text),
                        ),
                      ),
                      if (current != null)
                        Text(
                          'From ${current.name} · ${floorName(current.floor)}',
                          style: t.typography.subhead.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  constraints: BoxConstraints.tight(
                    Size.square(t.space.touchMin),
                  ),
                  icon: Icon(WlIcons.close, color: c.text),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            SizedBox(height: t.space.sm),
            WlSearchBar(
              hint: 'Search departments',
              semanticsLabel: 'Search departments',
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: t.space.xs),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: rows,
              ),
            ),
          ],
        );
        // Fill the space the sheet gets; it shrinks with the keyboard
        // (WlBottomSheet pads by viewInsets).
        // Like the artboard, a strip of the page stays visible above it.
        final cap = MediaQuery.sizeOf(context).height * 0.9;
        return box.maxHeight.isFinite
            ? SizedBox(height: math.min(box.maxHeight, cap), child: content)
            : content;
      },
    );
  }

  /// Up to three likely next stops: departments patients most often go to
  /// from the current one today, then the busiest destinations overall.
  List<Department> _suggestions(HospitalSnapshot snap, String from) {
    final score = <String, int>{};
    for (final e in snap.events.whereType<LocationEvent>()) {
      if (e.isAdmission || e.to == from) continue;
      score[e.to] = (score[e.to] ?? 0) + (e.from == from ? 3 : 1);
    }
    final candidates =
        snap.departments
            .where((d) => d.code != from && (score[d.code] ?? 0) > 0)
            .toList()
          ..sort((a, b) => (score[b.code]!).compareTo(score[a.code]!));
    if (candidates.length < 3) {
      // Not enough history today: add the wards with the most free beds.
      final rest =
          snap.departments
              .where((d) => d.code != from && !candidates.contains(d))
              .toList()
            ..sort(
              (a, b) => (b.beds - snap.occupancy(b.code)).compareTo(
                a.beds - snap.occupancy(a.code),
              ),
            );
      candidates.addAll(rest.take(3 - candidates.length));
    }
    return candidates.take(3).toList();
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.xxs / 2,
        t.space.sm,
        t.space.xxs / 2,
        t.space.xxs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: t.typography.overline.copyWith(color: t.colors.textSecondary),
        ),
      ),
    );
  }
}

/// One department: name, "RAD · 6/14 beds · 8 free", occupancy % + bar.
/// The patient's current department is marked "Current" and is not a
/// button.
class _DeptRow extends StatelessWidget {
  const _DeptRow({
    required this.department,
    required this.occupied,
    required this.current,
    required this.onTap,
    this.query = '',
    this.showFloor = false,
  });

  final Department department;
  final int occupied;
  final bool current;
  final VoidCallback onTap;
  final String query;
  final bool showFloor;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final d = department;
    final percent = d.beds == 0 ? 0 : (occupied * 100 / d.beds).round();
    final occ = c.occupancy(percent);
    final full = occupied >= d.beds;
    final free = full ? 'Full' : '${d.beds - occupied} free';
    final floor = showFloor ? ' · ${floorShort(d.floor)}' : '';
    final meta = current
        ? '${d.code}$floor · patient is here now'
        : '${d.code}$floor · $occupied/${d.beds} beds · $free';
    final nameStyle = t.typography.callout.copyWith(
      color: current ? c.textSecondary : c.text,
      fontWeight: FontWeight.w600,
    );
    final metaStyle = t.typography
        .tabular(t.typography.caption)
        .copyWith(color: c.textSecondary, fontWeight: FontWeight.w400);

    final trailing = current
        ? Container(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.xs,
              vertical: t.space.xxs / 2,
            ),
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: t.radius.chipBr,
            ),
            child: Text(
              'Current',
              style: t.typography.caption.copyWith(
                color: c.primaryInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: t.typography
                    .tabular(t.typography.subhead)
                    .copyWith(color: c.text, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: t.space.xxs),
              ClipRRect(
                borderRadius: BorderRadius.circular(t.radius.full),
                child: SizedBox(
                  width: t.space.xxl,
                  height: t.space.xxs,
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: c.subtle)),
                      FractionallySizedBox(
                        widthFactor: (percent / 100).clamp(0.0, 1.0),
                        child: ColoredBox(color: occ.fill),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

    final spoken = current
        ? '${d.name}, current location, not selectable'
        : '${d.name}, $occupied of ${d.beds} beds, $percent percent, '
              '${full ? 'full' : occ.word.toLowerCase()}';

    final body = Container(
      constraints: BoxConstraints(minHeight: t.space.action),
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xxs / 2,
        vertical: t.space.xs - 2,
      ),
      decoration: BoxDecoration(
        color: current ? c.page : null,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(_highlight(d.name, query, nameStyle, c)),
                SizedBox(height: t.space.xxs / 2),
                Text.rich(_highlight(meta, query, metaStyle, c, codeOnly: d)),
              ],
            ),
          ),
          SizedBox(width: t.space.sm),
          trailing,
        ],
      ),
    );

    return Semantics(
      key: ValueKey('dest-${d.code}'),
      label: spoken,
      button: !current,
      enabled: !current,
      excludeSemantics: true,
      child: current
          ? body
          : InkWell(onTap: onTap, borderRadius: t.radius.inputBr, child: body),
    );
  }

  /// Marks the matched part of [text] (search "rad" → **Rad**iology).
  /// With [codeOnly], only the department code at the start is marked.
  static InlineSpan _highlight(
    String text,
    String query,
    TextStyle style,
    WlColors c, {
    Department? codeOnly,
  }) {
    if (query.isEmpty) return TextSpan(text: text, style: style);
    final searchIn = codeOnly != null
        ? codeOnly.code.toLowerCase()
        : text.toLowerCase();
    final i = searchIn.indexOf(query);
    if (i < 0) return TextSpan(text: text, style: style);
    final end = i + query.length;
    final mark = style.copyWith(
      color: c.primaryInk,
      backgroundColor: c.primarySoft,
    );
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(text: text.substring(i, end), style: mark),
        TextSpan(text: text.substring(end)),
      ],
    );
  }
}
