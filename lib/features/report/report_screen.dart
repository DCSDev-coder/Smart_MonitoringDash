import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/navigation/app_navigator.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/config/site_runtime_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/constants/app_constants.dart';
import '../../core/controllers/global_status_poller.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/alarm_payload.dart';

import 'dart:ui' as ui;
import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/header_refresh_bar.dart';
import '../../shared/utils/pull_to_refresh_gate.dart';
import '../dashboard/widgets/dashboard_typography.dart';
import '../../shared/utils/app_toast.dart';

part 'report_screen_navigation.dart';
part 'report_screen_health_security.dart';

class ReportScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool isActive;

  const ReportScreen({
    super.key,
    this.initialTabIndex = 0,
    this.isActive = true,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with TickerProviderStateMixin {
  static const List<String> _eventRangeOptions = <String>[
    'Recent',
    'Weekly',
    'Monthly',
  ];

  int _selectedTabIndex = 0;

  bool _loading = true;
  bool _refreshing = false;
  RefreshIndicatorStatus? _refreshStatus;
  final PullToRefreshGate _refreshGate = PullToRefreshGate();
  Map<String, double> _powerMonth = {};
  List<dynamic> _devices = [];
  List<dynamic> _reportAlarms = [];
  List<dynamic> _doorLogs = [];
  bool _fetchingHistoricalEvents = false;
  bool _fetchingDoorLogs = false;
  String _eventLogRange = 'Recent'; // Recent, Weekly, Monthly, All

  // Historical Energy Analytics state
  List<FlSpot> _totalPowerSpots = [];
  List<FlSpot> _itPowerSpots = [];
  List<FlSpot> _pueSpots = [];
  List<String> _totalPowerLabels = [];
  List<String> _itPowerLabels = [];
  List<String> _pueLabels = [];
  String _totalPowerRange = '24H';
  String _itPowerRange = '24H';
  String _otherPowerRange = '24H';

  // Analytics State
  int _smokeStatus = -1; // -1 means sensor not discovered yet
  int _floodStatus = -1;
  DateTime? _lastMaintenance;
  int? _siteId;
  int _adapterMissStreak = 0;
  bool get _showAdapterDegraded => _adapterMissStreak >= 2;

  late final AnimationController _tabSelC;
  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _fetchReportData();
    }
  }

  @override
  void initState() {
    super.initState();
    // Allow external deep-links (e.g. Dashboard service card) to open directly on
    // the maintenance logistics page.
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 2);
    _tabSelC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: _selectedTabIndex.toDouble(),
      upperBound: 2.0,
    );
    _poller.addListener(_syncFromPoller);
    GlobalEventBus.targetHistoricalAlarm.addListener(_onTargetAlarmChanged);
    GlobalEventBus.targetMaintenancePage
        .addListener(_onTargetMaintenanceChanged);
    _syncFromPoller();
    _fetchReportData();
    _onTargetAlarmChanged();
    _onTargetMaintenanceChanged();
  }

  void _onTargetMaintenanceChanged() {
    if (GlobalEventBus.targetMaintenancePage.value) {
      if (_selectedTabIndex != 1) {
        _selectTab(1);
      }
      GlobalEventBus.targetMaintenancePage.value = false;
    }
  }

  void _onTargetAlarmChanged() {
    if (GlobalEventBus.targetHistoricalAlarm.value != null) {
      if (_selectedTabIndex != 1) {
        _selectTab(1);
      }
    }
  }

  @override
  void dispose() {
    _poller.removeListener(_syncFromPoller);
    GlobalEventBus.targetHistoricalAlarm.removeListener(_onTargetAlarmChanged);
    GlobalEventBus.targetMaintenancePage
        .removeListener(_onTargetMaintenanceChanged);
    _tabSelC.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncFromPoller() {
    if (!mounted) return;
    setState(() {
      _devices = _poller.devices;
      _smokeStatus = _poller.smokeStatus;
      _floodStatus = _poller.floodStatus;
    });
  }

  void _selectTab(int index) {
    if (index == _selectedTabIndex) return;
    setState(() => _selectedTabIndex = index);
    _tabSelC.animateTo(
      index.toDouble(),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isAdapterReady(int? siteId) =>
      AdapterApiService.instance.isConfigured && siteId != null;

  bool _canUseDirectFallback(int? siteId) =>
      !_isAdapterReady(siteId) || ApiService.instance.canUseDirectFallback;

  bool _shouldUseAdapter(int? siteId) =>
      _isAdapterReady(siteId) && !_showAdapterDegraded;

  Future<void> _fetchReportData({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _loading = true);
    try {
      final site = CpanelApiService.instance.currentSite;
      final siteId = SiteRuntimeConfig.siteId(site);
      final cabinetId = SiteRuntimeConfig.cabinetId(site);
      final adapterReady = _isAdapterReady(siteId);

      Future<Map<String, dynamic>?> fetchPowerMonth() async {
        if (adapterReady) {
          final adapterData =
              await AdapterApiService.instance.fetchPowerMonth(siteId: siteId!);
          if (adapterData != null) return adapterData;
          if (!_canUseDirectFallback(siteId)) return null;
        }
        return ApiService.instance.fetchPowerMonth(id: cabinetId);
      }

      Future<Map<String, dynamic>?> fetchRecentAlarms() async {
        if (adapterReady) {
          final adapterData = await AdapterApiService.instance
              .fetchRecentAlarms(siteId: siteId!);
          if (adapterData != null) return adapterData;
          if (!_canUseDirectFallback(siteId)) return null;
        }
        return ApiService.instance.fetchAlarmsByLevel();
      }

      Future<Map<String, dynamic>?> fetchSysInfo() async {
        if (adapterReady) {
          final adapterData =
              await AdapterApiService.instance.fetchSysInfo(siteId: siteId!);
          if (adapterData != null) return adapterData;
          if (!_canUseDirectFallback(siteId)) return null;
        }
        return ApiService.instance.fetchSysInfo();
      }

      final results = await Future.wait([
        fetchPowerMonth(),
        fetchRecentAlarms(),
        fetchSysInfo(),
      ]);

      if (adapterReady) {
        final adapterMiss =
            results[0] == null || results[1] == null || results[2] == null;
        if (adapterMiss) {
          _adapterMissStreak += 1;
        } else {
          _adapterMissStreak = 0;
        }
      } else {
        _adapterMissStreak = 0;
      }

      if (mounted) {
        setState(() {
          final pm = results[0];
          if (pm != null && pm['result'] is Map) {
            _powerMonth = (pm['result'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
            );
          } else {
            // System down or disconnected; clear stale data.
            _powerMonth = {};
          }

          // 7. Load Cpanel Site Info
          if (site != null) {
            _siteId = siteId;
            if (site['last_maintenance'] != null) {
              _lastMaintenance = DateTime.tryParse(site['last_maintenance']);
            }
          }
          if (showSkeleton) _loading = false;
        });
      }
      if (showSkeleton && mounted) setState(() => _loading = false);
    } catch (e) {
      AppLog.w('Fetch error', tag: 'ReportScreen', error: e);
      if (showSkeleton && mounted) setState(() => _loading = false);
    }
    // 8. Health/Historical should show something immediately; default is "Today".
    await Future.wait([
      _refreshEventData(),
      _fetchEnergyHistory(),
    ]);
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    _refreshGate.beginRefresh();
    setState(() => _refreshing = true);
    try {
      // Refresh without blanking the page; we keep the current content visible
      // and overlay skeletons in the build method.
      await _fetchReportData(showSkeleton: false);
    } finally {
      _refreshGate.endRefresh();
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _onRefreshStatusChanged(RefreshIndicatorStatus? status) {
    if (!mounted || _refreshStatus == status) return;
    setState(() => _refreshStatus = status);
  }

  bool get _showRefreshBar =>
      _refreshing ||
      _refreshStatus == RefreshIndicatorStatus.drag ||
      _refreshStatus == RefreshIndicatorStatus.armed ||
      _refreshStatus == RefreshIndicatorStatus.snap ||
      _refreshStatus == RefreshIndicatorStatus.refresh;

  Future<void> _refreshEventData() {
    // Prefer a single report bundle call when adapter is configured.
    return _fetchReportBundleOrFallback();
  }

  Future<void> _fetchReportBundleOrFallback() async {
    final now = DateTime.now();
    final int startTime = _eventRangeStartFor(now);
    final int endTime = now.millisecondsSinceEpoch;

    final siteId = SiteRuntimeConfig.siteId(
      CpanelApiService.instance.currentSite,
    );

    if (_shouldUseAdapter(siteId)) {
      final sid = siteId!;
      if (!mounted) return;
      setState(() {
        _fetchingHistoricalEvents = true;
        _fetchingDoorLogs = true;
      });
      try {
        final bundle = await AdapterApiService.instance.fetchReportBundle(
          siteId: sid,
          startTime: startTime,
          endTime: endTime,
          page: 1,
          pageSize: 20,
        );

        if (bundle != null && mounted) {
          _adapterMissStreak = 0;
          setState(() {
            final ra = bundle['reportAlarms'];
            final al = bundle['accessLogs'];
            final dynamic raResult = (ra is Map) ? ra['result'] : null;
            final dynamic raRecords =
                (raResult is Map) ? raResult['records'] : null;
            final List<dynamic> rawAlarms =
                (raRecords is List) ? raRecords : [];

            _reportAlarms = rawAlarms.where((alarm) {
              final timeStr = (alarm['happenTime'] ??
                      alarm['happen_time'] ??
                      alarm['alarmTime'])
                  ?.toString();
              if (timeStr == null || timeStr.trim().isEmpty) return true;
              final dt = DateTime.tryParse(timeStr);
              if (dt == null) return true;
              final ms = dt.millisecondsSinceEpoch;
              return ms >= startTime && ms <= endTime;
            }).toList();

            final dynamic logsResult = (al is Map ? al['result'] : null);
            final rawLogs = _extractAccessLogRows(logsResult);

            _doorLogs = rawLogs.where((log) {
              final timeStr = log['opTime']?.toString() ?? '';
              final dt = DateTime.tryParse(timeStr);
              if (dt == null) return true;
              final ms = dt.millisecondsSinceEpoch;
              if (ms < startTime || ms > endTime) return false;

              final u = (log['opUser'] ??
                          log['openUser'] ??
                          log['userName'] ??
                          log['username'])
                      ?.toString()
                      .toLowerCase() ??
                  '';
              final bool isResolvedIdentity = log['is_intercepted'] == true ||
                  log['matched_event_id'] != null ||
                  log['matched_user_id'] != null ||
                  (log['event_source']?.toString().trim().isNotEmpty ?? false);
              if (!isResolvedIdentity &&
                  (u == 'superadmin' || u == 'admin' || u == 'remote open')) {
                return false;
              }
              return true;
            }).toList();

            _fetchingHistoricalEvents = false;
            _fetchingDoorLogs = false;
          });
        } else {
          _adapterMissStreak += 1;
          AppLog.w(
            'Adapter report bundle returned null/invalid payload',
            tag: 'ReportScreen',
            fields: {'siteId': siteId},
          );
          if (mounted) {
            setState(() {
              _fetchingHistoricalEvents = false;
              _fetchingDoorLogs = false;
            });
          }
          if (_showAdapterDegraded) {
            await Future.wait([
              _fetchHistoricalEvents(),
              _fetchDoorLogs(),
            ]);
          }
        }
      } catch (e) {
        _adapterMissStreak += 1;
        AppLog.w('Report bundle fetch error', tag: 'ReportScreen', error: e);
        if (mounted) {
          setState(() {
            _fetchingHistoricalEvents = false;
            _fetchingDoorLogs = false;
          });
        }
        if (_showAdapterDegraded) {
          await Future.wait([
            _fetchHistoricalEvents(),
            _fetchDoorLogs(),
          ]);
        }
      }
      return;
    }

    AppLog.i(
      'Using direct fallback for report events because adapter is not configured',
      tag: 'ReportScreen',
      fields: {'siteId': siteId},
    );
    // Fallback: legacy 2 calls only when adapter is not configured.
    await Future.wait([
      _fetchHistoricalEvents(),
      _fetchDoorLogs(),
    ]);

    if (mounted) {
      AppToast.setReconnecting(context, _showAdapterDegraded);
    }
  }

  void _setEventLogRange(String value) {
    if (value == _eventLogRange) return;
    setState(() => _eventLogRange = value);
    _refreshEventData();
  }

  void _applyMaintenanceDate(DateTime picked, String dateStr) {
    setState(() {
      _lastMaintenance = picked;
      if (CpanelApiService.instance.currentSite != null) {
        CpanelApiService.instance.currentSite!['last_maintenance'] = dateStr;
      }
    });
  }

  List<dynamic> _extractAccessLogRows(dynamic resultData) {
    if (resultData is List) {
      return resultData;
    }
    if (resultData is Map) {
      final pageData = resultData['pageData'];
      if (pageData is List) {
        return pageData;
      }
      final records = resultData['records'];
      if (records is List) {
        return records;
      }
    }
    return const [];
  }

  int _eventRangeStartFor(DateTime now) {
    switch (_eventLogRange) {
      case 'Recent':
        // Show last 3 days of events to catch unresolved alarms from yesterday
        return now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      case 'Monthly':
        return now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      case 'Weekly':
      default:
        return now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    }
  }

  Future<void> _fetchHistoricalEvents() async {
    if (!mounted) return;
    setState(() => _fetchingHistoricalEvents = true);
    try {
      final now = DateTime.now();
      final int startTime = _eventRangeStartFor(now);
      final int endTime = now.millisecondsSinceEpoch;

      final siteId = SiteRuntimeConfig.siteId(
        CpanelApiService.instance.currentSite,
      );

      Map<String, dynamic>? res;
      if (_shouldUseAdapter(siteId)) {
        final sid = siteId!;
        res = await AdapterApiService.instance.fetchReportAlarms(
          siteId: sid,
          startTime: startTime,
          endTime: endTime,
          page: 1,
          pageSize: 20,
        );
        if (res == null) {
          _adapterMissStreak += 1;
        } else {
          _adapterMissStreak = 0;
        }
      }

      if (!_shouldUseAdapter(siteId)) {
        if (!_canUseDirectFallback(siteId)) {
          if (mounted) setState(() => _fetchingHistoricalEvents = false);
          return;
        }
        res ??= await ApiService.instance
            .fetchReportAlarms(startTime: startTime, endTime: endTime);
      }

      if (mounted) {
        setState(() {
          _reportAlarms = (res?['result']?['records'] as List?) ?? [];
          _fetchingHistoricalEvents = false;
        });
      }
    } catch (e) {
      AppLog.w('Event fetch error', tag: 'ReportScreen', error: e);
      if (mounted) setState(() => _fetchingHistoricalEvents = false);
    }
  }

  Future<void> _fetchDoorLogs() async {
    if (!mounted) return;
    setState(() => _fetchingDoorLogs = true);
    try {
      final now = DateTime.now();
      final int startTime = _eventRangeStartFor(now);
      final int endTime = now.millisecondsSinceEpoch;

      final siteId = SiteRuntimeConfig.siteId(
        CpanelApiService.instance.currentSite,
      );

      Map<String, dynamic>? res;
      List<Map<String, dynamic>> cpanelLogs = [];

      if (_shouldUseAdapter(siteId)) {
        final sid = siteId!;
        res = await AdapterApiService.instance.fetchAccessLogs(
          siteId: sid,
          startTime: startTime,
          endTime: endTime,
          accessType: '1',
        );
      }

      if (!_shouldUseAdapter(siteId)) {
        if (!_canUseDirectFallback(siteId)) {
          if (mounted) setState(() => _fetchingDoorLogs = false);
          return;
        }
        res ??= await ApiService.instance.fetchDoorAccessLogs(
          accessType: '1',
        );
      }

      if (!_shouldUseAdapter(siteId) && siteId != null) {
        cpanelLogs = await CpanelApiService.instance.fetchRemoteAccessLogs(
          siteId: siteId,
          startTime:
              startTime, // We still pass these, but the backend now ignores them safely
          endTime: endTime,
        );
      }

      Map<String, dynamic>? doorsRes;
      try {
        if (_shouldUseAdapter(siteId)) {
          doorsRes =
              await AdapterApiService.instance.fetchDoors(siteId: siteId!);
        }
        if (doorsRes == null && _canUseDirectFallback(siteId)) {
          final cabinetId = SiteRuntimeConfig.cabinetId(
              CpanelApiService.instance.currentSite);
          final parsed = int.tryParse(cabinetId ?? '');
          doorsRes = await ApiService.instance
              .fetchCabinetDoors(cabinetId: parsed ?? 1);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          final dynamic resultData = res?['result'];
          final rawLogs = _extractAccessLogRows(resultData);

          final Map<int, String> doorNames = {};
          for (final log in rawLogs) {
            final ch = int.tryParse(log['channel']?.toString() ?? '');
            final name = log['accessName']?.toString();
            if (ch != null && name != null && name.isNotEmpty) {
              doorNames[ch] = name;
            }
          }

          // The direct API doesn't support time filtering for access logs,
          // so we filter them on the client side.
          _doorLogs = rawLogs.where((log) {
            final timeStr = log['opTime']?.toString() ?? '';
            final dt = DateTime.tryParse(timeStr);
            if (dt == null) return true; // keep if invalid format
            final ms = dt.millisecondsSinceEpoch;
            if (ms < startTime || ms > endTime) return false;

            final u = (log['opUser'] ??
                        log['openUser'] ??
                        log['userName'] ??
                        log['username'])
                    ?.toString()
                    .toLowerCase() ??
                '';
            final bool isResolvedIdentity = log['is_intercepted'] == true ||
                log['matched_event_id'] != null ||
                log['matched_user_id'] != null ||
                (log['event_source']?.toString().trim().isNotEmpty ?? false);
            if (!isResolvedIdentity &&
                (u == 'superadmin' || u == 'admin' || u == 'remote open')) {
              return false; // Remove only raw generic Dahua remote unlock logs.
            }
            return true;
          }).toList();

          final Map<int, String> synthesizedDoorNames = {};
          if (doorsRes != null) {
            final raw = doorsRes['result'];
            final List cabinets = raw is List
                ? raw
                : (raw is Map
                    ? ((raw['list'] as List?) ??
                        (raw['data'] as List?) ??
                        const [])
                    : const []);
            final List<Map<String, dynamic>> tempDoors = [];

            for (final cabinet in cabinets) {
              if (cabinet is! Map) continue;
              final details = (cabinet['detailList'] as List?) ??
                  (cabinet['detail_list'] as List?) ??
                  (cabinet['accessList'] as List?) ??
                  (cabinet['doorList'] as List?) ??
                  const [];

              for (final door in details) {
                if (door is! Map) continue;
                final dynamic idRaw =
                    door['id'] ?? door['accessId'] ?? door['access_id'];
                final int? dId = idRaw == null
                    ? null
                    : (idRaw is num
                        ? idRaw.toInt()
                        : int.tryParse(idRaw.toString()));
                if (dId == null) continue;

                final rawDoor = (door['accessName'] ?? door['name'] ?? '')
                    .toString()
                    .trim();
                final doorSide =
                    rawDoor.toUpperCase().contains('FRONT') ? 'Front' : 'Back';

                final rawCab = cabinet['cabinetItemName']?.toString() ?? '';
                final cabNumText = RegExp(r'\d+').firstMatch(rawCab)?.group(0);
                final cabIndex = int.tryParse(cabNumText ?? '');

                tempDoors.add({
                  'id': dId,
                  'side': doorSide,
                  'cabIndex': cabIndex,
                });
              }
            }

            tempDoors.sort((a, b) {
              final sideA = a['side']?.toString().toLowerCase() ?? '';
              final sideB = b['side']?.toString().toLowerCase() ?? '';
              if (sideA == 'front' && sideB == 'back') return -1;
              if (sideA == 'back' && sideB == 'front') return 1;

              final cabA =
                  (a['cabIndex'] is int) ? (a['cabIndex'] as int) : null;
              final cabB =
                  (b['cabIndex'] is int) ? (b['cabIndex'] as int) : null;
              if (cabA != null && cabB != null) return cabA.compareTo(cabB);
              if (cabA != null) return -1;
              if (cabB != null) return 1;
              return (a['id'] as int).compareTo(b['id'] as int);
            });

            int front = 0;
            int back = 0;
            for (final d in tempDoors) {
              final side = d['side']?.toString().toLowerCase();
              if (side == 'front') {
                front += 1;
                synthesizedDoorNames[d['id'] as int] = 'Front $front';
              } else {
                back += 1;
                synthesizedDoorNames[d['id'] as int] = 'Back $back';
              }
            }
          }

          for (final cLog in cpanelLogs) {
            final dId = int.tryParse(cLog['door_id']?.toString() ?? '');

            String doorName = 'Door $dId';
            if (dId != null) {
              if (synthesizedDoorNames.containsKey(dId)) {
                doorName = synthesizedDoorNames[dId]!;
              } else if (doorNames.containsKey(dId)) {
                doorName = doorNames[dId]!;
              }
            }

            _doorLogs.add({
              'opTime': cLog['created_at'],
              'opUser': cLog['username'],
              'accessName': doorName,
              'channel': cLog['door_id'],
              'op': 1,
            });
          }

          _doorLogs.sort((a, b) {
            final aTime = DateTime.tryParse(a['opTime']?.toString() ?? '')
                    ?.millisecondsSinceEpoch ??
                0;
            final bTime = DateTime.tryParse(b['opTime']?.toString() ?? '')
                    ?.millisecondsSinceEpoch ??
                0;
            return bTime.compareTo(aTime);
          });
          _fetchingDoorLogs = false;
        });
      }
    } catch (e) {
      AppLog.w('Door fetch error', tag: 'ReportScreen', error: e);
      if (mounted) setState(() => _fetchingDoorLogs = false);
    }
  }

  Future<void> _fetchEnergyHistory() async {
    if (!mounted) return;

    try {
      final now = DateTime.now();
      final endTime = now.millisecondsSinceEpoch;
      // Fetch a full 24H window; UI selectors (8H/12H/24H) slice this series.
      final startTime =
          now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

      // 1. Fetch Production Energy Trends & PUE
      final site = CpanelApiService.instance.currentSite;
      final siteId = SiteRuntimeConfig.siteId(
        CpanelApiService.instance.currentSite,
      );

      Future<Map<String, dynamic>?> fetchPueWithFallback(
          {required int? siteId}) async {
        final cabinetId = SiteRuntimeConfig.cabinetId(site);

        if (_isAdapterReady(siteId)) {
          final adapterData =
              await AdapterApiService.instance.fetchPue(siteId: siteId!);
          if (adapterData != null) return adapterData;
          if (!_canUseDirectFallback(siteId)) return null;
        }
        // Legacy fallback expects a cabinet id (string), default to 1.
        return ApiService.instance.fetchPue(id: cabinetId ?? '1');
      }

      Future<Map<String, dynamic>?> fetchRangeWithFallback({
        required int nodeId,
        required String metricCode,
      }) async {
        if (_isAdapterReady(siteId)) {
          final adapterData = await AdapterApiService.instance.fetchRange(
            siteId: siteId!,
            nodeId: nodeId,
            metricCode: metricCode,
            startTime: startTime,
            endTime: endTime,
          );
          if (adapterData != null) return adapterData;
          if (!_canUseDirectFallback(siteId)) return null;
        }
        return ApiService.instance.fetchHistoricalData(
          nodeId: nodeId,
          metricCode: metricCode,
          startTime: startTime,
          endTime: endTime,
        );
      }

      final results = await Future.wait([
        fetchPueWithFallback(siteId: siteId),
        // Prefer app_config node metric mapping, then fall back to known defaults.
        fetchRangeWithFallback(
          nodeId: 6,
          metricCode: SiteRuntimeConfig.metricCodeForNode(
            site,
            6,
            fallback: 'pdu_active_power_single_phase',
          ),
        ),
        fetchRangeWithFallback(
          nodeId: 7,
          metricCode: SiteRuntimeConfig.metricCodeForNode(
            site,
            7,
            fallback: 'active_power_single_phase',
          ),
        ),
      ]);

      if (mounted) {
        setState(() {
          _totalPowerSpots = [];
          _itPowerSpots = [];
          _pueSpots = [];
          _totalPowerLabels = [];
          _itPowerLabels = [];
          _pueLabels = [];

          bool hasRealHistory = false;

          List<Map<String, Object?>> parseRange(dynamic res) {
            final raw = (res is Map<String, dynamic>) ? res['result'] : null;
            if (raw is! List) return const [];
            final out = <Map<String, Object?>>[];
            for (final it in raw) {
              if (it is Map) {
                final v = it['value'];
                final t = it['time'];
                final val = (v is num) ? v.toDouble() : double.tryParse('$v');
                final time = t?.toString();
                if (val != null && time != null && time.isNotEmpty) {
                  out.add({'value': val, 'time': time});
                }
              }
            }
            return out;
          }

          // Total vs IT power series.
          // Adapter requests:
          // - results[1] range(nodeId=6, metricCode=pdu_active_power_single_phase) => Total power
          // - results[2] range(nodeId=7, metricCode=active_power_single_phase) => IT device power
          final totalSeries = parseRange(results[1]);
          final itSeries = parseRange(results[2]);

          if (totalSeries.isNotEmpty || itSeries.isNotEmpty) {
            final totalByTime = <String, double>{};
            for (final pt in totalSeries) {
              final t = pt['time'] as String;
              final v = pt['value'] as double;
              totalByTime[t] = v;
            }

            final itByTime = <String, double>{};
            for (final pt in itSeries) {
              final t = pt['time'] as String;
              final v = pt['value'] as double;
              itByTime[t] = v;
            }

            final times = <String>{...totalByTime.keys, ...itByTime.keys}
                .toList()
              ..sort();
            if (times.isNotEmpty) {
              hasRealHistory = true;
              for (int i = 0; i < times.length; i++) {
                final t = times[i];
                // Backend values are typically W; convert to kW for display.
                final totalKw = (totalByTime[t] ?? 0) / 1000.0;
                final itKw = (itByTime[t] ?? 0) / 1000.0;
                _totalPowerSpots.add(FlSpot(i.toDouble(), totalKw));
                _itPowerSpots.add(FlSpot(i.toDouble(), itKw));
                _totalPowerLabels.add(t);
                _itPowerLabels.add(t);
              }
            }
          }

          // B. PUE stability: use current PUE value as a flat line over the selected range.
          final pueRes = (results[0] is Map<String, dynamic>)
              ? results[0] as Map<String, dynamic>
              : null;
          if (pueRes != null) {
            // Adapter shape:
            // { pueStatus, pue, vendorPue, ... }
            // Legacy shape:
            // { result: { pue | pueValue, power } }
            final dynamic topLevelSystemPue = pueRes['pue'];
            final dynamic topLevelVendorPue = pueRes['vendorPue'];
            final dynamic legacy = pueRes['result'];
            final dynamic legacyPue =
                legacy is Map ? (legacy['pue'] ?? legacy['pueValue']) : null;
            final dynamic resolvedVendor =
                topLevelVendorPue ?? topLevelSystemPue ?? legacyPue;
            final vendorPueVal = resolvedVendor is num
                ? resolvedVendor.toDouble()
                : double.tryParse(resolvedVendor?.toString() ?? '');
            final pueVal = vendorPueVal;

            if (pueVal != null && pueVal > 0) {
              hasRealHistory = true;
              // Align points to totalPower labels if we have them.
              final n =
                  _totalPowerLabels.isNotEmpty ? _totalPowerLabels.length : 1;
              for (int i = 0; i < n; i++) {
                _pueSpots.add(FlSpot(i.toDouble(), pueVal));
                _pueLabels.add(_totalPowerLabels.isNotEmpty
                    ? _totalPowerLabels[i]
                    : 'Now');
              }
            } else {
              AppLog.w(
                'PUE payload present but no valid PUE value',
                tag: 'EnergyHistory',
                fields: {
                  'keys': pueRes.keys.toList(),
                  'pueStatus': pueRes['pueStatus'],
                  'rawPue': topLevelSystemPue,
                  'rawVendorPue': pueRes['vendorPue'],
                },
              );
            }
          }

          // C. FOLLBACK REMOVED
          if (!hasRealHistory) {
            AppLog.d(
                '[EnergyHistory] History empty. No fallback data generated per user request. Chart will remain empty until real data is available.');
          }
        });
      }
    } catch (e) {
      AppLog.w('Production fetch error', tag: 'EnergyHistory', error: e);
    }
  }

  static int _hoursForRange(String range) {
    switch (range.trim().toUpperCase()) {
      case '4H':
        return 4;
      case '8H':
        return 8;
      case '12H':
        return 12;
      case '24H':
      default:
        return 24;
    }
  }

  Widget _buildLoadingView(BuildContext context) {
    final hPadding = AppSpacing.pageHorizontal(context);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            hPadding,
            AppConstants.headerClearance(context),
            hPadding,
            AppSpacing.pageBottom(context),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.sectionGapSm),
              _ReportSkeletonCard(),
              SizedBox(height: AppSpacing.cardGap),
              _ReportSkeletonCard(),
              SizedBox(height: AppSpacing.cardGap),
              _ReportSkeletonCard(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildLoadingView(context);
    }

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final uiScale =
        screenWidth >= 900 ? (screenWidth / 1150).clamp(1.0, 1.25) : 1.0;

    final totalPower = _powerMonth['Total'] ?? 0.0;

    // Calculate true physical device counts (Fully Dynamic Discovery)
    int siteCount = 0;
    int siteOnline = 0;
    if (_smokeStatus != -1) {
      siteCount++;
      if (_smokeStatus == 0) siteOnline++;
    }
    if (_floodStatus != -1) {
      siteCount++;
      if (_floodStatus == 0) siteOnline++;
    }

    final totalPhysicalDevices = _devices.fold<int>(
            0, (sum, d) => sum + (d['totalCount'] as int? ?? 0)) +
        siteCount;
    final onlinePhysicalDevices = _devices.fold<int>(
            0, (sum, d) => sum + (d['normalCount'] as int? ?? 0)) +
        siteOnline;

    final healthScore = totalPhysicalDevices == 0
        ? 100
        : (onlinePhysicalDevices / totalPhysicalDevices * 100).toInt();

    final hPadding = AppSpacing.pageHorizontal(context);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _refreshGate.handleNotification,
                child: RefreshIndicator.noSpinner(
                  triggerMode: RefreshIndicatorTriggerMode.onEdge,
                  notificationPredicate: _refreshGate.shouldProcess,
                  onRefresh: _onRefresh,
                  onStatusChange: _onRefreshStatusChanged,
                  child: CustomScrollView(
                    controller: _scrollController,
                    // Avoid iOS-style "rubber band" overscroll that can feel like infinite
                    // scrolling, while still allowing pull-to-refresh even when content is
                    // shorter than the viewport.
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      // 1. Dynamic Header Clearance (Scrollable)
                      SliverToBoxAdapter(
                        child: SizedBox(
                            height: AppConstants.headerClearance(context)),
                      ),

                      // 2. Custom Navigation
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPadding),
                          child: const SizedBox.shrink(),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPadding),
                          child: _buildCustomNavButtons(),
                        ),
                      ),

                      // 3. Tab Content
                      // We use Visibility with maintainState: true but maintainSize: false
                      // instead of IndexedStack. This allows the scroll boundary to
                      // shrink/grow to fit only the active page, while still keeping the
                      // inactive page's charts alive for the PDF capture process.
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            if (!_loading)
                              Column(
                                children: [
                                  const SizedBox(
                                      height: AppSpacing.sectionGapSm),
                                  Visibility(
                                    visible: _selectedTabIndex == 0,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    maintainSize: false,
                                    child: _buildEnergyPage(
                                        hPadding,
                                        totalPower,
                                        healthScore,
                                        onlinePhysicalDevices,
                                        totalPhysicalDevices,
                                      ),
                                  ),
                                  Visibility(
                                    visible: _selectedTabIndex == 1,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    maintainSize: false,
                                    child: _buildMaintenancePage(hPadding),
                                  ),
                                  Visibility(
                                    visible: _selectedTabIndex == 2,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    maintainSize: false,
                                    child: _buildSecurityPage(hPadding),
                                  ),
                                ],
                              ),
                            if ((_loading || _refreshing) &&
                                _selectedTabIndex != 2)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: SingleChildScrollView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: hPadding),
                                      child: const Column(
                                        children: [
                                          SizedBox(
                                              height: AppSpacing.sectionGapSm),
                                          _ReportSkeletonCard(),
                                          SizedBox(height: AppSpacing.cardGap),
                                          _ReportSkeletonCard(),
                                          SizedBox(height: AppSpacing.cardGap),
                                          _ReportSkeletonCard(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Bottom padding
                      SliverToBoxAdapter(
                        child: SizedBox(
                          // Keep the last card (PUE Stability) as the natural end of the
                          // scroll, while still leaving enough room for the floating
                          // bottom nav on phones.
                          height: AppSpacing.pageBottom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            HeaderRefreshBar(
              visible: _showRefreshBar,
              top: AppConstants.headerClearance(context) - 6,
              horizontalInset: hPadding,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyPage(
    double hPadding,
    double totalPower,
    int healthScore,
    int onlineDevices,
    int totalDevices,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktopWide = width >= 1100;
    final isTablet = width >= 650 && width < 1100;

    final double? pmTotal = _powerMonth['Total'];
    final double? pmIt = _powerMonth['IT Device'];
    final double? pmOther = _powerMonth['Other'];

    final slicedTotal = _sliceSeriesForRange(
        _totalPowerSpots, _totalPowerLabels, _totalPowerRange);
    final slicedIt =
        _sliceSeriesForRange(_itPowerSpots, _itPowerLabels, _itPowerRange);
    final slicedOther = _sliceSeriesForRange(
      List.generate(
        math.min(_totalPowerSpots.length, _itPowerSpots.length),
        (i) => FlSpot(_totalPowerSpots[i].x,
            math.max(0, _totalPowerSpots[i].y - _itPowerSpots[i].y)),
      ),
      _totalPowerLabels,
      _otherPowerRange,
    );

    final summaryCard = _buildSummaryCard(
      healthScore,
      onlineDevices: onlineDevices,
      totalDevices: totalDevices,
    );

    final totalPowerCard = _sparklineCard(
      title: 'Total Power',
      subtitle: 'Facility Infeed',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF00E5FF),
      valueText: pmTotal == null ? 'Offline' : pmTotal.toStringAsFixed(2),
      spots: slicedTotal.spots,
      labels: slicedTotal.labels,
      currentRange: _totalPowerRange,
      onRangeChanged: (r) => setState(() => _totalPowerRange = r),
    );

    final itDevicesCard = _sparklineCard(
      title: 'IT Devices',
      subtitle: 'Active Compute Load',
      icon: Icons.dns_rounded,
      color: const Color(0xFF3B82F6),
      valueText: pmIt == null ? 'Offline' : pmIt.toStringAsFixed(2),
      spots: slicedIt.spots,
      labels: slicedIt.labels,
      currentRange: _itPowerRange,
      onRangeChanged: (r) => setState(() => _itPowerRange = r),
    );

    final coolingCard = _sparklineCard(
      title: 'Other/Cooling',
      subtitle: 'Losses & Chillers',
      icon: Icons.ac_unit_rounded,
      color: const Color(0xFFF59E0B),
      valueText: pmOther == null ? 'Offline' : pmOther.toStringAsFixed(2),
      spots: slicedOther.spots,
      labels: slicedOther.labels,
      currentRange: _otherPowerRange,
      onRangeChanged: (r) => setState(() => _otherPowerRange = r),
    );

    final distributionCard = _buildEnergyDistributionCard(
      pmTotal: pmTotal,
      pmIt: pmIt,
      pmOther: pmOther,
    );

    return Padding(
      // Let the global bottom nav / safe area handle spacing.
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      child: Column(
        children: [
          if (isDesktopWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: summaryCard,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: totalPowerCard,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: itDevicesCard,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: coolingCard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            distributionCard,
          ] else if (isTablet) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: summaryCard,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: totalPowerCard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: itDevicesCard,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 260,
                    child: coolingCard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            distributionCard,
          ] else ...[
            SizedBox(
              height: 260,
              child: summaryCard,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: totalPowerCard,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: itDevicesCard,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: coolingCard,
            ),
            const SizedBox(height: 14),
            distributionCard,
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    int score, {
    int onlineDevices = 0,
    int totalDevices = 0,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      tint: isLight ? Colors.white : null,
      borderColor: isLight ? AppTheme.lightStroke : const Color(0xFF1E2D3D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SITE HEALTH',
                        style: TextStyle(
                          color: isLight
                              ? AppTheme.lightTextPrimary
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Availability Index',
                        style: TextStyle(
                          color: isLight
                              ? AppTheme.lightTextSecondary
                              : const Color(0xFF8FA0B5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _infoIconButton(
                iconColor: isLight
                    ? AppTheme.lightTextSecondary.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.55),
                onTap: () => _showSiteHealthInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Ring Gauge Center
          Expanded(
            child: Center(
              child: _HealthGaugeRing(score: score),
            ),
          ),
          const SizedBox(height: 8),
          // Footer Status & Diagnostics
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      score >= 90
                          ? 'OPTIMAL HEALTH'
                          : (score >= 70 ? 'NORMAL OPERATION' : 'DEGRADED'),
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                totalDevices > 0
                    ? '$onlineDevices of $totalDevices monitored nodes normal'
                    : 'All systems operating within safe limits',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : const Color(0xFF8FA0B5),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<String> _coerceLabels(List<String> labels, int len) {
    if (labels.length == len) return labels;
    if (labels.isEmpty) return List.generate(len, (_) => '');
    if (labels.length > len) return labels.take(len).toList();
    final out = List<String>.from(labels);
    while (out.length < len) {
      out.add(out.last);
    }
    return out;
  }

  _SeriesSlice _sliceSeriesForRange(
    List<FlSpot> rawSpots,
    List<String> rawLabels,
    String range,
  ) {
    if (rawSpots.isEmpty) return const _SeriesSlice([], []);

    final hours = _hoursForRange(range);
    final total = rawSpots.length;

    // Assume raw series is roughly a 24H window. Keep points proportionally.
    var keep = math.max(2, ((total * hours) / 24.0).round());
    keep = math.min(keep, total);

    final start = math.max(0, total - keep);
    final spots = rawSpots.sublist(start);
    final labels =
        (rawLabels.length == total) ? rawLabels.sublist(start) : rawLabels;

    // For report charts we want roughly one value per hour, not every raw sample.
    // This keeps the charts responsive and avoids very wide, heavy 24H graphs.
    if (spots.length > hours) {
      final binSize = spots.length / hours;
      final outSpots = <FlSpot>[];
      final outLabels = <String>[];
      for (int h = 0; h < hours; h++) {
        final s0 = (h * binSize).floor();
        final s1 = ((h + 1) * binSize).floor().clamp(s0 + 1, spots.length);
        double sum = 0;
        for (int i = s0; i < s1; i++) {
          sum += spots[i].y;
        }
        final avg = sum / (s1 - s0);
        outSpots.add(FlSpot(h.toDouble(), avg));
        final labelIdx = math.min(labels.length - 1, s1 - 1);
        outLabels.add(labels.isEmpty ? '' : labels[labelIdx]);
      }
      return _SeriesSlice(outSpots, _coerceLabels(outLabels, outSpots.length));
    }

    final reindexed = List.generate(
      spots.length,
      (i) => FlSpot(i.toDouble(), spots[i].y),
    );

    return _SeriesSlice(reindexed, _coerceLabels(labels, reindexed.length));
  }

  void _showSiteHealthInfo(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      barrierLabel: 'Site Health Info',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              color: Colors.transparent,
              child: DashboardGlass(
                radius: 20,
                padding: const EdgeInsets.all(16),
                tint: isLight ? Colors.white : const Color(0xFF0B0F14),
                borderColor: isLight ? AppTheme.lightStroke : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SITE HEALTH INDEX',
                          style: bitcount(
                            context,
                            fontSize: 15,
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : const Color(0xFF80B4FF),
                            letterSpacing: 2,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isLight
                                ? AppTheme.lightTextSecondary
                                : Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A quick indicator of site availability based on how many discovered devices are currently reporting normally.',
                      style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white,
                          fontSize: 12,
                          height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    _infoBullet(
                      'Computed as: online devices / total discovered devices.',
                      isLight: isLight,
                    ),
                    _infoBullet(
                      'Includes infrastructure devices and on-site sensors when available.',
                      isLight: isLight,
                    ),
                    _infoBullet(
                      'If a device is offline or abnormal, the index will decrease.',
                      isLight: isLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: If the index drops, check Notifications or the Health tab to see which devices are affected.',
                      style: TextStyle(
                          color: isLight
                              ? AppTheme.lightTextSecondary
                              : Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                          height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ui.ImageFilter.blur(
              sigmaX: 12 * anim1.value, sigmaY: 12 * anim1.value),
          child: Transform.scale(
            scale: 0.8 + (0.2 * curve.value),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        );
      },
    );
  }

  static Widget _infoBullet(String text, {bool isLight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: Color(0xFF80B4FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoIconButton(
      {required Color iconColor, required VoidCallback onTap}) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: Icon(Icons.info_outline_rounded, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }

  Widget _sparklineCard({
    Key? key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String valueText,
    String unit = 'kW',
    required List<FlSpot> spots,
    List<String>? labels,
    required String currentRange,
    required ValueChanged<String> onRangeChanged,
  }) {
    // Determine bounds for chart
    double minY = 0.0;
    double maxY = 1.0;
    if (spots.isNotEmpty) {
      minY = spots.map((s) => s.y).reduce(math.min);
      maxY = spots.map((s) => s.y).reduce(math.max);
      if (minY == maxY) {
        maxY += 1;
        minY = math.max(0, minY - 1);
      } else {
        final diff = maxY - minY;
        maxY += diff * 0.1;
        minY = math.max(0, minY - diff * 0.1);
      }
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final bool isStandby = valueText == 'Offline' ||
        valueText == '0.0' ||
        valueText == '0.00' ||
        valueText == '0';

    return DashboardGlass(
      key: key,
      radius: 18,
      padding: const EdgeInsets.all(16),
      tint: isLight ? Colors.white : null,
      borderColor: isLight ? AppTheme.lightStroke : const Color(0xFF1E2D3D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.15),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextSecondary
                                  : const Color(0xFF8FA0B5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: onRangeChanged,
                color: isLight ? Colors.white : const Color(0xFF111922),
                itemBuilder: (context) => ['4H', '8H', '12H', '24H']
                    .map(
                      (option) => PopupMenuItem<String>(
                        value: option,
                        child: Text(
                          option,
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                child: DashboardGlass(
                  radius: 10,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  tint: isLight
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF0F1722),
                  borderColor: isLight
                      ? AppTheme.lightStroke
                      : const Color(0xFF1E2D3D),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentRange,
                        style: TextStyle(
                          color: isLight
                              ? AppTheme.lightTextPrimary
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Value & Status Pill Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isStandby ? '0.00' : valueText,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : const Color(0xFF8FA0B5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isStandby)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141C26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF223142)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 5,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF8FA0B5),
                          ),
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'STANDBY',
                        style: TextStyle(
                          color: Color(0xFF8FA0B5),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ONLINE',
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Chart Area
          Expanded(
            child: spots.length < 2
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TelemetryStandbyWavePainter(
                            color: color,
                            isLight: isLight,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.white.withValues(alpha: 0.85)
                              : const Color(0xFF0F1722).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLight
                                ? AppTheme.lightStroke
                                : const Color(0xFF1E2D3D),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sensors_rounded, size: 12, color: color),
                            const SizedBox(width: 5),
                            Text(
                              'Telemetry Active',
                              style: TextStyle(
                                color: isLight
                                    ? AppTheme.lightTextSecondary
                                    : Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      minX: spots.isNotEmpty ? spots.first.x : 0,
                      maxX: spots.isNotEmpty ? spots.last.x : 1,
                      lineTouchData: labels != null
                          ? LineTouchData(
                              enabled: true,
                              handleBuiltInTouches: true,
                              touchSpotThreshold: 28,
                              getTouchedSpotIndicator: (barData, spotIndexes) =>
                                  spotIndexes.map((index) {
                                return TouchedSpotIndicatorData(
                                  FlLine(
                                    color: color.withValues(alpha: 0.9),
                                    strokeWidth: 2.5,
                                  ),
                                  FlDotData(
                                    getDotPainter: (spot, percent, bar, index) =>
                                        FlDotCirclePainter(
                                      radius: 4.5,
                                      color: color,
                                      strokeWidth: 2,
                                      strokeColor: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                    ),
                                  ),
                                );
                              }).toList(),
                              touchTooltipData: LineTouchTooltipData(
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                showOnTopOfTheChartBoxArea: true,
                                tooltipRoundedRadius: 8,
                                tooltipMargin: 20,
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((touchedSpot) {
                                    final idx = touchedSpot.x
                                        .round()
                                        .clamp(0, labels.length - 1);
                                    final label = labels[idx];
                                    return LineTooltipItem(
                                      '$label\n${touchedSpot.y.toStringAsFixed(2)} $unit',
                                      TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            )
                          : const LineTouchData(enabled: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: math.max(0.1, (maxY - minY) / 3),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.06),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: labels != null
                          ? FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 20,
                                  interval: math.max(
                                      1, (spots.length / 4).floorToDouble()),
                                  getTitlesWidget: (value, meta) {
                                    final int idx = value.toInt();
                                    if (idx < 0 || idx >= labels.length) {
                                      return const SizedBox();
                                    }
                                    final timeStr = labels[idx];
                                    final parts = timeStr.split(' ');
                                    String timePart = parts.length > 1
                                        ? parts.last
                                        : timeStr;
                                    final timeTokens = timePart.split(':');
                                    if (timeTokens.length >= 2) {
                                      timePart =
                                          '${timeTokens[0]}:${timeTokens[1]}';
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        timePart,
                                        style: TextStyle(
                                          color: isLight
                                              ? AppTheme.lightTextSecondary
                                              : const Color(0xFF8FA0B5),
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          : const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: color,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.25),
                                color.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Divider(
            color: isLight ? AppTheme.lightStroke : const Color(0x1AFFFFFF),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 8),
          // Footer Stats
          Row(
            children: [
              Text(
                'MIN ',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : const Color(0xFF8FA0B5),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${minY.toStringAsFixed(2)} $unit',
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'MAX ',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : const Color(0xFF8FA0B5),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${maxY.toStringAsFixed(2)} $unit',
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyDistributionCard({
    required double? pmTotal,
    required double? pmIt,
    required double? pmOther,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final totalVal = (pmTotal != null && pmTotal > 0)
        ? pmTotal
        : ((pmIt ?? 0.0) + (pmOther ?? 0.0));
    final itVal = pmIt ?? 0.0;
    final otherVal = pmOther ?? (totalVal > itVal ? totalVal - itVal : 0.0);

    final double itPct =
        totalVal > 0 ? (itVal / totalVal).clamp(0.0, 1.0) : 0.70;
    final double otherPct = (1.0 - itPct).clamp(0.0, 1.0);
    final double pueEstimate =
        (itVal > 0 && totalVal > 0) ? (totalVal / itVal).clamp(1.0, 3.5) : 1.25;

    final isNarrow = MediaQuery.sizeOf(context).width < 650;

    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.all(20),
      tint: isLight ? Colors.white : null,
      borderColor: isLight ? AppTheme.lightStroke : const Color(0xFF1E2D3D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        size: 16,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FACILITY ENERGY ALLOCATION & LOAD DISTRIBUTION',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Dynamic power partitioning across computing infrastructure and cooling subsystems',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextSecondary
                                  : const Color(0xFF8FA0B5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PUE ~ ${pueEstimate.toStringAsFixed(2)} OPTIMAL',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Split Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: math.max(1, (itPct * 1000).toInt()),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF3B82F6).withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: math.max(1, (otherPct * 1000).toInt()),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 4 Metric Columns
          if (isNarrow)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _distributionMetricTile(
                        color: const Color(0xFF3B82F6),
                        title: 'IT COMPUTE LOAD',
                        value: '${itVal.toStringAsFixed(2)} kW',
                        subtitle:
                            '${(itPct * 100).toStringAsFixed(1)}% Active Payload',
                        isLight: isLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _distributionMetricTile(
                        color: const Color(0xFFF59E0B),
                        title: 'COOLING & LOSSES',
                        value: '${otherVal.toStringAsFixed(2)} kW',
                        subtitle:
                            '${(otherPct * 100).toStringAsFixed(1)}% Infrastructure',
                        isLight: isLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _distributionMetricTile(
                        color: const Color(0xFF00E5FF),
                        title: 'TOTAL INFEED',
                        value: '${totalVal.toStringAsFixed(2)} kW',
                        subtitle: 'Aggregated Demand',
                        isLight: isLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _distributionMetricTile(
                        color: const Color(0xFF10B981),
                        title: 'DESIGN PUE RATIO',
                        value: '${pueEstimate.toStringAsFixed(2)} PUE',
                        subtitle: 'Target < 1.40 Benchmark',
                        isLight: isLight,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _distributionMetricTile(
                    color: const Color(0xFF3B82F6),
                    title: 'IT COMPUTE LOAD',
                    value: '${itVal.toStringAsFixed(2)} kW',
                    subtitle:
                        '${(itPct * 100).toStringAsFixed(1)}% Active Payload',
                    isLight: isLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _distributionMetricTile(
                    color: const Color(0xFFF59E0B),
                    title: 'COOLING & LOSSES',
                    value: '${otherVal.toStringAsFixed(2)} kW',
                    subtitle:
                        '${(otherPct * 100).toStringAsFixed(1)}% Infrastructure',
                    isLight: isLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _distributionMetricTile(
                    color: const Color(0xFF00E5FF),
                    title: 'TOTAL INFEED',
                    value: '${totalVal.toStringAsFixed(2)} kW',
                    subtitle: 'Aggregated Demand',
                    isLight: isLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _distributionMetricTile(
                    color: const Color(0xFF10B981),
                    title: 'DESIGN PUE RATIO',
                    value: '${pueEstimate.toStringAsFixed(2)} PUE',
                    subtitle: 'Target < 1.40 Benchmark',
                    isLight: isLight,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _distributionMetricTile({
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    required bool isLight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0E1520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? AppTheme.lightStroke : const Color(0xFF1B2838),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : const Color(0xFF8FA0B5),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: isLight
                  ? AppTheme.lightTextSecondary
                  : const Color(0xFF8FA0B5),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AuraPill extends StatelessWidget {
  final Color color;

  const _AuraPill({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
    );
  }
}

class _MiniRing extends StatefulWidget {
  final Color color;
  final double progress; // 0..1
  final Color trackColor;
  final Widget child;

  const _MiniRing({
    required this.color,
    required this.progress,
    required this.trackColor,
    required this.child,
  });

  @override
  State<_MiniRing> createState() => _MiniRingState();
}

class _MiniRingState extends State<_MiniRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35);
    // Slightly larger base size so it reads better in the 3-column KPI layout.
    final size = 64.0 * scale;
    final stroke = 6.5 * scale;
    return SizedBox(
      width: size + 24,
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 12,
            height: size + 12,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF141A21).withValues(alpha: 0.65),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                color: widget.color,
                progress: widget.progress,
                stroke: stroke,
                trackColor: widget.trackColor,
                glow: true,
                gradientColors: _gradientFor(context, widget.color),
                gradientRotation: _c.value * math.pi * 2,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }

  static List<Color> _gradientFor(BuildContext context, Color base) {
    // Match the dashboard gauge feel: bright -> deep -> bright sweep.
    if (base.toARGB32() == const Color(0xFF3271D7).toARGB32()) {
      return const [
        Color(0xFF80B4FF),
        Color(0xFF3271D7),
        Color(0xFF1A3C71),
        Color(0xFF3271D7),
        Color(0xFF80B4FF),
      ];
    }
    // greens (Avg PUE / good)
    return [
      AppTheme.accentGreen,
      const Color(0xFF05A100),
      const Color(0xFF0B6B0A),
      AppTheme.accentGreen,
      AppTheme.accentGreen,
    ];
  }
}

class _HealthGaugeRing extends StatefulWidget {
  final int score;

  const _HealthGaugeRing({required this.score});

  @override
  State<_HealthGaugeRing> createState() => _HealthGaugeRingState();
}

class _HealthGaugeRingState extends State<_HealthGaugeRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final targetPct = (widget.score.clamp(0, 100)) / 100.0;
    _anim = Tween<double>(begin: 0.0, end: targetPct).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant _HealthGaugeRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      final oldPct = (oldWidget.score.clamp(0, 100)) / 100.0;
      final newPct = (widget.score.clamp(0, 100)) / 100.0;
      _anim = Tween<double>(begin: oldPct, end: newPct).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
      );
      _c.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    const stroke = 8.0;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final pct = _anim.value;
        final scoreVal = (pct * 100).round();

        final Color primaryColor = scoreVal >= 90
            ? const Color(0xFF10B981)
            : (scoreVal >= 70
                ? const Color(0xFF38BDF8)
                : const Color(0xFFF59E0B));

        final List<Color> gradient = scoreVal >= 90
            ? const [
                Color(0xFF34D399),
                Color(0xFF10B981),
                Color(0xFF059669),
                Color(0xFF10B981),
              ]
            : [
                primaryColor.withValues(alpha: 0.8),
                primaryColor,
                primaryColor.withValues(alpha: 0.6),
                primaryColor,
              ];

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(size),
                painter: _RingPainter(
                  color: primaryColor,
                  progress: pct,
                  stroke: stroke,
                  trackColor: isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : const Color(0x26FFFFFF),
                  glow: true,
                  gradientColors: gradient,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$scoreVal%',
                    style: TextStyle(
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'HEALTH',
                    style: TextStyle(
                      color: isLight
                          ? AppTheme.lightTextSecondary
                          : const Color(0xFF8FA0B5),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TelemetryStandbyWavePainter extends CustomPainter {
  final Color color;
  final bool isLight;

  const _TelemetryStandbyWavePainter({
    required this.color,
    this.isLight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // Draw subtle horizontal grid lines
    final gridPaint = Paint()
      ..color = (isLight ? Colors.black : Colors.white).withValues(alpha: 0.05)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h * 0.25), Offset(w, h * 0.25), gridPaint);
    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    canvas.drawLine(Offset(0, h * 0.75), Offset(w, h * 0.75), gridPaint);

    // Smooth pulse wave (Gaussian-enveloped damped sine wave)
    final path = Path();
    path.moveTo(0, midY);

    for (double x = 0; x <= w; x += 2) {
      final normX = (x / w) * 2.0 - 1.0; // -1 to 1
      final bell = math.exp(-normX * normX * 4.5); // Gaussian bell envelope
      final wave = math.sin(normX * math.pi * 5.0) * (h * 0.30) * bell;
      path.lineTo(x, midY - wave);
    }

    // Ambient glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Core stroke
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TelemetryStandbyWavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isLight != isLight;
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double stroke;
  final Color trackColor;
  final bool glow;
  final List<Color>? gradientColors;
  final double gradientRotation;

  _RingPainter({
    required this.color,
    required this.progress,
    required this.stroke,
    this.trackColor = const Color(0x26FFFFFF),
    required this.glow,
    this.gradientColors,
    this.gradientRotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);

    final sweep = (progress.clamp(0.0, 1.0)) * math.pi * 2;
    const start = -math.pi / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    if (gradientColors != null && gradientColors!.isNotEmpty) {
      arc.shader = SweepGradient(
        colors: gradientColors!,
        stops: _evenStops(gradientColors!.length),
        transform: GradientRotation(gradientRotation - math.pi / 2),
      ).createShader(arcRect);
    }

    if (glow && sweep > 0) {
      final glowBase = (gradientColors != null && gradientColors!.length > 1)
          ? gradientColors![1]
          : (gradientColors?.first ?? color);

      final ambientGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 18
        ..strokeCap = StrokeCap.round
        ..color = glowBase.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
      canvas.drawArc(arcRect, start, sweep, false, ambientGlow);

      final haloGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 12
        ..strokeCap = StrokeCap.round
        ..color = glowBase.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawArc(arcRect, start, sweep, false, haloGlow);

      final coreGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(arcRect, start, sweep, false, coreGlow);
    }

    if (sweep > 0) {
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        arc,
      );
    }
  }

  static List<double> _evenStops(int n) {
    if (n <= 1) return const [0.0];
    return List<double>.generate(n, (i) => i / (n - 1));
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.stroke != stroke ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.glow != glow ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.gradientRotation != gradientRotation;
  }
}

class _SeriesSlice {
  final List<FlSpot> spots;
  final List<String> labels;

  const _SeriesSlice(this.spots, this.labels);
}

class _ReportSkeletonCard extends StatelessWidget {
  const _ReportSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      tint: isLight
          ? const Color(0xFFF7F7F9)
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: isLight ? AppTheme.lightStroke : const Color(0x22FFFFFF),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(
            width: 160,
            height: 14,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(height: 12),
          Skeleton(
            height: 12,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(height: 10),
          Skeleton(
            height: 12,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(height: 18),
          Skeleton(
            height: 110,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ],
      ),
    );
  }
}
