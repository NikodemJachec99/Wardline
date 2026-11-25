import '../../../core/theme/wl_tokens.dart';

/// Map animation timings (design/handoff/motion.md). Values live in
/// [WlMotionTokens]; this only names them for the map code.
abstract final class MapMotion {
  static WlMotionTokens get _m => WlTokens.light.motion;

  /// "Map dot movement": dot travels A→B once per event.
  static Duration get dotTravel => _m.mapDotTravel;

  /// "then 2s ring on B" (also the reduced-motion highlight).
  static Duration get arrivalRing => _m.mapArrivalRing;

  /// "Route draw": polyline dash offset → 0.
  static Duration get routeDraw => _m.routeDraw;

  /// "stops pop in order": +80ms each.
  static Duration get stopStagger => _m.routeStopStagger;

  /// At most this many live dots at once; older ones are dropped.
  static const int maxMovements = 3;
}
