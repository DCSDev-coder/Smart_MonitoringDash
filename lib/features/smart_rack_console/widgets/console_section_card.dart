import 'package:flutter/material.dart';

import '../theme/console_theme.dart';

class ConsoleSectionCard extends StatelessWidget {
  const ConsoleSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.minHeight,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cardBorder = ConsoleTheme.cardBorder(context);
    final textPrimary = ConsoleTheme.textPrimary(context);
    final textSecondary = ConsoleTheme.textSecondary(context);

    return Container(
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      decoration: BoxDecoration(
        gradient: ConsoleTheme.cardBgGradient(context),
        borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
        border: Border.all(color: cardBorder),
        boxShadow: ConsoleTheme.glowShadow(context),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20.0), // 20px - 24px padding matching design guidelines
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
