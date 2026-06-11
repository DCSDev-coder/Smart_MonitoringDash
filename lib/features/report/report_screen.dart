import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/navigation/app_navigator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
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

import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/skeleton.dart';
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
  final GlobalKey _siteChartKey = GlobalKey();
  final GlobalKey _itChartKey = GlobalKey();
  final GlobalKey _pueChartKey = GlobalKey();

  // We removed the GlobalKeys for the power cards because moving them around
  // the tree during responsive layout shifts was causing a framework assertion
  // failure in InheritedElement dependencies (ancestor == this is not true).

  bool _loading = true;
  bool _refreshing = false;
  Map<String, double> _powerMonth = {};
  List<dynamic> _alarms = [];
  List<dynamic> _devices = [];
  List<dynamic> _reportAlarms = [];
  List<dynamic> _doorLogs = [];
  List<dynamic> _cpanelAccessLogs = [];
  bool _fetchingHistoricalEvents = false;
  bool _fetchingDoorLogs = false;
  String _eventLogRange = 'Recent'; // Recent, Weekly, Monthly, All
  String _siteName = 'Smart Rack';

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
  bool _isExporting = false;
  int _smokeStatus = -1; // -1 means sensor not discovered yet
  int _floodStatus = -1;
  DateTime? _lastMaintenance;
  int? _siteId;
  int _adapterMissStreak = 0;
  bool get _showAdapterDegraded => _adapterMissStreak >= 2;

  late final AnimationController _tabSelC;
  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;
  final ScrollController _scrollController = ScrollController();

  bool get _canViewReport {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return true; // backward compatible fallback

    final v = site['can_view_report'];
    if (v == null) return true;
    if (v is bool) return v;
    if (v is num) return v != 0;

    final s = v.toString().trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return true;
  }

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

  bool _shouldUseAdapter(int? siteId) =>
      _isAdapterReady(siteId) && !_showAdapterDegraded;

  Future<void> _fetchReportData({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _loading = true);
    try {
      final site = CpanelApiService.instance.currentSite;
      final siteId = SiteRuntimeConfig.siteId(site);
      final cabinetId = SiteRuntimeConfig.cabinetId(site);
      final adapterReady = _isAdapterReady(siteId);

      final results = await Future.wait([
        adapterReady
            ? AdapterApiService.instance.fetchPowerMonth(siteId: siteId!)
            : ApiService.instance.fetchPowerMonth(id: cabinetId),
        adapterReady
            ? AdapterApiService.instance.fetchRecentAlarms(siteId: siteId!)
            : ApiService.instance.fetchAlarmsByLevel(),
        adapterReady
            ? AdapterApiService.instance.fetchSysInfo(siteId: siteId!)
            : ApiService.instance.fetchSysInfo(),
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

          final alRes = results[1];
          if (alRes != null) {
            final raw = alRes['result'];
            if (raw is List) {
              _alarms = raw;
            } else if (raw is Map && raw['records'] is List) {
              _alarms = raw['records'];
            } else {
              _alarms = [];
            }
          }

          final sysRes = results[2];
          if (sysRes != null && sysRes['result'] != null) {
            _siteName = sysRes['result']['sysName']?.toString() ?? 'Smart Rack';
          }

          // 7. Load Cpanel Site Info
          if (site != null) {
            _siteId = siteId;
            if (site['last_maintenance'] != null) {
              _lastMaintenance = DateTime.tryParse(site['last_maintenance']);
            }
          }

          if (results.length > 5 && results[5] != null) {
            final Map<String, dynamic> accessData = results[5] as Map<String, dynamic>;
            if (accessData['data'] is List) {
              _doorLogs = List.from(accessData['data']);
            }
          }

          if (results.length > 6 && results[6] != null) {
            _cpanelAccessLogs = results[6] as List<dynamic>;
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
    setState(() => _refreshing = true);
    try {
      // Refresh without blanking the page; we keep the current content visible
      // and overlay skeletons in the build method.
      await _fetchReportData(showSkeleton: false);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

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
              return ms >= startTime && ms <= endTime;
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
        res ??= await ApiService.instance.fetchDoorAccessLogs(
          accessType: '1',
        );
      }

      if (siteId != null) {
        cpanelLogs = await CpanelApiService.instance.fetchRemoteAccessLogs(
          siteId: siteId,
          startTime: startTime, // We still pass these, but the backend now ignores them safely
          endTime: endTime,
        );
      }
      
      Map<String, dynamic>? doorsRes;
      try {
        if (_shouldUseAdapter(siteId)) {
          doorsRes = await AdapterApiService.instance.fetchDoors(siteId: siteId!);
        } else {
          final cabinetId = SiteRuntimeConfig.cabinetId(CpanelApiService.instance.currentSite);
          final parsed = int.tryParse(cabinetId ?? '');
          doorsRes = await ApiService.instance.fetchCabinetDoors(cabinetId: parsed ?? 1);
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
            
            final u = (log['opUser'] ?? log['openUser'] ?? log['userName'] ?? log['username'])?.toString().toLowerCase() ?? '';
            if (u == 'superadmin' || u == 'admin' || u == 'remote open') {
               return false; // Remove Dahua's generic remote unlock logs completely
            }
            return true;
          }).toList();

          final Map<int, String> synthesizedDoorNames = {};
          if (doorsRes != null) {
            final raw = doorsRes['result'];
            final List cabinets = raw is List ? raw : (raw is Map ? ((raw['list'] as List?) ?? (raw['data'] as List?) ?? const []) : const []);
            final List<Map<String, dynamic>> tempDoors = [];
            
            for (final cabinet in cabinets) {
              if (cabinet is! Map) continue;
              final details = (cabinet['detailList'] as List?) ?? (cabinet['detail_list'] as List?) ?? (cabinet['accessList'] as List?) ?? (cabinet['doorList'] as List?) ?? const [];
              
              for (final door in details) {
                if (door is! Map) continue;
                final dynamic idRaw = door['id'] ?? door['accessId'] ?? door['access_id'];
                final int? dId = idRaw == null ? null : (idRaw is num ? idRaw.toInt() : int.tryParse(idRaw.toString()));
                if (dId == null) continue;
                
                final rawDoor = (door['accessName'] ?? door['name'] ?? '').toString().trim();
                final doorSide = rawDoor.toUpperCase().contains('FRONT') ? 'Front' : 'Back';
                
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
              
              final cabA = (a['cabIndex'] is int) ? (a['cabIndex'] as int) : null;
              final cabB = (b['cabIndex'] is int) ? (b['cabIndex'] as int) : null;
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
             final aTime = DateTime.tryParse(a['opTime']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
             final bTime = DateTime.tryParse(b['opTime']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
             return bTime.compareTo(aTime);
          });

          _cpanelAccessLogs = cpanelLogs;

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
          return AdapterApiService.instance.fetchPue(siteId: siteId!);
        }
        // Legacy fallback expects a cabinet id (string), default to 1.
        return ApiService.instance.fetchPue(id: cabinetId ?? '1');
      }

      Future<Map<String, dynamic>?> fetchRangeWithFallback({
        required int nodeId,
        required String metricCode,
      }) async {
        if (_isAdapterReady(siteId)) {
          return AdapterApiService.instance.fetchRange(
            siteId: siteId!,
            nodeId: nodeId,
            metricCode: metricCode,
            startTime: startTime,
            endTime: endTime,
          );
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

  double _estimateConsumptionKwh(
      List<FlSpot> spots, List<String> labels, String range) {
    final sliced = _sliceSeriesForRange(spots, labels, range);
    if (sliced.spots.isEmpty) return 0.0;
    final hours = _hoursForRange(range).toDouble();
    final dt = hours / sliced.spots.length;
    var sum = 0.0;
    for (final p in sliced.spots) {
      sum += p.y;
    }
    return sum * dt;
  }

  Future<Uint8List> _captureChart(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return Uint8List(0);
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      AppLog.w('Capture error', tag: 'ReportScreen', error: e);
      return Uint8List(0);
    }
  }

  Future<void> _generatePdf() async {
    if (_isExporting) return;
    if (!_canViewReport) {
      if (!mounted) return;
      AppToast.show(context, 'You do not have permission to export reports.');
      return;
    }
    setState(() => _isExporting = true);

    try {
      // Capture charts before generating PDF
      final siteChartImage = await _captureChart(_siteChartKey);
      final itChartImage = await _captureChart(_itChartKey);
      final pueChartImage = await _captureChart(_pueChartKey);

      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);

      final itPower = _powerMonth['IT Device'] ?? 0.0;
      final coolingPower = _powerMonth['Aircon'] ?? 0.0;

      final alarmCount = _alarms.fold<int>(
          0, (prev, a) => prev + (a['alarmCount'] as int? ?? 0));

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
      final offlineDevices = totalPhysicalDevices - onlinePhysicalDevices;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SMART RACK ANALYTICS REPORT',
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
              pw.Text('Site: $_siteName',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Report Period: $_totalPowerRange Consumption',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.Text('1. Energy Trends & Performance',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              if (siteChartImage.isNotEmpty) ...[
                pw.Text('Total Site Power Trend:',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 140,
                  width: double.infinity,
                  child: pw.Image(pw.MemoryImage(siteChartImage)),
                ),
                pw.SizedBox(height: 10),
              ],
              if (itChartImage.isNotEmpty) ...[
                pw.Text('IT Device Power Trend:',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 140,
                  width: double.infinity,
                  child: pw.Image(pw.MemoryImage(itChartImage)),
                ),
                pw.SizedBox(height: 10),
              ],
              if (pueChartImage.isNotEmpty) ...[
                pw.Text('PUE Stability Tracker:',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 140,
                  width: double.infinity,
                  child: pw.Image(pw.MemoryImage(pueChartImage)),
                ),
              ],
              if (siteChartImage.isEmpty && pueChartImage.isEmpty)
                pw.Text(
                    '[Graph Data Unavailable - View the Energy tab to render charts before exporting]'),
              pw.SizedBox(height: 20),
              pw.Text('2. Consumption Details',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Bullet(
                  text:
                      'Total Usage in Period: ${_estimateConsumptionKwh(_totalPowerSpots, _totalPowerLabels, _totalPowerRange).toStringAsFixed(2)} kWh'),
              pw.Bullet(
                  text:
                      'Monthly Projected (IT): ${itPower.toStringAsFixed(2)} kWh'),
              pw.Bullet(
                  text:
                      'Monthly Projected (Cooling): ${coolingPower.toStringAsFixed(2)} kWh'),
              pw.SizedBox(height: 20),
              pw.Text('3. Infrastructure Health & Utilization',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Bullet(text: 'Uptime Integrity Index: $healthScore%'),
              pw.Bullet(
                  text:
                      'Device Availability: $onlinePhysicalDevices Online / $offlineDevices Offline (Total: $totalPhysicalDevices)'),
              if (_lastMaintenance != null)
                pw.Bullet(
                    text:
                        'Last Service Date: ${DateFormat('yyyy-MM-dd').format(_lastMaintenance!)}'),
              // Server utilization removed by request (CPU/RAM/Storage).
              pw.Bullet(text: 'Historical Alarm Count: $alarmCount'),
              pw.SizedBox(height: 20),
              pw.Text('4. Recent Historical Events',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ..._reportAlarms.take(15).map((alarm) => pw.Bullet(
                    text:
                        '[${alarm['occurrenceTime']}] ${alarm['alarmTypeName']}: ${alarm['content']}',
                    style: const pw.TextStyle(fontSize: 9),
                  )),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                    'Document digitally generated by Smart Rack eCTRL Systems',
                    style: const pw.TextStyle(fontSize: 8)),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());

      if (mounted) {
        AppToast.showSuccess(context, 'Report generated successfully.');
      }
    } catch (e) {
      AppLog.w('PDF error', tag: 'ReportScreen', error: e);
      if (mounted) {
        AppToast.showError(context, 'Failed to generate PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        body: RefreshIndicator(
          edgeOffset: AppConstants.headerClearance(context),
          onRefresh: _onRefresh,
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
                child: SizedBox(height: AppConstants.headerClearance(context)),
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
                          const SizedBox(height: AppSpacing.sectionGapSm),
                          Visibility(
                            visible: _selectedTabIndex == 0,
                            maintainState: true,
                            maintainAnimation: true,
                            maintainSize: false,
                            child: _buildEnergyPage(
                                hPadding, totalPower, healthScore),
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
                    if ((_loading || _refreshing) && _selectedTabIndex != 2)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: hPadding),
                              child: const Column(
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
    );
  }

  Widget _buildEnergyPage(double hPadding, double totalPower, int healthScore) {
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

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

    return Padding(
      // Let the global bottom nav / safe area handle spacing.
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      child: Column(
        children: [
          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 260,
                        child: _buildSummaryCard(healthScore),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 260,
                        child: _sparklineCard(
                          title: 'Total Power',
                          subtitle: 'Facility Total',
                          color: const Color(0xFFD3F928), // Lime Green
                          textColor: Colors.black,
                          valueText: pmTotal == null
                              ? 'Offline'
                              : '${pmTotal.toStringAsFixed(1)} kW',
                          spots: slicedTotal.spots,
                          labels: slicedTotal.labels,
                          currentRange: _totalPowerRange,
                          onRangeChanged: (r) =>
                              setState(() => _totalPowerRange = r),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 260,
                        child: _sparklineCard(
                          title: 'IT Devices',
                          subtitle: 'Active Load',
                          color: const Color(0xFFFFFFFF), // White
                          textColor: Colors.black,
                          valueText: pmIt == null
                              ? 'Offline'
                              : '${pmIt.toStringAsFixed(1)} kW',
                          spots: slicedIt.spots,
                          labels: slicedIt.labels,
                          currentRange: _itPowerRange,
                          onRangeChanged: (r) =>
                              setState(() => _itPowerRange = r),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 260,
                        child: _sparklineCard(
                          title: 'Other/Cooling',
                          subtitle: 'Losses & Overhead',
                          color: const Color(0xFFFF6B57), // Coral Red
                          textColor: Colors.white,
                          valueText: pmOther == null
                              ? 'Offline'
                              : '${(pmOther).toStringAsFixed(1)} kW',
                          spots: slicedOther.spots,
                          labels: slicedOther.labels,
                          currentRange: _otherPowerRange,
                          onRangeChanged: (r) =>
                              setState(() => _otherPowerRange = r),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              height: 260,
              child: _buildSummaryCard(healthScore),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            _buildTrendAnalysisGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int score) {
    // Light mode mock uses a brighter cyan/blue block rather than the darker
    // "navy" gradient.
    const c1 = Color(0xFF00A3FF);
    const c2 = Color(0xFF0077D6);

    final isLight = Theme.of(context).brightness == Brightness.light;

    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      tint: isLight
          ? Colors.white
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Site Health Index',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _infoIconButton(
                iconColor: isLight
                    ? AppTheme.lightTextSecondary.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.55),
                onTap: () => _showSiteHealthInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Operational',
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _BatteryGauge(score: score),
          const SizedBox(height: 4),
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
                        color: Theme.of(context).brightness == Brightness.light
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
          filter: ui.ImageFilter.blur(sigmaX: 12 * anim1.value, sigmaY: 12 * anim1.value),
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
    required Color color,
    required Color textColor,
    required String valueText,
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
        minY -= 1;
      } else {
        final diff = maxY - minY;
        maxY += diff * 0.1;
        minY = math.max(0, minY - diff * 0.1);
      }
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final bool useDarkTheme = !isLight;
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

    // In dark mode, we use the card's accent color for text and lines, and a dark glass background.
    // In light mode, we use the vibrant solid background and the provided text color.
    final effectiveTextColor = useDarkTheme ? color : textColor;
    final chartLineColor = useDarkTheme ? color : textColor;
    final dividerColor = useDarkTheme
        ? const Color(0x22FFFFFF)
        : textColor.withValues(alpha: 0.2);

    return DashboardGlass(
      key: key,
      radius: 18,
      padding: const EdgeInsets.all(20),
      tint: useDarkTheme
          ? const Color(0xFF0E141B).withValues(alpha: 0.92)
          : color,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: effectiveTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: effectiveTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: onRangeChanged,
                color: isLight ? Colors.white : const Color(0xFF0E141B),
                itemBuilder: (context) => ['4H', '8H', '12H', '24H']
                    .map(
                      (option) => PopupMenuItem<String>(
                        value: option,
                        child: Text(option,
                            style: TextStyle(
                                color: isLight
                                    ? AppTheme.lightTextPrimary
                                    : Colors.white)),
                      ),
                    )
                    .toList(),
                child: DashboardGlass(
                  radius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tint: isLight
                      ? color
                      : const Color(0xFF0E141B).withValues(alpha: 0.92),
                  borderColor: isLight
                      ? effectiveTextColor.withValues(alpha: 0.15)
                      : const Color(0x22FFFFFF),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentRange,
                        style: TextStyle(
                          color: isLight ? effectiveTextColor : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isLight
                            ? effectiveTextColor.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.75),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Chart
          Expanded(
            child: spots.length < 2
                ? Center(
                    child: Text(
                      'Insufficient data',
                      style: TextStyle(
                        color: effectiveTextColor.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                minX: spots.isNotEmpty ? (spots.first.x == spots.last.x ? spots.first.x - 1 : spots.first.x) : 0,
                maxX: spots.isNotEmpty ? (spots.first.x == spots.last.x ? spots.first.x + 1 : spots.last.x) : 1,
                lineTouchData: labels != null && isWide
                    ? LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              final textStyle = TextStyle(
                                color: chartLineColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              );
                              return LineTooltipItem(
                                '${touchedSpot.y.toStringAsFixed(2)} kW',
                                textStyle,
                              );
                            }).toList();
                          },
                        ),
                      )
                    : const LineTouchData(enabled: false),
                gridData: labels != null
                    ? FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: math.max(0.1, (maxY - minY) / 3),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: chartLineColor.withValues(alpha: 0.15),
                            strokeWidth: 1,
                          );
                        },
                      )
                    : const FlGridData(show: false),
                titlesData: labels != null
                    ? FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval:
                                math.max(1, (spots.length / 5).floorToDouble()),
                            getTitlesWidget: (value, meta) {
                              final int idx = value.toInt();
                              if (idx < 0 || idx >= labels.length) {
                                return const SizedBox();
                              }
                              final timeStr = labels[idx];
                              final parts = timeStr.split(' ');
                              String timePart =
                                  parts.length > 1 ? parts.last : timeStr;
                              final timeTokens = timePart.split(':');
                              if (timeTokens.length >= 2) {
                                timePart = '${timeTokens[0]}:${timeTokens[1]}';
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  timePart,
                                  style: TextStyle(
                                    color: effectiveTextColor.withValues(
                                        alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      )
                    : const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: chartLineColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Divider
          Divider(color: dividerColor, thickness: 1, height: 1),
          const SizedBox(height: 16),
          // Metadata and Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Min ${minY.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: effectiveTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max ${maxY.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: effectiveTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                valueText,
                style: TextStyle(
                  color: effectiveTextColor,
                  fontSize: 32, // slightly smaller so it fits well
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysisGrid() {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 300,
          child: _sparklineCard(
            title: 'Total Power',
            subtitle: 'Facility Total',
            color: const Color(0xFFD3F928), // Lime Green
            textColor: Colors.black,
            valueText: pmTotal == null
                ? 'Offline'
                : '${pmTotal.toStringAsFixed(1)} kW',
            spots: slicedTotal.spots,
            labels: slicedTotal.labels,
            currentRange: _totalPowerRange,
            onRangeChanged: (r) => setState(() => _totalPowerRange = r),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: _sparklineCard(
            title: 'IT Devices',
            subtitle: 'Active Load',
            color: const Color(0xFFFFFFFF), // White
            textColor: Colors.black,
            valueText:
                pmIt == null ? 'Offline' : '${pmIt.toStringAsFixed(1)} kW',
            spots: slicedIt.spots,
            labels: slicedIt.labels,
            currentRange: _itPowerRange,
            onRangeChanged: (r) => setState(() => _itPowerRange = r),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: _sparklineCard(
            title: 'Other/Cooling',
            subtitle: 'Losses & Overhead',
            color: const Color(0xFFFF6B57), // Coral Red
            textColor: Colors.white,
            valueText: pmOther == null
                ? 'Offline'
                : '${pmOther.toStringAsFixed(1)} kW',
            spots: slicedOther.spots,
            labels: slicedOther.labels,
            currentRange: _otherPowerRange,
            onRangeChanged: (r) => setState(() => _otherPowerRange = r),
          ),
        ),
      ],
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

class _BatteryGauge extends StatefulWidget {
  final int score;

  const _BatteryGauge({required this.score});

  @override
  State<_BatteryGauge> createState() => _BatteryGaugeState();
}

class _BatteryGaugeState extends State<_BatteryGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    final targetPct = (widget.score.clamp(0, 100)) / 100.0;
    _anim = Tween<double>(begin: 1.0, end: targetPct).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant _BatteryGauge oldWidget) {
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

  Color _getColor(double pct) {
    if (pct >= 0.80) return const Color(0xFF4CAF50); // Green
    if (pct >= 0.40) return const Color(0xFFE6A600); // Yellow/Orange
    return const Color(0xFFE53935); // Red
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final pct = _anim.value;
            final isLight = Theme.of(context).brightness == Brightness.light;

            return CustomPaint(
              painter: _BatteryPainter(
                progress: pct,
                isLight: isLight,
              ),
              child: Center(
                child: Text(
                  '${(pct * 100).toInt()}%',
                  style: bitcount(
                    context,
                    fontSize: 24,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double progress;
  final bool isLight;

  _BatteryPainter({
    required this.progress,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Background track
    final trackRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final trackRRect =
        RRect.fromRectAndRadius(trackRect, Radius.circular(size.height * 0.15));

    final trackColor = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.1);

    final trackPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = trackColor;

    canvas.drawRRect(trackRRect, trackPaint);

    // Fill
    final currentFillWidth = size.width * progress;

    if (currentFillWidth > 0) {
      final fillRect = Rect.fromLTWH(0, 0, currentFillWidth, size.height);
      final fillRRect = RRect.fromRectAndRadius(
          fillRect, Radius.circular(size.height * 0.15));

      Color baseColor;
      if (progress >= 0.80)
        baseColor = const Color(0xFF4CAF50);
      else if (progress >= 0.40)
        baseColor = const Color(0xFFE6A600);
      else
        baseColor = const Color(0xFFE53935);

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor;

      canvas.drawRRect(fillRRect, fillPaint);

      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(fillRRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
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
