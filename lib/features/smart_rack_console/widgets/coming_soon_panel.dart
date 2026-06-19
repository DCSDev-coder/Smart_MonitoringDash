import 'package:flutter/material.dart';
import '../theme/console_theme.dart';

class ComingSoonPanel extends StatelessWidget {
  const ComingSoonPanel({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final primaryColor = ConsoleTheme.primaryBlue(context);
    final textColor = ConsoleTheme.textPrimary(context);
    final secondaryTextColor = ConsoleTheme.textSecondary(context);
    final cardBg = ConsoleTheme.cardBg(context);
    final border = ConsoleTheme.cardBorder(context);

    return Container(
      decoration: BoxDecoration(
        gradient: ConsoleTheme.pageBgGradient(context),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(ConsoleTheme.xl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(ConsoleTheme.xxl),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
          border: Border.all(color: border),
          boxShadow: ConsoleTheme.glowShadow(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.construction_rounded,
                color: primaryColor,
                size: 38,
              ),
            ),
            const SizedBox(height: ConsoleTheme.xl),
            Text(
              '$title Module',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ConsoleTheme.md),
            Text(
              'This section is currently under development as part of the phase-by-phase implementation plan.',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ConsoleTheme.xl),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ConsoleTheme.lg,
                vertical: ConsoleTheme.sm,
              ),
              decoration: BoxDecoration(
                color: ConsoleTheme.innerSurface(context),
                borderRadius: BorderRadius.circular(ConsoleTheme.innerRadius),
                border: Border.all(
                  color: ConsoleTheme.divider(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ConsoleTheme.warning(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: ConsoleTheme.sm),
                  Text(
                    'Operational Planning Phase',
                    style: TextStyle(
                      color: ConsoleTheme.textSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
