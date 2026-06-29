import 'package:flutter/material.dart';

class HeaderRefreshBar extends StatelessWidget {
  const HeaderRefreshBar({
    super.key,
    required this.visible,
    required this.top,
    required this.horizontalInset,
  });

  final bool visible;
  final double top;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final barColor = theme.colorScheme.primary;
    final trackColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);

    return Positioned(
      left: horizontalInset,
      right: horizontalInset,
      top: top,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 160),
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, -0.2),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: trackColor,
                color: barColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
