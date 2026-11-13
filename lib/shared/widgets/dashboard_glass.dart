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
            : const Color(0xFF131D2A));

    final effectiveBorder =
        borderColor ?? (isLight ? AppTheme.lightStroke : const Color(0xFF1E2D3D));

    final bool isDarkCustomTint = !isLight &&
        tint != null &&
        tint != const Color(0xFF111922) &&
        tint != const Color(0xFF131D2A);

    final Gradient? gradient = (!isLight && !isDarkCustomTint)
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF131D2A), Color(0xFF0C131D)],
          )
        : null;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient != null ? null : effectiveTint,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isLight
              ? effectiveBorder
              : (borderColor == Colors.transparent
                  ? const Color(0xFF1E2D3D)
                  : effectiveBorder),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.25),
            blurRadius: isLight ? 12 : 16,
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
