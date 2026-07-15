import 'package:flutter/material.dart';

import '../../../core/controllers/global_status_poller.dart';
import '../../../core/network/cpanel_api_service.dart';

@immutable
class ConsoleBreakdownItem {
  const ConsoleBreakdownItem({
    required this.label,
    required this.percentage,
  });

  final String label;
  final double percentage;
}

@immutable
class ConsoleMetricRow {
  const ConsoleMetricRow({
    required this.label,
    required this.value,
    this.isNormal = false,
  });

  final String label;
  final String value;
  final bool isNormal;
}

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
    this.responseTimeMs,
    this.packetLossPct,
    required this.pue,
    this.totalMonthEnergyKwh,
    this.capacityBreakdown = const [],
    this.powerInletRows = const [],
    this.powerOutletRows = const [],
    this.powerPdu1Outlets = const [],
    this.powerPdu2Outlets = const [],
    this.powerPdu1MetricRows = const [],
    this.powerPdu1StatusRows = const [],
    this.powerPdu1SettingRows = const [],
    this.powerPdu2MetricRows = const [],
    this.powerPdu2StatusRows = const [],
    this.powerPdu2SettingRows = const [],
    this.acMetricRows = const [],
    this.acSettingRows = const [],
    this.acStatusRows = const [],
    this.acUnitStatus,
    this.acCompressorStatus,
    this.upsParameterRows = const [],
    this.upsStatusRows = const [],
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
  final double? responseTimeMs;
  final double? packetLossPct;
  final double? pue;
  final double? totalMonthEnergyKwh;
  final List<ConsoleBreakdownItem> capacityBreakdown;
  final List<ConsoleMetricRow> powerInletRows;
  final List<ConsoleMetricRow> powerOutletRows;
  final List<Map<String, dynamic>> powerPdu1Outlets;
  final List<Map<String, dynamic>> powerPdu2Outlets;
  final List<ConsoleMetricRow> powerPdu1MetricRows;
  final List<ConsoleMetricRow> powerPdu1StatusRows;
  final List<ConsoleMetricRow> powerPdu1SettingRows;
  final List<ConsoleMetricRow> powerPdu2MetricRows;
  final List<ConsoleMetricRow> powerPdu2StatusRows;
  final List<ConsoleMetricRow> powerPdu2SettingRows;
  final List<ConsoleMetricRow> acMetricRows;
  final List<ConsoleMetricRow> acSettingRows;
  final List<ConsoleMetricRow> acStatusRows;
  final String? acUnitStatus;
  final String? acCompressorStatus;
  final List<ConsoleMetricRow> upsParameterRows;
  final List<ConsoleMetricRow> upsStatusRows;
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

    final sysData =
        poller.sysInfo?['result'] as Map<String, dynamic>? ?? poller.sysInfo;

    final temperatureC = poller.temperatureC ??
        _extractDouble(
          sysData,
          const ['temperature', 'temp', 'ambientTemperature', 'ambient_temp'],
        );
    final humidityPct = poller.humidityPct ??
        _extractDouble(
          sysData,
          const ['humidity', 'rh', 'relativeHumidity'],
        );
    final capacityUsedPct = poller.capacityUsedPct ??
        _extractDouble(
          sysData,
          const [
            'capacityUsedPct',
            'capacity_used_pct',
            'usedRate',
            'spaceUsedPct'
          ],
        );
    final memoryUsedPct = poller.itMemoryUsage ??
        poller.memoryUsedPct ??
        _extractDouble(
          sysData,
          const ['memoryUsedPct', 'memory_used_pct', 'memoryUsage', 'memory'],
        );
    final cpuUsedPct = poller.itCpuUsage ??
        _extractDouble(
          sysData,
          const ['cpuUsedPct', 'cpu_used_pct', 'cpuUsage', 'cpu'],
        );
    final diskUsedPct = poller.itDiskUsage ??
        _extractDouble(
          sysData,
          const ['diskUsedPct', 'disk_used_pct', 'diskUsage', 'disk'],
        );
    final totalPower = _extractDouble(
          sysData,
          const ['totalPower', 'total_power', 'Total', 'TOTAL'],
        ) ??
        0.0;

    final itPower = _extractDouble(
          sysData,
          const ['itPower', 'it_power', 'IT', 'IT Device', 'IT DEVICE'],
        ) ??
        0.0;

    double? calculatedPue;
    if (itPower > 0 && totalPower > 0) {
      calculatedPue = totalPower / itPower;
    }

    final pueVal = calculatedPue ??
        poller.pue ??
        _extractDouble(
          sysData,
          const ['pue', 'currentPue', 'current_pue'],
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
      maintenanceDaysLeft: poller.maintenanceDaysLeft ??
          _extractInt(
            sysData,
            const ['maintenanceDaysLeft', 'maintenance_days_left', 'daysLeft'],
          ),
      systemUptimeDays: poller.systemUptimeDays ??
          _extractInt(
            sysData,
            const ['systemUptimeDays', 'system_uptime_days', 'uptimeDays'],
          ),
      capacityUsedPct: capacityUsedPct,
      memoryUsedPct: memoryUsedPct,
      cpuUsedPct: cpuUsedPct,
      diskUsedPct: diskUsedPct,
      responseTimeMs: poller.itResponseMs,
      packetLossPct: poller.itPacketLossPct,
      pue: pueVal,
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

  SmartRackConsoleSnapshot copyWith({
    String? siteName,
    String? healthLabel,
    Color? healthColor,
    int? totalDevices,
    int? issueCount,
    String? smokeLabel,
    String? waterLeakLabel,
    double? temperatureC,
    double? humidityPct,
    DateTime? lastUpdatedUtc,
    int? maintenanceDaysLeft,
    int? systemUptimeDays,
    double? capacityUsedPct,
    double? memoryUsedPct,
    double? cpuUsedPct,
    double? diskUsedPct,
    double? responseTimeMs,
    double? packetLossPct,
    double? pue,
    double? totalMonthEnergyKwh,
    List<ConsoleBreakdownItem>? capacityBreakdown,
    List<ConsoleMetricRow>? powerInletRows,
    List<ConsoleMetricRow>? powerOutletRows,
    List<Map<String, dynamic>>? powerPdu1Outlets,
    List<Map<String, dynamic>>? powerPdu2Outlets,
    List<ConsoleMetricRow>? powerPdu1MetricRows,
    List<ConsoleMetricRow>? powerPdu1StatusRows,
    List<ConsoleMetricRow>? powerPdu1SettingRows,
    List<ConsoleMetricRow>? powerPdu2MetricRows,
    List<ConsoleMetricRow>? powerPdu2StatusRows,
    List<ConsoleMetricRow>? powerPdu2SettingRows,
    List<ConsoleMetricRow>? acMetricRows,
    List<ConsoleMetricRow>? acSettingRows,
    List<ConsoleMetricRow>? acStatusRows,
    String? acUnitStatus,
    String? acCompressorStatus,
    List<ConsoleMetricRow>? upsParameterRows,
    List<ConsoleMetricRow>? upsStatusRows,
    List<Map<String, dynamic>>? temperatures,
    List<Map<String, dynamic>>? humidities,
    List<dynamic>? alarms,
    List<Map<String, dynamic>>? devices,
    int? smokeStatus,
    int? floodStatus,
    List<Map<String, dynamic>>? networkInterfaces,
    List<Map<String, dynamic>>? doors,
    List<Map<String, dynamic>>? recentDoorLogs,
  }) {
    return SmartRackConsoleSnapshot(
      siteName: siteName ?? this.siteName,
      healthLabel: healthLabel ?? this.healthLabel,
      healthColor: healthColor ?? this.healthColor,
      totalDevices: totalDevices ?? this.totalDevices,
      issueCount: issueCount ?? this.issueCount,
      smokeLabel: smokeLabel ?? this.smokeLabel,
      waterLeakLabel: waterLeakLabel ?? this.waterLeakLabel,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPct: humidityPct ?? this.humidityPct,
      lastUpdatedUtc: lastUpdatedUtc ?? this.lastUpdatedUtc,
      maintenanceDaysLeft: maintenanceDaysLeft ?? this.maintenanceDaysLeft,
      systemUptimeDays: systemUptimeDays ?? this.systemUptimeDays,
      capacityUsedPct: capacityUsedPct ?? this.capacityUsedPct,
      memoryUsedPct: memoryUsedPct ?? this.memoryUsedPct,
      cpuUsedPct: cpuUsedPct ?? this.cpuUsedPct,
      diskUsedPct: diskUsedPct ?? this.diskUsedPct,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      packetLossPct: packetLossPct ?? this.packetLossPct,
      pue: pue ?? this.pue,
      totalMonthEnergyKwh: totalMonthEnergyKwh ?? this.totalMonthEnergyKwh,
      capacityBreakdown: capacityBreakdown ?? this.capacityBreakdown,
      powerInletRows: powerInletRows ?? this.powerInletRows,
      powerOutletRows: powerOutletRows ?? this.powerOutletRows,
      powerPdu1Outlets: powerPdu1Outlets ?? this.powerPdu1Outlets,
      powerPdu2Outlets: powerPdu2Outlets ?? this.powerPdu2Outlets,
      powerPdu1MetricRows: powerPdu1MetricRows ?? this.powerPdu1MetricRows,
      powerPdu1StatusRows: powerPdu1StatusRows ?? this.powerPdu1StatusRows,
      powerPdu1SettingRows: powerPdu1SettingRows ?? this.powerPdu1SettingRows,
      powerPdu2MetricRows: powerPdu2MetricRows ?? this.powerPdu2MetricRows,
      powerPdu2StatusRows: powerPdu2StatusRows ?? this.powerPdu2StatusRows,
      powerPdu2SettingRows: powerPdu2SettingRows ?? this.powerPdu2SettingRows,
      acMetricRows: acMetricRows ?? this.acMetricRows,
      acSettingRows: acSettingRows ?? this.acSettingRows,
      acStatusRows: acStatusRows ?? this.acStatusRows,
      acUnitStatus: acUnitStatus ?? this.acUnitStatus,
      acCompressorStatus: acCompressorStatus ?? this.acCompressorStatus,
      upsParameterRows: upsParameterRows ?? this.upsParameterRows,
      upsStatusRows: upsStatusRows ?? this.upsStatusRows,
      temperatures: temperatures ?? this.temperatures,
      humidities: humidities ?? this.humidities,
      alarms: alarms ?? this.alarms,
      devices: devices ?? this.devices,
      smokeStatus: smokeStatus ?? this.smokeStatus,
      floodStatus: floodStatus ?? this.floodStatus,
      networkInterfaces: networkInterfaces ?? this.networkInterfaces,
      doors: doors ?? this.doors,
      recentDoorLogs: recentDoorLogs ?? this.recentDoorLogs,
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

  static String _firstNonEmpty(List<String?> values,
      {required String fallback}) {
    for (final value in values) {
      final next = value?.trim();
      if (next != null && next.isNotEmpty) return next;
    }
    return fallback;
  }
}
