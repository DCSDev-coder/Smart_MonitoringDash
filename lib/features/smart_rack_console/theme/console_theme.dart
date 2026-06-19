import 'package:flutter/material.dart';

class ConsoleTheme {
  ConsoleTheme._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

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
      isDark(context) ? const Color(0xFF03142E) : const Color(0xFFF4F8FD);

  static Color panelBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF071B3A) : const Color(0xFFFFFFFF);

  static Color cardBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0A2348) : const Color(0xFFFFFFFF);

  static Color innerSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF091A35) : const Color(0xFFF7FAFE);

  static Color softBlueSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF071B3A) : const Color(0xFFEAF3FF);

  // ─── Accent Colors ─────────────────────────────────────────────────────────
  static Color primaryBlue(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E90FF) : const Color(0xFF2F80FF);

  static Color cyan(BuildContext context) =>
      isDark(context) ? const Color(0xFF26D7FF) : const Color(0xFF22C7F2);

  static Color tealGlow(BuildContext context) =>
      isDark(context) ? const Color(0xFF18D2C3) : const Color(0xFF16C7B7);

  static Color electricBlue(BuildContext context) =>
      isDark(context) ? const Color(0xFF4BB8FF) : const Color(0xFF5DA9FF);

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
      isDark(context) ? const Color(0xFFF4F8FF) : const Color(0xFF183153);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFC7D8F5) : const Color(0xFF355072);

  static Color textTertiary(BuildContext context) =>
      isDark(context) ? const Color(0xFF8EA6C9) : const Color(0xFF5B7696);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF6D83A7) : const Color(0xFF7E94AE);

  static Color textInverse(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);

  // ─── Borders and Divider Colors ───────────────────────────────────────────
  static Color cardBorder(BuildContext context) => isDark(context)
      ? const Color(0x384E88FF) // rgba(78, 136, 255, 0.22)
      : const Color(0x244E88FF); // rgba(78, 136, 255, 0.14)

  static Color divider(BuildContext context) => isDark(context)
      ? const Color(0x1F96BEFF) // rgba(150, 190, 255, 0.12)
      : const Color(0x1F5678AA); // rgba(86, 120, 170, 0.12)

  static Color strongDivider(BuildContext context) => isDark(context)
      ? const Color(0x47508CFF) // rgba(80, 140, 255, 0.28)
      : const Color(0x333764B4); // rgba(55, 100, 180, 0.20)

  // ─── Gradients ─────────────────────────────────────────────────────────────
  static Gradient pageBgGradient(BuildContext context) {
    return isDark(context)
        ? const LinearGradient(
            colors: [Color(0xFF071B3A), Color(0xFF05152D)],
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
            colors: [Color(0xFF0A2348), Color(0xFF071B3A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
  }

  static Gradient activeAccentGradient(BuildContext context) {
    final glow = tealGlow(context);
    return LinearGradient(
      colors: [glow.withValues(alpha: 0.35), glow.withValues(alpha: 0.0)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  // ─── Glow & Shadows ────────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(BuildContext context, {Color? color}) {
    if (isDark(context)) {
      return [
        BoxShadow(
          color: (color ?? const Color(0xFF26D7FF)).withValues(alpha: 0.18),
          blurRadius: 18,
          spreadRadius: 0,
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
