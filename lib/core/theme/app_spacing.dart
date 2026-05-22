import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  //Page level padding
  static double pageHorizontal(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 0.06;

  static double pageBottom(BuildContext context){
    final w = MediaQuery.sizeOf(context).width;
    //Unifies the 92-95px bottom required for the floating bottom nav
    return w >= 600 ? 24.0 : MediaQuery.paddingOf(context).bottom + 95.0;
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