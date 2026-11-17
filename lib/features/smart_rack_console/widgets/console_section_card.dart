import 'package:flutter/material.dart';

import '../theme/console_theme.dart';

class ConsoleSectionCard extends StatelessWidget {
  const ConsoleSectionCard({
    super.key,
    this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.minHeight,
    this.padding,
    this.expand = false,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cardBorder = ConsoleTheme.cardBorder(context);
    final textPrimary = ConsoleTheme.textPrimary(context);
    final textSecondary = ConsoleTheme.textSecondary(context);
    final resolvedPadding = padding ??
        EdgeInsets.all(ConsoleTheme.isRackConsoleLite ? 14.0 : 20.0);
    final titleGap = ConsoleTheme.isRackConsoleLite
        ? ConsoleTheme.md
        : ConsoleTheme.lg;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = expand && constraints.hasBoundedHeight;

        return Container(
          constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
          decoration: BoxDecoration(
            gradient: ConsoleTheme.cardBgGradient(context),
            borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
            border: Border.all(color: cardBorder),
            boxShadow: ConsoleTheme.glowShadow(context),
          ),
          child: Padding(
            padding: resolvedPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: canExpand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (title != null && title!.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title!,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: ConsoleTheme.isRackConsoleLite ? 14 : 18,
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
                  SizedBox(height: titleGap),
                ],
                canExpand ? Expanded(child: child) : child,
              ],
            ),
          ),
        );
      },
    );
  }
}
