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
  final base = TextStyle(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    shadows: shadows,
    height: 1.1,
  );

  // Manrope reads well on mobile + desktop and feels neutral/corporate.
  return GoogleFonts.manrope(textStyle: base);
}
