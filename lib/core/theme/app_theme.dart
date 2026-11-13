import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Defines the application-wide ThemeData.
/// Colour palette matches the Dashboard.Template.pen design:
///   Background : #0F1C2E  (dark navy)
///   Surface    : #162436  (card navy)
///   Primary    : #00C08B  (accent green)
///   Error/Alarm: #FF4C4C
class AppTheme {
  AppTheme._();

  // ─── Colour tokens ────────────────────────────────────────────────────────
  static const Color bgColor = Colors.black; // Dark navy background
  static const Color surfaceColor = Color(0xFF162436); // Match hardware background
  static const Color cardColor = Color(0xFF131D2A);
  static const Color accentGreen = Color(0xFF00C08B); // Accent green
  static const Color accentBlue = Color(0xFF42A5F5); // Soft blue
  static const Color accentRed = Color(0xFFCE4A4A); // Soft red
  static const Color textPrimary = Colors.white; // White text
  static const Color textSecondary = Colors.white70; // Slightly dim white
  static const Color dividerColor = Color(0xFF2E2E2E); // Darker divider

  // Very light 'ice white' with a hint of blue for a premium background.
  static const Color lightBg = Color(0xFFF4F7FC);
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure white cards
  static const Color lightStroke =
      Color(0x4D7D7D7D); // Grey @ ~30% opacity (0x4D)
  static const Color lightTextPrimary = Color(0xFF0B0F14);
  static const Color lightTextSecondary = Color(0xFF3A3A3A);

  // ─── Aura themed colours (for Deep Server View) ──────────────────────────
  static const Color auraCyan = Color(0xFF00E5FF); // Electric Cyan
  static const Color auraIndigo = Color(0xFF651FFF); // Deep Indigo

  // Alarm level colours (from API response)
  static const Color alarmInfo = Color(0xFF00AFEE);
  static const Color alarmMinor = Color(0xFF90CF5B);
  static const Color alarmMajor = Color(0xFFFF9500);
  static const Color alarmCritical = Color(0xFFF9974C);
  static const Color alarmUrgent = Color(0xFFFF1E02);

  // ─── Status colours ───────────────────────────────────────────────────────
  static const Color statusOk = accentGreen;
  static const Color statusWarn = alarmMajor;
  static const Color statusError = alarmUrgent;

  // ─── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData(
      fontFamily: GoogleFonts.manrope().fontFamily,
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: accentBlue,
        surface: surfaceColor,
        error: alarmUrgent,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 4,
        shadowColor: Colors.black26,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: accentGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            const Color(0xFF1E3046), // Slightly lighter than bg for inputs
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accentGreen, width: 1.5),
        ),
        labelStyle: GoogleFonts.manrope(color: textSecondary),
        hintStyle: GoogleFonts.manrope(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return textSecondary.withValues(alpha: 0.5);
            }
            return accentGreen;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: dividerColor.withValues(alpha: 0.5), width: 1);
            }
            return const BorderSide(color: accentGreen, width: 1.5);
          }),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 1),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black54,
      ),
    );

    final rawTextTheme = TextTheme(
      headlineLarge: GoogleFonts.manrope(
          color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
      headlineMedium: GoogleFonts.manrope(
          color: textPrimary, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: GoogleFonts.manrope(
          color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: GoogleFonts.manrope(
          color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: GoogleFonts.manrope(color: textPrimary, fontSize: 14),
      bodyMedium: GoogleFonts.manrope(
          color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.manrope(
          color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
    );

    return base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).merge(rawTextTheme),
    );
  }

  static ThemeData get light {
    final base = ThemeData(
      fontFamily: GoogleFonts.manrope().fontFamily,
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF164E87),
        secondary: accentBlue,
        surface: lightSurface,
        error: alarmUrgent,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      cardTheme: const CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: Color(0xFF164E87),
        unselectedItemColor: Color(0xFF4A4A4A),
        type: BottomNavigationBarType.fixed,
        elevation: 6,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF164E87), width: 1.5),
        ),
        labelStyle: GoogleFonts.manrope(color: lightTextSecondary),
        hintStyle: GoogleFonts.manrope(color: lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF164E87),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return lightTextSecondary.withValues(alpha: 0.5);
            }
            return const Color(0xFF164E87);
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: lightStroke.withValues(alpha: 0.5), width: 1);
            }
            return const BorderSide(color: Color(0xFF164E87), width: 1.5);
          }),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lightStroke, thickness: 1),
      dialogTheme: const DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black26,
      ),
    );

    final rawTextTheme = TextTheme(
      headlineLarge: GoogleFonts.manrope(
          color: lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 28),
      headlineMedium: GoogleFonts.manrope(
          color: lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22),
      titleLarge: GoogleFonts.manrope(
          color: lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18),
      titleMedium: GoogleFonts.manrope(
          color: lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16),
      bodyLarge: GoogleFonts.manrope(color: lightTextPrimary, fontSize: 14),
      bodyMedium: GoogleFonts.manrope(
          color: lightTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.manrope(
          color: lightTextSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold),
    );

    return base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).merge(rawTextTheme),
    );
  }
}
