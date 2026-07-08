import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DashboardGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color? tint;
  final Color? borderColor;

  /// When true, and the current theme is light, the glass surface uses the
  /// scaffold background color. This reads better for "cards inside cards"
  /// (avoids stacked white-on-white).
  final bool inset;
  final double? blurSigma; // Kept for backward compatibility but ignored for performance.

  const DashboardGlass({
    super.key,
    required this.child,
    required this.radius,
    required this.padding,
    this.tint,
    // Border defaults are computed from the current theme brightness.
    this.borderColor,
    this.inset = false,
    this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final effectiveTint = tint ??
        (isLight
            ? (inset
                ? theme.scaffoldBackgroundColor
                : theme.colorScheme.surface)
            : const Color(0xFF111922));

    final effectiveBorder =
        borderColor ?? (isLight ? AppTheme.lightStroke : Colors.transparent);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveTint,
        borderRadius: BorderRadius.circular(radius),
        border: isLight || borderColor != null 
            ? Border.all(color: effectiveBorder, width: 1.0)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.25),
            blurRadius: isLight ? 12 : 12,
            offset: Offset(0, isLight ? 4 : 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class DashboardGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double hitSize;
  final double iconSize;

  const DashboardGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.hitSize = 48,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DashboardGlass(
      radius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Icon(
                icon,
                color: isLight ? const Color(0xFF0B0F14) : Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
