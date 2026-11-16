import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rack_dashboard/features/smart_rack_console/models/smart_rack_device_profile.dart';
import 'package:smart_rack_dashboard/features/smart_rack_console/smart_rack_console_screen.dart';
import 'package:smart_rack_dashboard/features/dashboard/dashboard_v2_screen.dart';

void main() {
  testWidgets('Test SmartRackConsoleScreen Layout', (WidgetTester tester) async {
    // Test wide layout
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartRackConsoleScreen(profile: SmartRackDeviceProfiles.androidOperator),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Test narrow layout
    tester.view.physicalSize = const Size(380, 800);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartRackConsoleScreen(profile: SmartRackDeviceProfiles.androidOperator),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Test DashboardV2Screen Layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardV2Screen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  });
}
