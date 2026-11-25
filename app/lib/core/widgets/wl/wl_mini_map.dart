import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../features/map/presentation/map_data.dart';
import '../../../features/map/presentation/map_geometry.dart';
import '../../../features/map/presentation/map_painter.dart';
import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

/// One floor in isometric view (MapStates "Mini map in the profile"):
/// departments tinted by occupancy, the highlighted department with a 3dp
/// `primary` ring (others dimmed), a patient pin with initials. Tappable →
/// full map focused on that floor.
///
/// Reads the department geometry and live counts from [hospitalProvider]
/// (read-only). Outside a ProviderScope it shows an empty floor frame.
class WlMiniMap extends StatelessWidget {
  const WlMiniMap({
    required this.floor,
    this.highlightDepartment,
    this.patientInitials,
    this.onTap,
    super.key,
  });

  final int floor;
  final String? highlightDepartment;
  final String? patientInitials;
  final VoidCallback? onTap;

  static const double _height = 170;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final hasScope =
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
        null;

    Widget map(String? highlightName) {
      final label = [
        'Map of ${floorTitle(floor)}',
        if (highlightName != null) '$highlightName highlighted',
        if (patientInitials != null && highlightName != null) 'patient is here',
      ].join(', ');
      final frame = Container(
        height: _height,
        decoration: BoxDecoration(
          color: c.subtle,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (!hasScope)
              Center(child: Icon(WlIcons.map, color: c.textSecondary))
            else
              Positioned.fill(child: _MiniMapBody(this)),
            Positioned(
              left: t.space.sm - 2,
              top: t.space.sm - 2,
              child: Container(
                height: t.space.lg,
                padding: EdgeInsets.symmetric(horizontal: t.space.xs),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(t.radius.chip - 2),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  floorTitle(floor),
                  style: t.typography.overline.copyWith(
                    letterSpacing: 0,
                    color: c.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return Semantics(
        container: true,
        button: onTap != null,
        label: onTap != null ? '$label. Open map' : label,
        excludeSemantics: true,
        child: onTap == null
            ? frame
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: frame,
              ),
      );
    }

    if (!hasScope) return map(highlightDepartment);
    return Consumer(
      builder: (context, ref, _) {
        final name = ref.watch(
          hospitalProvider.select(
            (s) => highlightDepartment == null
                ? null
                : s.department(highlightDepartment!)?.name,
          ),
        );
        return map(name ?? highlightDepartment);
      },
    );
  }
}

class _MiniMapBody extends ConsumerWidget {
  const _MiniMapBody(this.widget);

  final WlMiniMap widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = WlTokens.of(context);
    final s = ref.watch(hospitalProvider);
    final occ = {for (final d in s.departments) d.code: occupancyOf(s, d)};
    return LayoutBuilder(
      builder: (context, box) {
        final projection = MapProjection.fit(
          mode: MapMode.iso,
          floors: [widget.floor],
          size: Size(box.maxWidth, box.maxHeight),
          padding: EdgeInsets.fromLTRB(
            t.space.md,
            t.space.md,
            t.space.md,
            t.space.sm,
          ),
        );
        final scene = MapScene.build(
          projection: projection,
          departments: s.departments,
        );
        final pinAt = widget.highlightDepartment == null
            ? null
            : scene.department(widget.highlightDepartment!)?.center;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: HospitalMapPainter(
                  scene: scene,
                  colors: t.colors,
                  occupancy: occ,
                  focus: widget.highlightDepartment,
                  ring: widget.highlightDepartment,
                ),
              ),
            ),
            if (pinAt != null && widget.patientInitials != null)
              Positioned(
                left: pinAt.dx,
                top: pinAt.dy - t.space.xxs,
                child: FractionalTranslation(
                  translation: const Offset(-.5, -1),
                  child: _Pin(initials: widget.patientInitials!),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Patient pin: initials in a `primaryInk` circle with a white ring.
class _Pin extends StatelessWidget {
  const _Pin({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primaryInk,
            shape: BoxShape.circle,
            border: Border.all(color: c.surface, width: 3),
            boxShadow: t.elevation.e2,
          ),
          child: Text(
            initials,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: t.typography.overline.copyWith(
              fontSize: 10,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
              color: c.onPrimary,
              height: 1,
            ),
          ),
        ),
        Container(width: 2, height: t.space.xs, color: c.primaryInk),
      ],
    );
  }
}
