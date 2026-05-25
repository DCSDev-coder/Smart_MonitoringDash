import 'package:flutter/material.dart';

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
    // We completely ignore legacy glass tints and borders to enforce 
    // the new unified solid Card style globally.
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
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
