import 'dart:async';

import 'package:flutter/widgets.dart';

import '../constants/app_constants.dart';
import '../controllers/smart_polling_settings.dart';
import '../network/adapter_api_service.dart';
import '../network/api_service.dart';
import '../network/cpanel_api_service.dart';
import '../utils/app_log.dart';

/// Centralized polling hub for app-wide status.
///
/// Why this exists:
/// - Avoid duplicated timers & network calls across screens (dashboard + shell).
/// - Provide a single source of truth for "global" indicators (alerts badge,
///   smoke/flood state, device health list, etc.).
///
/// The poller is intentionally small and dependency-free (no Provider/Riverpod).
/// UI can subscribe via `AnimatedBuilder` / `ListenableBuilder`.
class GlobalStatusPoller extends ChangeNotifier with WidgetsBindingObserver {
  GlobalStatusPoller._();
  static final GlobalStatusPoller instance = GlobalStatusPoller._();

  Timer? _timer;
  bool _enabled = false; // caller wants polling enabled for this session
  bool _observerRegistered = false;
  bool _inFlight = false;
  bool _emergencyMode = false;
  Duration _currentInterval = SmartPollingSettings.instance.normalInterval();
  bool _settingsListenerAttached = false;

  // Cached results
  int smokeStatus = -1;
  int floodStatus = -1;
  List<Map<String, dynamic>> devices = const [];
  List<dynamic> recentAlarms = const [];
  Map<String, dynamic>? sysInfo;

  // Cached telemetry/metrics for Rack Console
  double? temperatureC;
  double? humidityPct;
  List<Map<String, dynamic>> rawTemperatures = const [];
  List<Map<String, dynamic>> rawHumidities = const [];
  double? capacityUsedPct;
  double? memoryUsedPct;
  double? itCpuUsage;
  double? itMemoryUsage;
  double? itDiskUsage;
  List<Map<String, dynamic>> networkInterfaces = const [];
  List<Map<String, dynamic>> doors = const [];
  List<Map<String, dynamic>> recentDoorLogs = const [];
  int? maintenanceDaysLeft;
  int? systemUptimeDays;
  double? pue;

  DateTime? lastUpdatedUtc;

  bool get running => _enabled;


  bool get hasSmokeAlert => smokeStatus != 0 && smokeStatus != -1;
  bool get hasFloodAlert => floodStatus != 0 && floodStatus != -1;

  /// Used by the header/badge layer.
  bool get hasCriticalBanner => hasSmokeAlert || hasFloodAlert;

  /// Any issue that should light up the alerts icon (even if not critical).
  bool get hasAnyIssue =>
      hasSmokeAlert || hasFloodAlert || devices.any(_deviceHasIssue) || recentAlarms.isNotEmpty;

  /// Whether the current issues should be treated as critical (for emphasis).
  bool get hasCriticalIssue =>
      hasSmokeAlert || hasFloodAlert || devices.any(_deviceHasIssue) || _hasCriticalRecentAlarm();

  /// Whether we are currently in fast-poll mode due to an emergency/issue.
  bool get emergencyMode => _emergencyMode;

  void start() {
    if (_enabled) return;
    _enabled = true;

    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    if (!_settingsListenerAttached) {
      SmartPollingSettings.instance.addListener(_onSettingsChanged);
      _settingsListenerAttached = true;
    }

    // Only run the timer while app is in foreground.
    _ensureTimer();
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _enabled = false;
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    if (_settingsListenerAttached) {
      SmartPollingSettings.instance.removeListener(_onSettingsChanged);
      _settingsListenerAttached = false;
    }
    notifyListeners();
  }

  void _onSettingsChanged() {
    // Don't override emergency mode. Only adjust the baseline interval.
    if (_emergencyMode) return;
    _currentInterval = SmartPollingSettings.instance.normalInterval();
    _restartTimerIfRunning();
  }

  void _ensureTimer() {
    if (!_enabled) return;
    if (_timer != null) return;
    // Immediate fetch, then periodic (interval depends on emergency mode).
    fetchNow();
    _timer = Timer.periodic(_currentInterval, (_) => fetchNow());
  }

  void _restartTimerIfRunning() {
    if (!_enabled) return;
    if (_timer == null) return;
    _timer!.cancel();
    _timer = Timer.periodic(_currentInterval, (_) => fetchNow());
  }

  bool _deviceHasIssue(Map<String, dynamic> d) {
    final normalRaw = d['normalCount'];
    final totalRaw = d['totalCount'];
    final normal = normalRaw is num ? normalRaw.toInt() : int.tryParse('$normalRaw') ?? 0;
    final total = totalRaw is num ? totalRaw.toInt() : int.tryParse('$totalRaw') ?? 0;
    if (total <= 0) return false;
    return normal != total;
  }

  bool _hasCriticalRecentAlarm() {
    for (final a in recentAlarms) {
      if (a is! Map) continue;
      final level = (a['alarmLevelLevel'] ?? a['alarmLevel'] ?? '').toString().toUpperCase().trim();
      if (level == 'CRITICAL' || level == 'RED') return true;
    }
    return false;
  }

  bool _computeEmergencyMode() {
    if (hasSmokeAlert || hasFloodAlert) return true;
    if (devices.any(_deviceHasIssue)) return true;
    if (_hasCriticalRecentAlarm()) return true;
    return false;
  }

  void _applyEmergencyMode(bool nextEmergency) {
    if (_emergencyMode == nextEmergency) return;
    _emergencyMode = nextEmergency;

    // Normal: respect existing configured poll interval.
    // Emergency: poll faster for better responsiveness.
    _currentInterval =
        _emergencyMode ? const Duration(seconds: 5) : SmartPollingSettings.instance.normalInterval();

    _restartTimerIfRunning();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _ensureTimer();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _timer?.cancel();
        _timer = null;
        break;
    }
  }

  double? _extractDouble(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  int? _extractInt(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> fetchNow() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      Future<Map<String, dynamic>?> environmentWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter =
              await AdapterApiService.instance.fetchEnvironment(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchEnvironment();
      }

      Future<Map<String, dynamic>?> deviceStatusWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter = await AdapterApiService.instance
              .fetchDeviceStatus(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchDeviceStatus();
      }

      Future<Map<String, dynamic>?> sysInfoWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter =
              await AdapterApiService.instance.fetchSysInfo(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchSysInfo();
      }

      Future<Map<String, dynamic>?> recentAlarmsWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter =
              await AdapterApiService.instance.fetchRecentAlarms(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchRecentAlarms();
      }

      Future<Map<String, dynamic>?> tempHumWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter =
              await AdapterApiService.instance.fetchTempHumTopN(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchTempHumTopN();
      }

      Future<Map<String, dynamic>?> pueWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter =
              await AdapterApiService.instance.fetchPue(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        final cabinetId = site?['cabinet_id']?.toString() ?? '1';
        return ApiService.instance.fetchPue(id: cabinetId);
      }

      Future<Map<String, dynamic>?> powerMonthWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter =
              await AdapterApiService.instance.fetchPowerMonth(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        final cabinetId = site?['cabinet_id']?.toString() ?? '1';
        return ApiService.instance.fetchPowerMonth(id: cabinetId);
      }

      Future<Map<String, dynamic>?> cabinetStatsWithFallback() async {
        return ApiService.instance.fetchCabinetStats();
      }

      Future<Map<String, dynamic>?> redisMemoryWithFallback() async {
        return ApiService.instance.fetchRedisMemory();
      }

      Future<Map<String, dynamic>?> itDeviceInterfacesWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter = await AdapterApiService.instance.fetchItDeviceInterfaces(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchItDeviceInterfaces();
      }

      Future<Map<String, dynamic>?> itDeviceTopMetricsWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter = await AdapterApiService.instance.fetchItDeviceTopMetrics(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchItDeviceTopMetrics();
      }

      Future<Map<String, dynamic>?> doorsWithFallback() async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter =
              await AdapterApiService.instance.fetchDoors(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchCabinetDoors(cabinetId: 1);
      }

      Future<List<Map<String, dynamic>>> remoteLogsWithFallback() async {
        if (siteId != null) {
          try {
            return await CpanelApiService.instance.fetchRemoteAccessLogs(
              siteId: siteId,
            );
          } catch (_) {}
        }
        return [];
      }

      final results = await Future.wait([
        environmentWithFallback(),
        deviceStatusWithFallback(),
        sysInfoWithFallback(),
        recentAlarmsWithFallback(),
        tempHumWithFallback(),
        pueWithFallback(),
        powerMonthWithFallback(),
        cabinetStatsWithFallback(),
        redisMemoryWithFallback(),
        itDeviceInterfacesWithFallback(),
        itDeviceTopMetricsWithFallback(),
        doorsWithFallback(),
        ApiService.instance.fetchDoorAccessLogs(pageSize: 20),
        remoteLogsWithFallback(),
      ]);

      final env = results[0] as Map<String, dynamic>?;
      final ds = results[1] as Map<String, dynamic>?;
      final si = results[2] as Map<String, dynamic>?;
      final ra = results[3] as Map<String, dynamic>?;
      final th = results[4] as Map<String, dynamic>?;
      final pu = results[5] as Map<String, dynamic>?;
      final pm = results[6] as Map<String, dynamic>?;
      final cs = results[7] as Map<String, dynamic>?;
      final rm = results[8] as Map<String, dynamic>?;
      final itInterfaces = results[9] as Map<String, dynamic>?;
      final itTopMetrics = results[10] as Map<String, dynamic>?;
      final doorsRes = results[11] as Map<String, dynamic>?;
      final doorLogsRes = results[12] as Map<String, dynamic>?;

      // Update cached values (best-effort; keep last good values on nulls).
      if (env != null && (env['result'] as List?)?.isNotEmpty == true) {
        final e = env['result'][0];
        smokeStatus = (e['smokeStatus'] as int?) ?? smokeStatus;
        floodStatus = (e['floodStatus'] as int?) ?? floodStatus;
      }

      if (ds != null) {
        devices = (ds['result'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            devices;
      }

      if (si != null) {
        sysInfo = (si as Map).cast<String, dynamic>();
        final sysData = sysInfo?['result'] as Map<String, dynamic>? ?? sysInfo;
        systemUptimeDays = _extractInt(sysData, const ['systemUptimeDays', 'system_uptime_days', 'uptimeDays']) ?? systemUptimeDays;
      }

      if (ra != null && ra['result'] != null) {
        recentAlarms = (ra['result'] as List?)?.toList() ?? recentAlarms;
      }

      if (th != null && th['result'] != null) {
        final List? temps = th['result']['temperature'] as List?;
        final List? hums = th['result']['humidity'] as List?;

        if (temps != null && temps.isNotEmpty) {
          rawTemperatures = temps.map((e) => (e as Map).cast<String, dynamic>()).toList();
          double sum = 0;
          int count = 0;
          for (final item in temps) {
            final val = double.tryParse(item['value']?.toString() ?? '');
            if (val != null) {
              sum += val;
              count++;
            }
          }
          if (count > 0) {
            temperatureC = sum / count;
          }
        }

        if (hums != null && hums.isNotEmpty) {
          rawHumidities = hums.map((e) => (e as Map).cast<String, dynamic>()).toList();
          double sum = 0;
          int count = 0;
          for (final item in hums) {
            final val = double.tryParse(item['value']?.toString() ?? '');
            if (val != null) {
              sum += val;
              count++;
            }
          }
          if (count > 0) {
            humidityPct = sum / count;
          }
        }
      }

      if (pu != null) {
        double? parsedPue;
        if (pu.containsKey('pue')) {
          parsedPue = double.tryParse(pu['pue']?.toString() ?? '');
        }
        if (parsedPue == null && pu['result'] != null) {
          final res = pu['result'];
          if (res is num) {
            parsedPue = res.toDouble();
          } else if (res is Map) {
            final v = res['pue'] ?? res['pueValue'] ?? res['axisY'] ?? res['pue_value'];
            parsedPue = double.tryParse(v?.toString() ?? '');
          }
        }
        if (parsedPue != null && parsedPue > 0) {
          pue = parsedPue;
        }
      }

      if (pue == null && pm != null && pm['result'] is Map) {
        final powerBreakdown = (pm['result'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
        );
        final totalE = powerBreakdown['Total'] ??
            powerBreakdown['TOTAL'] ??
            powerBreakdown['total_power'] ??
            powerBreakdown['totalPower'] ??
            0.0;
        final itE = powerBreakdown['IT Device'] ??
            powerBreakdown['IT DEVICE'] ??
            powerBreakdown['IT'] ??
            powerBreakdown['it_power'] ??
            powerBreakdown['itPower'] ??
            powerBreakdown['IT_DEVICE'] ??
            0.0;
        if (itE > 0) {
          final derived = totalE / itE;
          if (derived.isFinite && derived > 0) {
            pue = derived;
          }
        }
      }

      if (cs != null && cs['result'] != null) {
        final statsData = cs['result'] as Map<String, dynamic>? ?? cs;
        capacityUsedPct = _extractDouble(statsData, const ['capacityUsedPct', 'capacity_used_pct', 'usedRate', 'spaceUsedPct']) ?? capacityUsedPct;
      }

      if (rm != null) {
        // Redis memory is specifically for the Redis cache, NOT the system's actual hardware memory usage.
        // We do NOT override the global memoryUsedPct with Redis memory here so that the UI can properly extract system memory from sysInfo.
      }

      if (itInterfaces != null && itInterfaces['result'] != null) {
        final list = itInterfaces['result'] as List?;
        if (list != null) {
          networkInterfaces = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        }
      }

      if (itTopMetrics != null && itTopMetrics['result'] != null) {
        final list = itTopMetrics['result'] as List?;
        if (list != null) {
          for (final item in list) {
            if (item is Map) {
              final code = item['metricTypeLibCode']?.toString();
              final val = double.tryParse(item['value']?.toString() ?? '');
              if (code == 'cpu_usage') itCpuUsage = val;
              if (code == 'mem_usage') itMemoryUsage = val;
              if (code == 'host_disk_usage') itDiskUsage = val;
            }
          }
        }
      }

      if (site != null) {
        if (site['last_maintenance'] != null) {
          final lastM = DateTime.tryParse(site['last_maintenance']);
          if (lastM != null) {
            final diff = DateTime.now().difference(lastM).inDays;
            maintenanceDaysLeft = (90 - diff).clamp(0, 90);
          }
        }
      }

      if (doorsRes != null && doorsRes['result'] != null) {
        final rawDoors = doorsRes['result'];
        if (rawDoors is List) {
           doors = List<Map<String, dynamic>>.from(rawDoors.whereType<Map<String, dynamic>>());
        } else if (rawDoors is Map) {
           final details = (rawDoors['detailList'] as List?) ?? (rawDoors['detail_list'] as List?) ?? (rawDoors['accessList'] as List?) ?? (rawDoors['doorList'] as List?) ?? const [];
           doors = List<Map<String, dynamic>>.from(details.whereType<Map<String, dynamic>>());
        }
      }

      final List<Map<String, dynamic>> mergedLogs = [];

      // 1. Process Dahua logs
      if (doorLogsRes != null && doorLogsRes['result'] != null) {
        final records = doorLogsRes['result']['records'];
        if (records is List) {
          for (final record in records) {
            if (record is Map) {
              final Map<String, dynamic> log = Map<String, dynamic>.from(record);
              final u = (log['opUser'] ?? log['openUser'] ?? log['userName'] ?? log['username'] ?? log['user'])?.toString().toLowerCase() ?? '';
              if (u == 'superadmin' || u == 'admin' || u == 'remote open') {
                 continue; // Remove Dahua's generic remote unlock logs completely
              }
              mergedLogs.add(log);
            }
          }
        }
      }

      // 2. Fetch/merge cpanelLogs
      final cpanelLogs = results.length > 13 ? (results[13] as List<Map<String, dynamic>>?) ?? const [] : const [];
      
      // Build a map of doorId -> doorName from the doors list and raw Dahua logs
      final Map<int, String> doorIdToName = {};
      for (final d in doors) {
        final idRaw = d['id'] ?? d['accessId'] ?? d['access_id'];
        final int? dId = idRaw == null ? null : (idRaw is num ? idRaw.toInt() : int.tryParse(idRaw.toString()));
        final name = (d['accessName'] ?? d['name'] ?? '').toString().trim();
        if (dId != null && name.isNotEmpty) {
          doorIdToName[dId] = name;
        }
      }
      if (doorLogsRes != null && doorLogsRes['result'] != null) {
        final records = doorLogsRes['result']['records'];
        if (records is List) {
          for (final log in records) {
            if (log is Map) {
              final ch = int.tryParse(log['channel']?.toString() ?? '');
              final name = log['accessName']?.toString() ?? log['doorName']?.toString();
              if (ch != null && name != null && name.isNotEmpty) {
                doorIdToName[ch] = name;
              }
            }
          }
        }
      }

      for (final cLog in cpanelLogs) {
        final dId = int.tryParse(cLog['door_id']?.toString() ?? '');
        String doorName = 'Door $dId';
        if (dId != null && doorIdToName.containsKey(dId)) {
          doorName = doorIdToName[dId]!;
        }
        mergedLogs.add({
          'opTime': cLog['created_at'],
          'opUser': cLog['username'],
          'accessName': doorName,
          'channel': cLog['door_id'],
          'op': 1,
          'opType': 'Success', // Cpanel logs represent successful unlocks
        });
      }

      // Sort by time descending
      mergedLogs.sort((a, b) {
        final aTimeStr = a['opTime']?.toString() ?? a['time']?.toString() ?? '';
        final bTimeStr = b['opTime']?.toString() ?? b['time']?.toString() ?? '';
        final aTime = DateTime.tryParse(aTimeStr)?.millisecondsSinceEpoch ?? 0;
        final bTime = DateTime.tryParse(bTimeStr)?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      recentDoorLogs = mergedLogs;

      lastUpdatedUtc = DateTime.now().toUtc();

      // Keep a global flag for other UI layers that rely on it.
      AppConstants.hasCriticalBanner = hasCriticalBanner;

      // Adaptive polling: switch to fast polling during emergencies.
      _applyEmergencyMode(_computeEmergencyMode());
      notifyListeners();
    } catch (e) {
      AppLog.d('[GlobalStatusPoller] fetch failed: $e');
    } finally {
      _inFlight = false;
    }
  }

}
