import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

/// Lightweight skeleton placeholder (no shimmer, just a soft pulse).
///
/// We keep this dependency-free and subtle to match the dark UI.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? margin;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.margin,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final a = lerpDouble(
              isLight ? 0.06 : 0.10,
              isLight ? 0.12 : 0.18,
              _t.value,
            ) ??
            (isLight ? 0.09 : 0.14);
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: isLight
                ? Colors.black.withValues(alpha: a)
                : Colors.white.withValues(alpha: a),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}
