import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'dashboard_glass.dart';
import '../../features/dashboard/widgets/dashboard_typography.dart';

Future<bool?> showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = 'Cancel',
  required String confirmText,
  Color? confirmColor,
  Color? confirmGlow,
}) {
  final screenW = MediaQuery.of(context).size.width;
  final maxW = (screenW - 32).clamp(280.0, 380.0);
  final isLight = Theme.of(context).brightness == Brightness.light;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, __, ___) {
      final okColor = confirmColor ?? AppTheme.statusError;
      final glow = confirmGlow ?? okColor;

      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: DashboardGlass(
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    tint: isLight ? Colors.white : const Color(0xFF070B10),
                    borderColor: isLight
                        ? AppTheme.lightStroke
                        : Colors.white.withValues(alpha: 0.10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: bitcount(
                            context,
                            fontSize: 18,
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextSecondary
                                : AppTheme.textSecondary,
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, c) {
                            final stack = c.maxWidth < 320;

                            Widget cancelBtn = SizedBox(
                              height: 42,
                              width: stack ? double.infinity : null,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLight
                                      ? const Color(0xFFF1F2F5)
                                      : Colors.white.withValues(alpha: 0.10),
                                  foregroundColor: isLight
                                      ? AppTheme.lightTextPrimary
                                      : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isLight
                                          ? const Color(0xFFD5DAE2)
                                          : Colors.white
                                              .withValues(alpha: 0.10),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  cancelText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            );

                            Widget confirmBtn = SizedBox(
                              height: 42,
                              width: stack ? double.infinity : null,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: okColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  confirmText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            );

                            if (stack) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  confirmBtn,
                                  const SizedBox(height: 10),
                                  cancelBtn,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: cancelBtn),
                                const SizedBox(width: 12),
                                Expanded(child: confirmBtn),
                              ],
                            );
                          },
                        ),
	                      ],
	                    ),
	                  ),
	                ),
	              ),
	            ),
	          ),
	        ),
	      );
	    },
	    transitionBuilder: (ctx, anim, __, child) {
	      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
	      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
