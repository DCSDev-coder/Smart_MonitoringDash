import 'package:flutter/material.dart';

/// A lightweight, smooth, seamless looping gradient fill.
///
/// Uses `TileMode.repeated` + a translating `GradientTransform` so the gradient
/// can "move" forever without the visible snap you get when restarting a tween.
class AnimatedGradientFill extends StatelessWidget {
  final Animation<double> t; // 0..1 repeating
  final BorderRadius borderRadius;
  final List<Color> colors;
  final Color? fallbackColor;
  final List<BoxShadow>? boxShadow;

  const AnimatedGradientFill({
    super.key,
    required this.t,
    required this.borderRadius,
    required this.colors,
    this.fallbackColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: borderRadius,
        gradient: fallbackColor != null
            ? null
            : LinearGradient(
                colors: colors,
                tileMode: TileMode.repeated,
                transform: _SlidingGradientTransform(t.value),
              ),
        boxShadow: boxShadow,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  // 0..1
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // Translate by 0..1 * width. With TileMode.repeated, shifting by a full
    // width lands on the same pixels, so looping is seamless.
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

