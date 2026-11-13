import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  //Page level padding
  static double pageHorizontal(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 ? 6.0 : w * 0.06;
  }

  static double pageBottom(BuildContext context){
    final w = MediaQuery.sizeOf(context).width;
    // Unifies the bottom padding required for the floating bottom nav,
    // ensuring content can be scrolled fully above the nav bar.
    return w >= 600 ? 24.0 : MediaQuery.paddingOf(context).bottom + 140.0;
  }

  //Section gaps (between major section)
  static const double sectionGapSm = 12.0;
  static const double sectionGapMd = 24.0;
  static const double sectionGapLg = 32.0;

  //Card layout gaps
  static const double cardGap = 14.0;

  //Internal card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(18.0);
}