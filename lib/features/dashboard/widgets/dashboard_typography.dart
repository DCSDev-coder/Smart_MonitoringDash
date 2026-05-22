import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// This helper was originally used for a dot-matrix / "IT vibe" look.
// We keep the function name to avoid a huge refactor, but the styling is now
// enterprise-friendly (clean sans-serif).
TextStyle bitcount(
  BuildContext context, {
  required double fontSize,
  required Color color,
  double letterSpacing = 0,
  FontWeight fontWeight = FontWeight.w600,
  List<Shadow>? shadows,
}) {
  // Respect device accessibility setting for bold text
  final isBoldText = MediaQuery.boldTextOf(context);
  final actualWeight = isBoldText 
      ? FontWeight.values.firstWhere((w) => w.value == (fontWeight.value + 200).clamp(100, 900), orElse: () => fontWeight)
      : fontWeight;

  final base = TextStyle(
    fontSize: fontSize,
    color: color,
    fontWeight: actualWeight,
    letterSpacing: letterSpacing,
    shadows: shadows,
    height: 1.1,
  );

  return GoogleFonts.manrope(textStyle: base);
}
