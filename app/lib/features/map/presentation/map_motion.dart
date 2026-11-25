// Map animation timings from design/handoff/motion.md that have no WlMotion
// token yet (map dot movement, route draw, arrival ring). Everything else
// uses WlTokens.motion. Reduced motion fallbacks live in the widgets.
// Candidate for WlMotionTokens (shared file) — see the PR notes.

abstract final class MapMotion {
  /// "Map dot movement": dot travels A→B once per event.
  static const Duration dotTravel = Duration(milliseconds: 2600);

  /// "then 2s ring on B" (also the reduced-motion highlight).
  static const Duration arrivalRing = Duration(milliseconds: 2000);

  /// "Route draw": polyline dash offset → 0.
  static const Duration routeDraw = Duration(milliseconds: 900);

  /// "stops pop in order": +80ms each.
  static const Duration stopStagger = Duration(milliseconds: 80);

  /// At most this many live dots at once; older ones are dropped.
  static const int maxMovements = 3;
}
