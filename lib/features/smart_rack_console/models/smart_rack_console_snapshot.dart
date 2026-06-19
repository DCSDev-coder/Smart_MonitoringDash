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

  factory SmartRackConsoleSnapshot.fromPoller(GlobalStatusPoller poller) {
    final site = CpanelApiService.instance.currentSite;
    final siteName = _firstNonEmpty([
      site?['site_name']?.toString(),
      site?['name']?.toString(),
      site?['company_name']?.toString(),
    ], fallback: 'Smart Rack');

    final temperatureC = _extractDouble(
      poller.sysInfo,
      const ['temperature', 'temp', 'ambientTemperature', 'ambient_temp'],
    );
    final humidityPct = _extractDouble(
      poller.sysInfo,
      const ['humidity', 'rh', 'relativeHumidity'],
    );
    final capacityUsedPct = _extractDouble(
      poller.sysInfo,
      const ['capacityUsedPct', 'capacity_used_pct', 'usedRate', 'spaceUsedPct'],
    );
    final memoryUsedPct = _extractDouble(
      poller.sysInfo,
      const ['memoryUsedPct', 'memory_used_pct', 'memoryUsage', 'memory'],
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
      maintenanceDaysLeft: _extractInt(
        poller.sysInfo,
        const ['maintenanceDaysLeft', 'maintenance_days_left', 'daysLeft'],
      ),
      systemUptimeDays: _extractInt(
        poller.sysInfo,
        const ['systemUptimeDays', 'system_uptime_days', 'uptimeDays'],
      ),
      capacityUsedPct: capacityUsedPct,
      memoryUsedPct: memoryUsedPct,
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
