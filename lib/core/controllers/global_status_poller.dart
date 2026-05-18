import 'dart:async';

import 'package:flutter/widgets.dart';

import '../constants/app_constants.dart';
import '../controllers/smart_polling_settings.dart';
import '../network/api_service.dart';
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

  Future<void> fetchNow() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final results = await Future.wait([
        ApiService.instance.fetchEnvironment(),
        ApiService.instance.fetchDeviceStatus(),
        ApiService.instance.fetchSysInfo(),
        ApiService.instance.fetchRecentAlarms(),
      ]);

      final env = results[0];
      final ds = results[1];
      final si = results[2];
      final ra = results[3];

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
      }

      if (ra != null && ra['result'] != null) {
        recentAlarms = (ra['result'] as List?)?.toList() ?? recentAlarms;
      }

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
