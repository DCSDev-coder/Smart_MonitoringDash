import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';

class ConsoleTheme {
  ConsoleTheme._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static bool get isRackConsoleLite => AppConfig.isRackConsoleBuild;

  static String? get fontFamily => GoogleFonts.manrope().fontFamily;

  static TextStyle font({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.manrope(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ─── Spacing Tokens (8px system) ──────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;

  // ─── Dimensions ────────────────────────────────────────────────────────────
  static const double headerHeight = 76.0;
  static const double sidebarWidth = 140.0;
  static const double cardRadius = 18.0;
  static const double innerRadius = 14.0;

  // ─── Background Colors ─────────────────────────────────────────────────────
  static Color appBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF090E15) : const Color(0xFFF4F8FD);

  static Color panelBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0F1722) : const Color(0xFFFFFFFF);

  static Color cardBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF131D2A) : const Color(0xFFFFFFFF);

  static Color innerSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF0E1622) : const Color(0xFFF7FAFE);

  static Color softBlueSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF152232) : const Color(0xFFEAF3FF);

  // ─── Accent Colors ─────────────────────────────────────────────────────────
  static Color primaryBlue(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E90FF) : const Color(0xFF2F80FF);

  static Color cyan(BuildContext context) =>
      isDark(context) ? const Color(0xFF26D7FF) : const Color(0xFF22C7F2);

  static Color tealGlow(BuildContext context) =>
      isDark(context) ? const Color(0xFF18D2C3) : const Color(0xFF16C7B7);

  static Color electricBlue(BuildContext context) =>
      isDark(context) ? const Color(0xFF4BB8FF) : const Color(0xFF5DA9FF);

  static Color purple(BuildContext context) =>
      isDark(context) ? const Color(0xFFC77DFF) : const Color(0xFF9C27B0);

  // ─── Status Colors ─────────────────────────────────────────────────────────
  static Color success(BuildContext context) =>
      isDark(context) ? const Color(0xFF21E38A) : const Color(0xFF14B86A);

  static Color warning(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFC857) : const Color(0xFFF5A623);

  static Color danger(BuildContext context) =>
      isDark(context) ? const Color(0xFFFF5C7A) : const Color(0xFFE94B68);

  static Color neutral(BuildContext context) =>
      isDark(context) ? const Color(0xFF7D93B2) : const Color(0xFF7F8FA8);

  // ─── Text Colors ───────────────────────────────────────────────────────────
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF8F9FA) : const Color(0xFF183153);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFB0B5BF) : const Color(0xFF355072);

  static Color textTertiary(BuildContext context) =>
      isDark(context) ? const Color(0xFF808691) : const Color(0xFF5B7696);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF606670) : const Color(0xFF7E94AE);

  static Color textInverse(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);

  // ─── Borders and Divider Colors ───────────────────────────────────────────
  static Color cardBorder(BuildContext context) => isDark(context)
      ? const Color(0xFF1E2D3D)
      : const Color(0x244E88FF); // rgba(78, 136, 255, 0.14)

  static Color divider(BuildContext context) => isDark(context)
      ? const Color(0xFF1E2D3D)
      : const Color(0x1F5678AA); // rgba(86, 120, 170, 0.12)

  static Color strongDivider(BuildContext context) => isDark(context)
      ? const Color(0xFF283B4F)
      : const Color(0x333764B4); // rgba(55, 100, 180, 0.20)

  // ─── Gradients ─────────────────────────────────────────────────────────────
  static Gradient pageBgGradient(BuildContext context) {
    return isDark(context)
        ? const LinearGradient(
            colors: [Color(0xFF090E15), Color(0xFF060B11)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFF7FBFF), Color(0xFFEEF4FB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
  }

  static Gradient cardBgGradient(BuildContext context) {
    return isDark(context)
        ? const LinearGradient(
            colors: [Color(0xFF131D2A), Color(0xFF0C131D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
  }

  static Gradient activeAccentGradient(BuildContext context) {
    final glow = tealGlow(context);
    final alpha = isRackConsoleLite ? 0.18 : 0.35;
    return LinearGradient(
      colors: [glow.withValues(alpha: alpha), glow.withValues(alpha: 0.0)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  // ─── Glow & Shadows ────────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(BuildContext context, {Color? color}) {
    if (isRackConsoleLite) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }
    if (isDark(context)) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: (color ?? const Color(0xFF2F80FF)).withValues(alpha: 0.10),
          blurRadius: 14,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0xFF1F4D8C).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
    }
  }
}
