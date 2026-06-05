import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class GlobalEventBus {
  static final ValueNotifier<Map?> targetHistoricalAlarm = ValueNotifier(null);
  static final ValueNotifier<bool> targetMaintenancePage = ValueNotifier(false);
}
