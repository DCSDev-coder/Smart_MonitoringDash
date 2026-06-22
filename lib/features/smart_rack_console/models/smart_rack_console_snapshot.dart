import 'package:flutter/material.dart';

import '../../../core/controllers/global_status_poller.dart';
import '../../../core/network/cpanel_api_service.dart';

@immutable
class SmartRackConsoleSnapshot {
  const SmartRackConsoleSnapshot({
    required this.siteName,
    required this.healthLabel,
    required this.healthColor,
    required this.totalDevices,
    required this.issueCount,
    required this.smokeLabel,
    required this.waterLeakLabel,
    required this.temperatureC,
    required this.humidityPct,
    required this.lastUpdatedUtc,
    required this.maintenanceDaysLeft,
    required this.systemUptimeDays,
    required this.capacityUsedPct,
    required this.memoryUsedPct,
    required this.cpuUsedPct,
    required this.diskUsedPct,
    this.temperatures = const [],
    this.humidities = const [],
    this.alarms = const [],
    this.devices = const [],
    this.smokeStatus = -1,
    this.floodStatus = -1,
    this.networkInterfaces = const [],
    this.doors = const [],
    this.recentDoorLogs = const [],
  });

  final String siteName;
  final String healthLabel;
  final Color healthColor;
  final int totalDevices;
  final int issueCount;
  final String smokeLabel;
  final String waterLeakLabel;
  final double? temperatureC;
  final double? humidityPct;
  final DateTime? lastUpdatedUtc;
  final int? maintenanceDaysLeft;
  final int? systemUptimeDays;
  final double? capacityUsedPct;
  final double? memoryUsedPct;
  final double? cpuUsedPct;
  final double? diskUsedPct;
  final List<Map<String, dynamic>> temperatures;
  final List<Map<String, dynamic>> humidities;
  final List<dynamic> alarms;
  final List<Map<String, dynamic>> devices;
  final int smokeStatus;
  final int floodStatus;
  final List<Map<String, dynamic>> networkInterfaces;
  final List<Map<String, dynamic>> doors;
  final List<Map<String, dynamic>> recentDoorLogs;

  factory SmartRackConsoleSnapshot.fromPoller(GlobalStatusPoller poller) {
    final site = CpanelApiService.instance.currentSite;
    final siteName = _firstNonEmpty([
      site?['site_name']?.toString(),
      site?['name']?.toString(),
      site?['company_name']?.toString(),
    ], fallback: 'Smart Rack');

    final sysData = poller.sysInfo?['result'] as Map<String, dynamic>? ?? poller.sysInfo;

    final temperatureC = poller.temperatureC ?? _extractDouble(
      sysData,
      const ['temperature', 'temp', 'ambientTemperature', 'ambient_temp'],
    );
    final humidityPct = poller.humidityPct ?? _extractDouble(
      sysData,
      const ['humidity', 'rh', 'relativeHumidity'],
    );
    final capacityUsedPct = poller.capacityUsedPct ?? _extractDouble(
      sysData,
      const ['capacityUsedPct', 'capacity_used_pct', 'usedRate', 'spaceUsedPct'],
    );
    final memoryUsedPct = poller.itMemoryUsage ?? poller.memoryUsedPct ?? _extractDouble(
      sysData,
      const ['memoryUsedPct', 'memory_used_pct', 'memoryUsage', 'memory'],
    );
    final cpuUsedPct = poller.itCpuUsage ?? _extractDouble(
      sysData,
      const ['cpuUsedPct', 'cpu_used_pct', 'cpuUsage', 'cpu'],
    );
    final diskUsedPct = poller.itDiskUsage ?? _extractDouble(
      sysData,
      const ['diskUsedPct', 'disk_used_pct', 'diskUsage', 'disk'],
    );

    return SmartRackConsoleSnapshot(
      siteName: siteName,
      healthLabel: poller.hasCriticalIssue
          ? 'Attention Required'
          : 'All Systems Operational',
      healthColor:
          poller.hasCriticalIssue ? Colors.redAccent : const Color(0xFF22C55E),
      totalDevices: poller.devices.length,
      issueCount: poller.recentAlarms.length,
      smokeLabel: poller.hasSmokeAlert ? 'Alert' : 'Normal',
      waterLeakLabel: poller.hasFloodAlert ? 'Alert' : 'Normal',
      temperatureC: temperatureC,
      humidityPct: humidityPct,
      lastUpdatedUtc: poller.lastUpdatedUtc,
      maintenanceDaysLeft: poller.maintenanceDaysLeft ?? _extractInt(
        sysData,
        const ['maintenanceDaysLeft', 'maintenance_days_left', 'daysLeft'],
      ),
      systemUptimeDays: poller.systemUptimeDays ?? _extractInt(
        sysData,
        const ['systemUptimeDays', 'system_uptime_days', 'uptimeDays'],
      ),
      capacityUsedPct: capacityUsedPct,
      memoryUsedPct: memoryUsedPct,
      cpuUsedPct: cpuUsedPct,
      diskUsedPct: diskUsedPct,
      temperatures: poller.rawTemperatures,
      humidities: poller.rawHumidities,
      alarms: poller.recentAlarms,
      devices: poller.devices,
      smokeStatus: poller.smokeStatus,
      floodStatus: poller.floodStatus,
      networkInterfaces: poller.networkInterfaces,
      doors: poller.doors,
      recentDoorLogs: poller.recentDoorLogs,
    );
  }

  static int? _extractInt(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static double? _extractDouble(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _firstNonEmpty(List<String?> values, {required String fallback}) {
    for (final value in values) {
      final next = value?.trim();
      if (next != null && next.isNotEmpty) return next;
    }
    return fallback;
  }
}
