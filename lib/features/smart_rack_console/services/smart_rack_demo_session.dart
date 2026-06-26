import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/cpanel_api_service.dart';
import '../models/smart_rack_console_snapshot.dart';

class SmartRackDemoSession extends ChangeNotifier {
  SmartRackDemoSession._();

  static final instance = SmartRackDemoSession._();

  static const List<String> _scenarios = <String>[
    'normal',
    'warning',
    'critical',
  ];

  Timer? _timer;
  int _scenarioIndex = 0;

  String get currentScenario => _scenarios[_scenarioIndex % _scenarios.length];

  bool get isRunning => _timer != null;

  void ensureDemoContext() {
    CpanelApiService.instance.currentSite = <String, dynamic>{
      'site_id': 1,
      'id': 1,
      'site_name': 'INVTRack Event Demo',
      'company_name': 'DCStack',
      'company_logo_path': '',
      'is_kiosk': 1,
      'role': 'admin',
      'can_control_doors': 0,
    };
    CpanelApiService.instance.currentUser = <String, dynamic>{
      'id': 1,
      'username': 'demo',
      'has_pin': 1,
      'pin_setup': 1,
    };
  }

  void startRotation() {
    if (!AppConfig.demoScenarioRotationEnabled) {
      return;
    }
    if (_timer != null) return;
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.demoScenarioSeconds),
      (_) => advanceScenario(),
    );
  }

  void stopRotation() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    _scenarioIndex = 0;
    notifyListeners();
  }

  void advanceScenario() {
    _scenarioIndex = (_scenarioIndex + 1) % _scenarios.length;
    notifyListeners();
  }

  SmartRackConsoleSnapshot currentSnapshot() {
    return _snapshotForScenario(currentScenario);
  }

  SmartRackConsoleSnapshot _snapshotForScenario(String scenario) {
    switch (scenario) {
      case 'warning':
        return _warningSnapshot();
      case 'critical':
        return _criticalSnapshot();
      case 'normal':
      default:
        return _normalSnapshot();
    }
  }

  SmartRackConsoleSnapshot _normalSnapshot() {
    return SmartRackConsoleSnapshot(
      siteName: 'INVTRack Event Demo',
      healthLabel: 'All Systems Operational',
      healthColor: const Color(0xFF22C55E),
      totalDevices: 13,
      issueCount: 0,
      smokeLabel: 'Normal',
      waterLeakLabel: 'Normal',
      temperatureC: 24.6,
      humidityPct: 60.5,
      lastUpdatedUtc: DateTime.now().toUtc(),
      maintenanceDaysLeft: 24,
      systemUptimeDays: 886,
      capacityUsedPct: 29.76,
      memoryUsedPct: 63.2,
      cpuUsedPct: 41.8,
      diskUsedPct: 55.4,
      pue: 1.28,
      temperatures: const [
        {'name': 'Front', 'value': 24.6},
        {'name': 'Back', 'value': 24.2},
      ],
      humidities: const [
        {'name': 'Front', 'value': 60.5},
        {'name': 'Back', 'value': 61.2},
      ],
      alarms: const [],
      devices: const [
        {'nodeName': 'UPS 1', 'type': 'UPS', 'status': '1'},
        {'nodeName': 'AC 1', 'type': 'AC', 'status': '1'},
        {'nodeName': 'T&H Sensor 1 Front', 'type': 'T&H', 'status': '1'},
        {'nodeName': 'PDU 1', 'type': 'PDU', 'status': '1'},
      ],
      smokeStatus: 0,
      floodStatus: 0,
      networkInterfaces: const [
        {'name': 'LAN', 'status': 'Online'},
      ],
      doors: const [
        {'id': 1, 'name': 'Front Door', 'isOpen': false},
        {'id': 2, 'name': 'Back Door', 'isOpen': false},
      ],
      recentDoorLogs: const [
        {
          'doorName': 'Front Door',
          'user': 'operator',
          'time': '2026/06/25 11:10:00',
          'status': 'Closed',
        },
        {
          'doorName': 'Back Door',
          'user': 'operator',
          'time': '2026/06/25 11:08:00',
          'status': 'Closed',
        },
      ],
    );
  }

  SmartRackConsoleSnapshot _warningSnapshot() {
    return SmartRackConsoleSnapshot(
      siteName: 'INVTRack Event Demo',
      healthLabel: 'Attention Required',
      healthColor: const Color(0xFFF59E0B),
      totalDevices: 13,
      issueCount: 2,
      smokeLabel: 'Normal',
      waterLeakLabel: 'Normal',
      temperatureC: 28.4,
      humidityPct: 71.2,
      lastUpdatedUtc: DateTime.now().toUtc(),
      maintenanceDaysLeft: 19,
      systemUptimeDays: 886,
      capacityUsedPct: 39.14,
      memoryUsedPct: 71.8,
      cpuUsedPct: 58.6,
      diskUsedPct: 61.2,
      pue: 1.44,
      temperatures: const [
        {'name': 'Front', 'value': 28.4},
        {'name': 'Back', 'value': 27.9},
      ],
      humidities: const [
        {'name': 'Front', 'value': 71.2},
        {'name': 'Back', 'value': 72.4},
      ],
      alarms: const [
        {'msg': 'Temperature trending high', 'alarmLevel': 'warning'},
        {'msg': 'UPS battery check due', 'alarmLevel': 'warning'},
      ],
      devices: const [
        {'nodeName': 'UPS 1', 'type': 'UPS', 'status': '0', 'statusColor': '#F59E0B'},
        {'nodeName': 'AC 1', 'type': 'AC', 'status': '0', 'statusColor': '#F59E0B'},
        {'nodeName': 'T&H Sensor 1 Front', 'type': 'T&H', 'status': '0', 'statusColor': '#F59E0B'},
        {'nodeName': 'PDU 1', 'type': 'PDU', 'status': '1'},
      ],
      smokeStatus: 0,
      floodStatus: 0,
      networkInterfaces: const [
        {'name': 'LAN', 'status': 'Online'},
      ],
      doors: const [
        {'id': 1, 'name': 'Front Door', 'isOpen': false},
        {'id': 2, 'name': 'Back Door', 'isOpen': false},
      ],
      recentDoorLogs: const [
        {
          'doorName': 'Front Door',
          'user': 'technician',
          'time': '2026/06/25 11:22:00',
          'status': 'Closed',
        },
        {
          'doorName': 'Back Door',
          'user': 'technician',
          'time': '2026/06/25 11:18:00',
          'status': 'Closed',
        },
      ],
    );
  }

  SmartRackConsoleSnapshot _criticalSnapshot() {
    return SmartRackConsoleSnapshot(
      siteName: 'INVTRack Event Demo',
      healthLabel: 'Critical Alarm',
      healthColor: const Color(0xFFEF4444),
      totalDevices: 13,
      issueCount: 5,
      smokeLabel: 'Alert',
      waterLeakLabel: 'Alert',
      temperatureC: 33.8,
      humidityPct: 76.5,
      lastUpdatedUtc: DateTime.now().toUtc(),
      maintenanceDaysLeft: 7,
      systemUptimeDays: 886,
      capacityUsedPct: 52.88,
      memoryUsedPct: 79.4,
      cpuUsedPct: 73.1,
      diskUsedPct: 68.9,
      pue: 1.78,
      temperatures: const [
        {'name': 'Front', 'value': 33.8},
        {'name': 'Back', 'value': 34.6},
      ],
      humidities: const [
        {'name': 'Front', 'value': 76.5},
        {'name': 'Back', 'value': 77.3},
      ],
      alarms: const [
        {'msg': 'Smoke sensor alert', 'alarmLevel': 'critical'},
        {'msg': 'Front door open', 'alarmLevel': 'critical'},
        {'msg': 'Back door open', 'alarmLevel': 'critical'},
        {'msg': 'UPS fault detected', 'alarmLevel': 'critical'},
        {'msg': 'Cooling degraded', 'alarmLevel': 'critical'},
      ],
      devices: const [
        {'nodeName': 'UPS 1', 'type': 'UPS', 'status': '0', 'statusColor': '#EF4444'},
        {'nodeName': 'AC 1', 'type': 'AC', 'status': '0', 'statusColor': '#F59E0B'},
        {'nodeName': 'T&H Sensor 1 Front', 'type': 'T&H', 'status': '0', 'statusColor': '#EF4444'},
        {'nodeName': 'PDU 1', 'type': 'PDU', 'status': '0', 'statusColor': '#EF4444'},
      ],
      smokeStatus: 1,
      floodStatus: 1,
      networkInterfaces: const [
        {'name': 'LAN', 'status': 'Online'},
      ],
      doors: const [
        {'id': 1, 'name': 'Front Door', 'isOpen': true},
        {'id': 2, 'name': 'Back Door', 'isOpen': true},
      ],
      recentDoorLogs: const [
        {
          'doorName': 'Front Door',
          'user': 'response team',
          'time': '2026/06/25 11:27:00',
          'status': 'Open',
        },
        {
          'doorName': 'Back Door',
          'user': 'response team',
          'time': '2026/06/25 11:26:00',
          'status': 'Open',
        },
      ],
    );
  }
}
