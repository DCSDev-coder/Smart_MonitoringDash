import 'package:flutter/material.dart';

import '../theme/console_theme.dart';

class ConsoleMetricCard extends StatelessWidget {
  const ConsoleMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtext,
    this.accentColor,
  });

  final String label;
  final String value;
  final String? subtext;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final activeAccent = accentColor ?? ConsoleTheme.primaryBlue(context);
    final cardBg = ConsoleTheme.cardBg(context);
    final cardBorder = ConsoleTheme.cardBorder(context);
    final textSecondary = ConsoleTheme.textSecondary(context);
    final textPrimary = ConsoleTheme.textPrimary(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        gradient: ConsoleTheme.cardBgGradient(context),
        borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
        border: Border.all(color: cardBorder),
        boxShadow: ConsoleTheme.glowShadow(context),
      ),
      padding: const EdgeInsets.all(ConsoleTheme.lg),
      child: Row(
        children: [
          // Left Icon with dynamic accent circle background
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeAccent.withValues(alpha: 0.15),
              border: Border.all(
                color: activeAccent.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: activeAccent, size: 20),
          ),
          const SizedBox(width: ConsoleTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtext!,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
