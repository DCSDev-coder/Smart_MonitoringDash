import 'dart:ui';
import 'package:flutter/material.dart';

class StickyHeaderBar extends StatelessWidget {
  final bool glass;
  final double height;
  final double topPad;
  final double contentHeight;
  final double topPadding;
  final double bottomPadding;
  final Widget child;

  const StickyHeaderBar({
    super.key,
    required this.glass,
    required this.height,
    required this.topPad,
    required this.contentHeight,
    required this.topPadding,
    required this.bottomPadding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: glass ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, tRaw, _) {
        final t = tRaw.clamp(0.0, 1.0);

        Color bgColor;
        List<BoxShadow>? shadows;
        BorderSide bottomBorder;

        if (isLight) {
          // Light mode: lightly tint with the same scaffold background color so the
          // header reads like the exact same surface as the dashboard (blur alone
          // can shift the perceived color).
          bgColor = theme.scaffoldBackgroundColor.withValues(alpha: 0.10);
          // No shadow/border in light mode; both slightly darken the blue background
          // and make the header look like a different colored strip.
          shadows = null;
          bottomBorder = BorderSide.none;
        } else {
          bgColor = const Color(0xFF060B11).withValues(alpha: 0.75);
          bottomBorder = BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          );
          if (t > 0) {
            shadows = [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3 * t),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ];
          }
        }

        return ClipRect(
          child: BackdropFilter(
            // Keep blur subtle so it reads "clear" instead of foggy.
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(bottom: bottomBorder),
                boxShadow: shadows,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  topPad + topPadding,
                  16,
                  bottomPadding,
                ),
                child: SizedBox(
                  height: contentHeight,
                  width: double.infinity,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
