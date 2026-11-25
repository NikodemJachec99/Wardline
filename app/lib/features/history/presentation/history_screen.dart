import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import 'history_data.dart';
import 'history_widgets.dart';

/// `/history`: every transfer and status change, newest first
/// (HistoryFlow artboard, "History · live").
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const int _pageSize = 40;

  final ScrollController _scroll = ScrollController();
  HistoryKind _kind = HistoryKind.all;
  HistoryRange _range = HistoryRange.today;
  String? _department;
  int _limit = _pageSize;
  int _total = 0;

  /// Newest remote event seen while this screen is alive (live highlight).
  String? _liveId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Next page when the end of the list comes into reach.
  void _maybeLoadMore() {
    if (!_scroll.hasClients || _limit >= _total) return;
    if (_scroll.position.extentAfter < 600) {
      setState(() => _limit += _pageSize);
    }
  }

  void _setFilters({HistoryKind? kind, HistoryRange? range, String? dept}) {
    setState(() {
      _kind = kind ?? _kind;
      _range = range ?? _range;
      _department = dept;
      _limit = _pageSize;
    });
  }

  void _resetFilters() => setState(() {
    _kind = HistoryKind.all;
    _range = HistoryRange.today;
    _department = null;
    _limit = _pageSize;
  });

  bool get _filtered =>
      _kind != HistoryKind.all ||
      _range != HistoryRange.today ||
      _department != null;

  Future<void> _pickDepartment(HospitalSnapshot s) async {
    final picked = await showWlBottomSheet<_Pick<String?>>(
      context: context,
      builder: (context) => _OptionSheet<String?>(
        title: 'Department',
        selected: _department,
        options: [
          (null, 'All departments'),
          for (final d in s.departments) (d.code, d.name),
        ],
      ),
    );
    if (picked != null) {
      _setFilters(dept: picked.value);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showWlBottomSheet<_Pick<HistoryRange>>(
      context: context,
      builder: (context) => _OptionSheet<HistoryRange>(
        title: 'Time',
        selected: _range,
        options: [for (final r in HistoryRange.values) (r, r.label)],
      ),
    );
    if (picked != null) {
      _setFilters(range: picked.value, dept: _department);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(hospitalProvider.select((s) => s.lastRemoteEvent), (_, next) {
      if (next != null) setState(() => _liveId = next.id);
    });
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final now = ref.watch(historyNowProvider)();
    final events = filterHistory(
      s,
      kind: _kind,
      range: _range,
      now: now,
      department: _department,
    );
    _total = events.length;
    final sections = sectionsFor(events, now);

    final slivers = <Widget>[];
    var budget = _limit;
    for (final (i, section) in sections.indexed) {
      if (budget <= 0) break;
      final rows = section.events.take(budget).toList();
      budget -= rows.length;
      final title = i == 0
          ? section.title
          : '${section.title} · ${section.events.length} more';
      slivers
        ..add(SliverToBoxAdapter(child: HistoryGroupLabel(title)))
        ..add(
          HistoryBox(
            sliver: SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (context, _) => const HistoryDivider(),
              itemBuilder: (context, index) =>
                  _row(context, s, rows[index], now),
            ),
          ),
        );
    }

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: WlLargeTitle(
                title: 'History',
                showBack: false,
                trailing: [
                  const HistoryConnectionPill(),
                  IconButton(
                    tooltip: 'Day timeline',
                    icon: Icon(WlIcons.timeline, color: c.text),
                    onPressed: () => context.push(Routes.dayTimeline),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: HistoryConnectionBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.gutter,
                  t.space.xxs,
                  t.space.gutter,
                  0,
                ),
                child: HistorySegmented<HistoryKind>(
                  selected: _kind,
                  onChanged: (k) => _setFilters(kind: k, dept: _department),
                  segments: const [
                    (HistoryKind.all, 'All'),
                    (HistoryKind.transfers, 'Transfers'),
                    (HistoryKind.status, 'Status'),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: WlFilterChips(
                chips: [
                  WlFilterChipData(
                    label: _department == null
                        ? 'All departments'
                        : deptName(s, _department),
                    selected: _department != null,
                    dropdown: true,
                    onTap: () => _pickDepartment(s),
                  ),
                  WlFilterChipData(
                    label: _range.label,
                    selected: _range != HistoryRange.today,
                    dropdown: true,
                    onTap: _pickRange,
                  ),
                ],
              ),
            ),
            if (_department != null)
              SliverToBoxAdapter(
                child: _DepartmentLink(
                  name: s.department(_department!)?.name ?? _department!,
                  onTap: () =>
                      context.push(Routes.departmentHistory(_department!)),
                ),
              ),
            if (s.departments.isEmpty)
              const SliverToBoxAdapter(child: _HistorySkeleton())
            else if (events.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFilter(
                  title: _emptyTitle(s),
                  body: _filtered
                      ? 'Nothing matched these filters.'
                      : 'Transfers and status changes appear here as '
                            'they happen.',
                  onShowAll: _filtered ? _resetFilters : null,
                ),
              )
            else
              ...slivers,
            SliverToBoxAdapter(
              child: SizedBox(
                height: t.space.lg + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyTitle(HospitalSnapshot s) {
    final what = switch (_kind) {
      HistoryKind.all => 'No activity',
      HistoryKind.transfers => 'No transfers',
      HistoryKind.status => 'No status changes',
    };
    final where = _department == null ? '' : ' in ${deptName(s, _department)}';
    return '$what$where ${_range.phrase}';
  }

  Widget _row(
    BuildContext context,
    HospitalSnapshot s,
    HistoryEvent e,
    DateTime now,
  ) {
    final t = WlTokens.of(context);
    final patient = s.patient(e.patientId);
    final role = roleLabel(e.byRole);
    final (String action, String subline) = switch (e) {
      LocationEvent(:final from, :final to) when from == null => (
        'admitted',
        'to ${deptName(s, to)} · $role',
      ),
      LocationEvent(:final from, :final to) => (
        'moved',
        '${deptName(s, from)} → ${deptName(s, to)} · $role',
      ),
      StatusEvent(:final from, :final to) => (
        'updated',
        '${from == null ? '' : '${WlStatusLabels.of(from)} → '}'
            '${WlStatusLabels.of(to)} · $role',
      ),
    };
    final live = e.id == _liveId;
    return Padding(
      key: ValueKey(e.id),
      padding: EdgeInsets.symmetric(horizontal: t.space.sm - t.space.xxs),
      child: WlActivityFeedItem(
        actorName: e.byName,
        actorRole: e.byRole,
        action: action,
        patientName: patient?.fullName ?? 'Unknown patient',
        subline: subline,
        timeAgo: sameDay(e.at, now) ? hm(e.at) : timeAgo(e.at, now),
        live: live,
        highlightKey: live ? e.id : null,
        onTap: patient == null
            ? null
            : () => context.push(Routes.patient(e.patientId)),
      ),
    );
  }
}

/// "Internal Medicine history ›" under the chips once a department is
/// chosen.
class _DepartmentLink extends StatelessWidget {
  const _DepartmentLink({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      label: 'Open $name history',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: t.space.touchMin),
          padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
          child: Row(
            children: [
              Icon(WlIcons.building, size: 18, color: c.primaryInk),
              SizedBox(width: t.space.xs),
              Flexible(
                child: Text(
                  '$name history',
                  style: t.typography.callout.copyWith(
                    color: c.primaryInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(WlIcons.chevronRight, size: 18, color: c.primaryInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.title, required this.body, this.onShowAll});

  final String title;
  final String body;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.only(top: t.space.xxl),
        child: Column(
          children: [
            WlEmptyState(icon: WlIcons.history, title: title, body: body),
            if (onShowAll != null)
              WlButton(
                label: 'Show all activity',
                variant: WlButtonVariant.secondary,
                fullWidth: false,
                dense: true,
                onPressed: onShowAll,
              ),
          ],
        ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return WlSkeletonScope(
      child: Padding(
        padding: EdgeInsets.all(t.space.gutter),
        child: Column(
          children: [
            for (var i = 0; i < 6; i++)
              Padding(
                padding: EdgeInsets.only(bottom: t.space.md),
                child: Row(
                  children: [
                    const WlSkeleton(height: 32, circle: true),
                    SizedBox(width: t.space.sm),
                    const Expanded(child: WlSkeleton(height: 14)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sheet result wrapper, so "All departments" (null) is a real choice.
class _Pick<T> {
  const _Pick(this.value);

  final T value;
}

/// Single-choice list in a bottom sheet (department / time range).
class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<(T, String)> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: t.space.xs),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: t.typography.title3.copyWith(color: c.text),
            ),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (value, label) in options)
                Semantics(
                  button: true,
                  selected: value == selected,
                  inMutuallyExclusiveGroup: true,
                  label: label,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: t.radius.inputBr,
                    onTap: () => Navigator.of(context).pop(_Pick<T>(value)),
                    child: Container(
                      constraints: BoxConstraints(minHeight: t.space.action),
                      padding: EdgeInsets.symmetric(horizontal: t.space.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: t.typography.body.copyWith(
                                color: c.text,
                                fontWeight: value == selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (value == selected)
                            Icon(WlIcons.check, size: 20, color: c.primaryInk),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
