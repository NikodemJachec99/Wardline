import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';

/// Grey block shaped like real content. Wrap a group in [WlSkeletonScope]
/// for the shimmer and the 300ms show delay.
class WlSkeleton extends StatelessWidget {
  const WlSkeleton({
    this.width,
    this.height = 16,
    this.radius,
    this.circle = false,
    super.key,
  });

  final double? width;
  final double height;
  final double? radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: t.colors.subtle,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : BorderRadius.circular(radius ?? t.radius.chip / 2),
      ),
    );
  }
}

/// Shows [child] (skeleton blocks) only after 300ms, with a 1.2s shimmer.
/// Reduced motion: static blocks.
class WlSkeletonScope extends StatefulWidget {
  const WlSkeletonScope({required this.child, super.key});

  final Widget child;

  @override
  State<WlSkeletonScope> createState() => _WlSkeletonScopeState();
}

class _WlSkeletonScopeState extends State<WlSkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _visible = true);
      if (!WlMotion.reduced(context)) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final t = WlTokens.of(context);
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (context, child) {
            if (!_c.isAnimating) return child!;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) {
                final dx = -200 + 400 * _c.value;
                return LinearGradient(
                  colors: [t.colors.subtle, t.colors.surface, t.colors.subtle],
                  stops: const [0.35, 0.5, 0.65],
                  transform: _Slide(dx),
                ).createShader(rect);
              },
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
