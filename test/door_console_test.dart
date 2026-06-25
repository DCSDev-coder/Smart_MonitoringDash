import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rack_dashboard/features/smart_rack_console/door_console_screen.dart';
import 'package:smart_rack_dashboard/features/smart_rack_console/models/smart_rack_console_snapshot.dart';
import 'package:smart_rack_dashboard/core/theme/app_theme.dart';

void main() {
  testWidgets('Test DoorConsoleScreen Layout', (WidgetTester tester) async {
    final mockSnapshot = SmartRackConsoleSnapshot(
      siteName: 'Test Site',
      healthLabel: 'All Systems Operational',
      healthColor: Colors.green,
      totalDevices: 10,
      issueCount: 0,
      smokeLabel: 'Normal',
      waterLeakLabel: 'Normal',
      temperatureC: 25.0,
      humidityPct: 50.0,
      lastUpdatedUtc: DateTime.now(),
      maintenanceDaysLeft: 100,
      systemUptimeDays: 200,
      capacityUsedPct: 30.0,
      memoryUsedPct: 40.0,
      cpuUsedPct: 15.0,
      diskUsedPct: 45.0,
      pue: 2.25,
      doors: [
        {
          'id': 1,
          'accessName': 'Test Door 1',
          'doorStatus': 1,
          'lockStatus': 0,
        },
        {
          'id': 2,
          'accessName': 'Test Door 2',
          'doorStatus': 0,
          'lockStatus': 1,
        }
      ],
      recentDoorLogs: [
        {
          'opTime': '2026-06-22 15:30:00',
          'accessName': 'Test Door 1',
          'username': 'Admin',
          'openType': '1'
        }
      ],
    );

    // Test wide layout
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 800,
            child: DoorConsoleScreen(snapshot: mockSnapshot),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Test narrow layout
    tester.view.physicalSize = const Size(400, 800);
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: DoorConsoleScreen(snapshot: mockSnapshot),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

