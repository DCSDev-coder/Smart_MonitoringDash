import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/controllers/global_status_poller.dart';
import '../../core/utils/app_log.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../shared/widgets/scrollable_time_series_chart.dart';
import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/skeleton.dart';
import '../dashboard/widgets/dashboard_typography.dart';

part 'report_screen_navigation.dart';
part 'report_screen_health_security.dart';

class ReportScreen extends StatefulWidget {
  final int initialTabIndex;

  const ReportScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with TickerProviderStateMixin {
  static const List<String> _eventRangeOptions = <String>[
    'Today',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  int _selectedTabIndex = 0;
  final GlobalKey _siteChartKey = GlobalKey();
  final GlobalKey _itChartKey = GlobalKey();
  final GlobalKey _pueChartKey = GlobalKey();
  bool _loading = true;
  bool _refreshing = false;
  bool _fetchingEnergy = false;
  Map<String, double> _powerMonth = {};
  List<dynamic> _alarms = [];
  List<dynamic> _devices = [];
  List<dynamic> _reportAlarms = [];
  List<dynamic> _doorLogs = [];
  bool _fetchingHistoricalEvents = false;
  bool _fetchingDoorLogs = false;
  String _eventLogRange = 'Today'; // Today, Weekly, Monthly, All
  String _siteName = 'Smart Rack';

  // Historical Energy Analytics state
  List<FlSpot> _totalPowerSpots = [];
  List<FlSpot> _itPowerSpots = [];
  List<FlSpot> _pueSpots = [];
  List<String> _totalPowerLabels = [];
  List<String> _itPowerLabels = [];
  List<String> _pueLabels = [];
  // Per-chart time window filters (independent, per Figma).
  String _sitePowerRange = '24H';
  String _itDeviceRange = '24H';
  String _pueStabilityRange = '24H';
  double _avgPue = 0.0;

  // Analytics State
  bool _isExporting = false;
  int _smokeStatus = -1; // -1 means sensor not discovered yet
  int _floodStatus = -1;
  DateTime? _lastMaintenance;
  int? _siteId;

  late final AnimationController _tabSelC;
  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;

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
    _syncFromPoller();
    _fetchReportData();
  }

  @override
  void dispose() {
    _poller.removeListener(_syncFromPoller);
    _tabSelC.dispose();
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

  Future<void> _fetchReportData({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.fetchPowerMonth(),
        ApiService.instance.fetchAlarmsByLevel(),
        ApiService.instance.fetchSysInfo(),
      ]);

      if (mounted) {
        setState(() {
          final pm = results[0];
          if (pm != null && pm['result'] is Map) {
            _powerMonth = (pm['result'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
            );
          }

          final alRes = results[1];
          if (alRes != null) {
            _alarms = (alRes['result'] as List?) ?? [];
          }

          final sysRes = results[2];
          if (sysRes != null && sysRes['result'] != null) {
            _siteName = sysRes['result']['sysName']?.toString() ?? 'Smart Rack';
          }

          // 7. Load Cpanel Site Info
          final site = CpanelApiService.instance.currentSite;
          if (site != null) {
            _siteId = int.tryParse(site['site_id']?.toString() ?? '');
            if (site['last_maintenance'] != null) {
              _lastMaintenance = DateTime.tryParse(site['last_maintenance']);
            }
          }

          if (showSkeleton) _loading = false;
        });
      }
      if (showSkeleton && mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('[ReportScreen] Fetch Error: $e');
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

    final site = CpanelApiService.instance.currentSite;
    final siteId = site == null
        ? null
        : (int.tryParse(site['site_id']?.toString() ?? '') ??
            int.tryParse(site['id']?.toString() ?? ''));

    if (AdapterApiService.instance.isConfigured && siteId != null) {
      setState(() {
        _fetchingHistoricalEvents = true;
        _fetchingDoorLogs = true;
      });
      try {
        final bundle = await AdapterApiService.instance.fetchReportBundle(
          siteId: siteId,
          startTime: startTime,
          endTime: endTime,
          page: 1,
          pageSize: 20,
        );

        if (bundle != null && mounted) {
          setState(() {
            final ra = bundle['reportAlarms'];
            final al = bundle['accessLogs'];
            _reportAlarms = (ra is Map ? ra['result']?['records'] : null) as List? ??
                const [];

            final dynamic logsResult = (al is Map ? al['result'] : null);
            if (logsResult is List) {
              _doorLogs = logsResult;
            } else if (logsResult is Map && logsResult['records'] is List) {
              _doorLogs = logsResult['records'];
            } else {
              _doorLogs = [];
            }

            _fetchingHistoricalEvents = false;
            _fetchingDoorLogs = false;
          });
        } else {
          if (mounted) {
            setState(() {
              _fetchingHistoricalEvents = false;
              _fetchingDoorLogs = false;
            });
          }
        }
      } catch (e) {
        debugPrint('[ReportScreen] Report bundle fetch error: $e');
        if (mounted) {
          setState(() {
            _fetchingHistoricalEvents = false;
            _fetchingDoorLogs = false;
          });
        }
      }
      return;
    }

    // Fallback: legacy 2 calls.
    await Future.wait([
      _fetchHistoricalEvents(),
      _fetchDoorLogs(),
    ]);
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

  int _eventRangeStartFor(DateTime now) {
    switch (_eventLogRange) {
      case 'Today':
        return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      case 'Yearly':
        return now.subtract(const Duration(days: 365)).millisecondsSinceEpoch;
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

      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      Map<String, dynamic>? res;
      if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.fetchReportAlarms(
          siteId: siteId,
          startTime: startTime,
          endTime: endTime,
          page: 1,
          pageSize: 20,
        );
      }

      // Fallback to direct Dahua call if adapter is not available.
      res ??= await ApiService.instance
          .fetchReportAlarms(startTime: startTime, endTime: endTime);

      if (mounted) {
        setState(() {
          _reportAlarms = (res?['result']?['records'] as List?) ?? [];
          _fetchingHistoricalEvents = false;
        });
      }
    } catch (e) {
      debugPrint('[ReportScreen] Event Fetch Error: $e');
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

      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      Map<String, dynamic>? res;
      if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.fetchAccessLogs(
          siteId: siteId,
          startTime: startTime,
          endTime: endTime,
          accessType: '1',
        );
      }

      // Fallback to direct Dahua call if adapter is not available.
      res ??= await ApiService.instance.fetchDoorAccessLogs(
        startTime: startTime,
        endTime: endTime,
        accessType: '1',
      );

      if (mounted) {
        setState(() {
          final dynamic resultData = res?['result'];
          if (resultData is List) {
            _doorLogs = resultData;
          } else if (resultData is Map && resultData['records'] is List) {
            _doorLogs = resultData['records'];
          } else {
            _doorLogs = [];
          }
          _fetchingDoorLogs = false;
        });
      }
    } catch (e) {
      debugPrint('[ReportScreen] Door Fetch Error: $e');
      if (mounted) setState(() => _fetchingDoorLogs = false);
    }
  }

  Future<void> _fetchEnergyHistory() async {
    if (!mounted) return;
    setState(() => _fetchingEnergy = true);

    try {
      final now = DateTime.now();
      final endTime = now.millisecondsSinceEpoch;
      // Fetch a full 24H window; UI selectors (8H/12H/24H) slice this series.
      final startTime =
          now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

      // 1. Fetch Production Energy Trends & PUE
      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      Future<Map<String, dynamic>?> _fetchPueWithFallback({required int? siteId}) async {
        final rawCabinetId = site != null
            ? (site['dahua_cabinet_id'] ??
                    site['cabinet_id'] ??
                    site['cabinetId'] ??
                    site['rack_cabinet_id'])
                ?.toString()
            : null;
        final cabinetId =
            rawCabinetId == null ? null : int.tryParse(rawCabinetId)?.toString();

        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter = await AdapterApiService.instance.fetchPue(siteId: siteId);
          if (viaAdapter != null) return viaAdapter;
        }
        // Legacy fallback expects a cabinet id (string), default to 1.
        return ApiService.instance.fetchPue(id: cabinetId ?? '1');
      }

      Future<Map<String, dynamic>?> _fetchRangeWithFallback({
        required int nodeId,
        required String metricCode,
      }) async {
        if (AdapterApiService.instance.isConfigured && siteId != null) {
          final viaAdapter = await AdapterApiService.instance.fetchRange(
            siteId: siteId,
            nodeId: nodeId,
            metricCode: metricCode,
            startTime: startTime,
            endTime: endTime,
          );
          if (viaAdapter != null) return viaAdapter;
        }
        return ApiService.instance.fetchHistoricalData(
          nodeId: nodeId,
          metricCode: metricCode,
          startTime: startTime,
          endTime: endTime,
        );
      }

      final results = await Future.wait([
        _fetchPueWithFallback(siteId: siteId),
        // PDU 1 active power history (hashed metric code)
        _fetchRangeWithFallback(
          nodeId: 6,
          metricCode: 'pdu_active_power_single_phase',
        ),
        // PDU 2 active power history (non-hashed metric code)
        _fetchRangeWithFallback(
          nodeId: 7,
          metricCode: 'active_power_single_phase',
        ),
      ]);

      if (mounted) {
        setState(() {
          _totalPowerSpots = [];
          _itPowerSpots = [];
          _pueSpots = [];
          _avgPue = 0.0;
          _totalPowerLabels = [];
          _itPowerLabels = [];
          _pueLabels = [];

          bool hasRealHistory = false;

          List<Map<String, Object?>> _parseRange(Map<String, dynamic>? res) {
            final raw = res?['result'];
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

          final pdu1Series = _parseRange(results[1] as Map<String, dynamic>?);
          final pdu2Series = _parseRange(results[2] as Map<String, dynamic>?);

          if (pdu1Series.isNotEmpty || pdu2Series.isNotEmpty) {
            // Merge by time string (vendor uses "YYYY-MM-DD HH:mm:ss" granularity).
            final byTime = <String, double>{};
            for (final pt in pdu1Series) {
              final t = pt['time'] as String;
              final v = pt['value'] as double;
              byTime[t] = (byTime[t] ?? 0) + v;
            }
            for (final pt in pdu2Series) {
              final t = pt['time'] as String;
              final v = pt['value'] as double;
              byTime[t] = (byTime[t] ?? 0) + v;
            }

            final times = byTime.keys.toList()..sort();
            if (times.isNotEmpty) {
              hasRealHistory = true;
              for (int i = 0; i < times.length; i++) {
                final t = times[i];
                // Backend values are typically W; convert to kW for display.
                final kw = (byTime[t] ?? 0) / 1000.0;
                _totalPowerSpots.add(FlSpot(i.toDouble(), kw));
                _itPowerSpots.add(FlSpot(i.toDouble(), kw));
                _totalPowerLabels.add(t);
                _itPowerLabels.add(t);
              }
            }
          }

          // B. PUE stability: use current PUE value as a flat line over the selected range.
          final pueRes = results[0] as Map<String, dynamic>?;
          if (pueRes != null && pueRes['result'] != null) {
            final r = pueRes['result'];

            // getCurrentPue: { result: { pue, power } }
            if (r is Map && (r['pue'] != null || r['pueValue'] != null)) {
              final v = r['pue'] ?? r['pueValue'];
              final pueVal =
                  (v is num) ? v.toDouble() : double.tryParse(v.toString());
              if (pueVal != null && pueVal > 0) {
                hasRealHistory = true;
                _avgPue = pueVal;
                // Align points to totalPower labels if we have them.
                final n =
                    _totalPowerLabels.isNotEmpty ? _totalPowerLabels.length : 1;
                for (int i = 0; i < n; i++) {
                  _pueSpots.add(FlSpot(i.toDouble(), pueVal));
                  _pueLabels.add(_totalPowerLabels.isNotEmpty
                      ? _totalPowerLabels[i]
                      : 'Now');
                }
              }
            }
          }

          // C. FOLLBACK REMOVED
          if (!hasRealHistory) {
            AppLog.d(
                '[EnergyHistory] History empty. No fallback data generated per user request. Chart will remain empty until real data is available.');
          }

          _fetchingEnergy = false;
        });
      }
    } catch (e) {
      debugPrint('[EnergyHistory] Production Fetch Error: $e');
      if (mounted) setState(() => _fetchingEnergy = false);
    }
  }

  static int _hoursForRange(String range) {
    switch (range.trim().toUpperCase()) {
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
      debugPrint('[ReportScreen] Capture Error: $e');
      return Uint8List(0);
    }
  }

  Future<void> _generatePdf() async {
    if (_isExporting) return;
    if (!_canViewReport) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to export reports.'),
        ),
      );
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
              pw.Text('Report Period: $_sitePowerRange Consumption',
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
                      'Total Usage in Period: ${_estimateConsumptionKwh(_totalPowerSpots, _totalPowerLabels, _sitePowerRange).toStringAsFixed(2)} kWh'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report generated successfully.')),
        );
      }
    } catch (e) {
      debugPrint('[ReportScreen] PDF Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to generate PDF: $e'),
              backgroundColor: AppTheme.statusError),
        );
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

    final hPadding = screenWidth * 0.06;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: _ShiftedFloatingActionButtonLocation(
            offset:
                screenWidth >= 600 ? const Offset(0, 0) : const Offset(0, -95)),
        floatingActionButton: _canViewReport
            ? FloatingActionButton(
                onPressed: _isExporting ? null : _generatePdf,
                backgroundColor: AppTheme.accentBlue,
                child: _isExporting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? AppTheme.lightTextPrimary
                                    : Colors.white,
                            strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf, color: Colors.white),
              )
            : null,
        body: RefreshIndicator(
          edgeOffset: AppConstants.headerClearance(context),
          onRefresh: _onRefresh,
          child: CustomScrollView(
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
                          const SizedBox(height: 12),
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
                                  SizedBox(height: 12),
                                  _ReportSkeletonCard(),
                                  SizedBox(height: 14),
                                  _ReportSkeletonCard(),
                                  SizedBox(height: 14),
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
                  height: MediaQuery.of(context).size.width >= 600
                      ? 24
                      : (MediaQuery.of(context).padding.bottom + 95),
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
    final totalKwh = _estimateConsumptionKwh(
        _totalPowerSpots, _totalPowerLabels, _sitePowerRange);
    final itKwh =
        _estimateConsumptionKwh(_itPowerSpots, _itPowerLabels, _itDeviceRange);
    final itRatio = totalKwh > 0 ? (itKwh / totalKwh).clamp(0.0, 1.0) : 0.0;
    return Padding(
      // Let the global bottom nav / safe area handle spacing.
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      child: Column(
        children: [
          if (isWide) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildSummaryCard(healthScore)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _kpiRingCard(
                      title: 'Avg PUE',
                      subtitle: 'Efficiency',
                      color: const Color(0xFF05A100),
                      valueText:
                          _avgPue <= 0 ? '--' : _avgPue.toStringAsFixed(1),
                      progress: _avgPue <= 0
                          ? 0.0
                          : (1.5 - _avgPue).clamp(0.0, 0.8) / 0.8,
                      trackColor:
                          const Color(0xFF4A4A4A).withValues(alpha: 0.38),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _kpiRingCard(
                      title: 'IT Ratio',
                      subtitle: 'Utilization',
                      color: const Color(0xFF3271D7),
                      valueText: '${(itRatio * 100).toStringAsFixed(0)}%',
                      progress: itRatio,
                      trackColor:
                          const Color(0xFF4A4A4A).withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildSummaryCard(healthScore),
            const SizedBox(height: 16),
            _buildTrendAnalysisGrid(),
          ],
          const SizedBox(height: 18),
          _buildEnergySection(totalPower),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int score) {
    // Light mode mock uses a brighter cyan/blue block rather than the darker
    // "navy" gradient.
    const c1 = Color(0xFF00A3FF);
    const c2 = Color(0xFF0077D6);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [c1, c2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Site Health Index',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _infoIconButton(
                      iconColor: Colors.white.withValues(alpha: 0.55),
                      onTap: () => _showSiteHealthInfo(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Operational',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HealthRing(score: score),
        ],
      ),
    );
  }

  static double _chartHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return (h * 0.26).clamp(220.0, 320.0);
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

  static String Function(String raw) _xLabelFormatterForRange(String range) {
    DateTime? parseDt(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      // Try ISO or "yyyy-mm-dd hh:mm:ss" variants first.
      final dt = DateTime.tryParse(s.replaceAll('/', '-'));
      if (dt != null) return dt;

      // Common patterns from some APIs: "yyyy-MM-dd HH:mm" / "yyyy-MM-dd HH:mm:ss"
      final m = RegExp(
              r'(\d{4})-(\d{2})-(\d{2})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?')
          .firstMatch(s);
      if (m == null) return null;
      final y = int.tryParse(m.group(1) ?? '');
      final mo = int.tryParse(m.group(2) ?? '');
      final d = int.tryParse(m.group(3) ?? '');
      if (y == null || mo == null || d == null) return null;
      final hh = int.tryParse(m.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(m.group(5) ?? '0') ?? 0;
      final ss = int.tryParse(m.group(6) ?? '0') ?? 0;
      return DateTime(y, mo, d, hh, mm, ss);
    }

    return (String raw) {
      final s = raw.trim();
      if (s.isEmpty) return '';

      // We currently only support hour windows; always format as time.
      final dt = parseDt(s);
      if (dt != null) return DateFormat('HH:mm').format(dt);
      final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
      if (m != null) return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
      return s.length <= 5 ? s : s.substring(0, 5);
    };
  }

  Widget _buildEnergySection(double totalPower) {
    return Column(
      children: [
        RepaintBoundary(
          key: _siteChartKey,
          child: _chartCard(
            title: 'SITE POWER',
            range: _sitePowerRange,
            onRange: (v) {
              setState(() => _sitePowerRange = v);
            },
            titleColor: AppTheme.accentGreen,
            child: _buildPowerIndividualChartBody(
              _totalPowerSpots,
              _totalPowerLabels,
              AppTheme.accentGreen,
              _sitePowerRange,
            ),
          ),
        ),
        const SizedBox(height: 18),
        RepaintBoundary(
          key: _itChartKey,
          child: _chartCard(
            title: 'IT DEVICE',
            range: _itDeviceRange,
            onRange: (v) {
              setState(() => _itDeviceRange = v);
            },
            titleColor: const Color(0xFF3271D7),
            child: _buildPowerIndividualChartBody(
              _itPowerSpots,
              _itPowerLabels,
              const Color(0xFF3271D7),
              _itDeviceRange,
            ),
          ),
        ),
        const SizedBox(height: 18),
        RepaintBoundary(
          key: _pueChartKey,
          child: _chartCard(
            title: 'PUE STABILITY',
            range: _pueStabilityRange,
            onRange: (v) {
              setState(() => _pueStabilityRange = v);
            },
            titleColor: const Color(0xFFB76DFF),
            child: _buildPueTrendChartBody(_pueStabilityRange),
          ),
        ),
      ],
    );
  }

  Widget _chartCard({
    required String title,
    required String range,
    required ValueChanged<String> onRange,
    required Widget child,
    Color? titleColor,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      tint: isLight
          ? Colors.white
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: isLight ? AppTheme.lightStroke : const Color(0x22FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isLight
                      ? (titleColor ?? AppTheme.lightTextPrimary)
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              _rangeDropdown(range: range, onChanged: onRange),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _rangeDropdown({
    required String range,
    required ValueChanged<String> onChanged,
  }) {
    String labelFor(String r) {
      final u = r.trim().toUpperCase();
      if (u == '8H') return '8 Hours';
      if (u == '12H') return '12 Hours';
      return '24 Hours';
    }

    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF0E141B),
      itemBuilder: (context) => [
        PopupMenuItem(
            value: '8H',
            child: Text('8 Hours',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.lightTextPrimary
                        : Colors.white))),
        PopupMenuItem(
            value: '12H',
            child: Text('12 Hours',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.lightTextPrimary
                        : Colors.white))),
        PopupMenuItem(
            value: '24H',
            child: Text('24 Hours',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.lightTextPrimary
                        : Colors.white))),
      ],
      child: DashboardGlass(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tint: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF0E141B).withValues(alpha: 0.92),
        borderColor: Theme.of(context).brightness == Brightness.light
            ? AppTheme.lightStroke
            : const Color(0x22FFFFFF),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labelFor(range),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppTheme.lightTextPrimary
                    : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Theme.of(context).brightness == Brightness.light
                  ? AppTheme.lightTextSecondary.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.75),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerIndividualChartBody(
      List<FlSpot> spots, List<String> labels, Color chartColor, String range) {
    final baseHeight = _chartHeight(context) - 56;
    if (_fetchingEnergy) {
      return SizedBox(
        height: baseHeight,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final sliced = _sliceSeriesForRange(spots, labels, range);
    return ScrollableTimeSeriesChart(
      spots: sliced.spots,
      xLabels: sliced.labels,
      lineColor: chartColor,
      height: baseHeight,
      targetYTicks: _targetYTicksForPower(range, sliced.spots),
      pxPerPoint: _pxPerPointForRange(range),
      targetXTicks: _targetTicksForRange(range),
      padding: const EdgeInsets.fromLTRB(2, 6, 10, 2),
      emptyText: 'Calculating power trends...',
      xLabelFormatter: _xLabelFormatterForRange(range),
    );
  }

  Widget _buildPueTrendChartBody(String range) {
    final baseHeight = _chartHeight(context) - 56;
    if (_fetchingEnergy) {
      return SizedBox(
        height: baseHeight,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final sliced = _sliceSeriesForRange(_pueSpots, _pueLabels, range);
    return ScrollableTimeSeriesChart(
      spots: sliced.spots,
      xLabels: sliced.labels,
      lineColor: const Color(0xFFB76DFF),
      height: baseHeight,
      targetYTicks: 4,
      minY: 1.0,
      maxY: 2.5,
      pxPerPoint: _pxPerPointForRange(range),
      targetXTicks: _targetTicksForRange(range),
      padding: const EdgeInsets.fromLTRB(2, 6, 10, 2),
      emptyText: 'Insufficient PUE data',
      xLabelFormatter: _xLabelFormatterForRange(range),
    );
  }

  static double _pxPerPointForRange(String range) {
    switch (range.trim().toUpperCase()) {
      case '8H':
        // Enough spacing to show every HH:mm label without overlap.
        return 62;
      case '12H':
        return 58;
      case '24H':
      default:
        return 56;
    }
  }

  static int _targetTicksForRange(String range) {
    switch (range.trim().toUpperCase()) {
      case '8H':
        return 8;
      case '12H':
        return 12;
      case '24H':
      default:
        return 6;
    }
  }

  static int _targetYTicksForPower(String range, List<FlSpot> spots) {
    // Aim for more Y guidance on longer windows / larger spans.
    final span = _spanY(spots);
    final r = range.trim().toUpperCase();
    var ticks = (r == '24H')
        ? 6
        : (r == '12H')
            ? 5
            : 4;
    if (span > 8000) ticks = math.max(ticks, 7);
    if (span > 15000) ticks = math.max(ticks, 8);
    return ticks.clamp(4, 8);
  }

  static double _spanY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    double lo = spots.first.y;
    double hi = spots.first.y;
    for (final s in spots) {
      if (s.y < lo) lo = s.y;
      if (s.y > hi) hi = s.y;
    }
    return (hi - lo).abs();
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
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: DashboardGlass(
            radius: 22,
            padding: const EdgeInsets.all(18),
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
                        fontSize: 16,
                        color: isLight
                            ? AppTheme.lightTextPrimary
                            : const Color(0xFF80B4FF),
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'A quick indicator of site availability based on how many discovered devices are currently reporting normally.',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextPrimary
                          : Colors.white,
                      fontSize: 13,
                      height: 1.35),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 12),
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
  }

  static Widget _infoBullet(String text, {bool isLight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF80B4FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
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

  Widget _buildTrendAnalysisGrid() {
    final totalKwh = _estimateConsumptionKwh(
        _totalPowerSpots, _totalPowerLabels, _sitePowerRange);
    final itKwh =
        _estimateConsumptionKwh(_itPowerSpots, _itPowerLabels, _itDeviceRange);
    final itRatio = totalKwh > 0 ? (itKwh / totalKwh).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Expanded(
          child: _kpiRingCard(
            title: 'Avg PUE',
            subtitle: 'Efficiency',
            color: const Color(0xFF05A100),
            valueText: _avgPue <= 0 ? '--' : _avgPue.toStringAsFixed(1),
            progress:
                _avgPue <= 0 ? 0.0 : (1.5 - _avgPue).clamp(0.0, 0.8) / 0.8,
            trackColor: const Color(0xFF4A4A4A).withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiRingCard(
            title: 'IT Ratio',
            subtitle: 'Utilization',
            color: const Color(0xFF3271D7),
            valueText: '${(itRatio * 100).toStringAsFixed(0)}%',
            progress: itRatio,
            trackColor: const Color(0xFF4A4A4A).withValues(alpha: 0.38),
          ),
        ),
      ],
    );
  }

  Widget _kpiRingCard({
    required String title,
    required String subtitle,
    required Color color,
    required String valueText,
    required double progress,
    required Color trackColor,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DashboardGlass(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        // In light mode, the mock uses a solid colored card.
        tint: isLight ? color : color.withValues(alpha: 0.22),
        borderColor:
            isLight ? Colors.transparent : color.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _MiniRing(
              color: color,
              progress: progress.clamp(0.0, 1.0),
              trackColor: trackColor,
              // White value text on the solid cards (both Avg PUE + IT Ratio).
              child: Text(
                valueText,
                style: bitcount(
                  context,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final r = BorderRadius.circular(10);

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
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
                gradientColors: _gradientFor(widget.color),
                gradientRotation: _c.value * math.pi * 2,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }

  static List<Color> _gradientFor(Color base) {
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
    return const [
      AppTheme.accentGreen,
      Color(0xFF05A100),
      Color(0xFF0B6B0A),
      AppTheme.accentGreen,
      AppTheme.accentGreen,
    ];
  }
}

class _HealthRing extends StatefulWidget {
  final int score;

  const _HealthRing({required this.score});

  @override
  State<_HealthRing> createState() => _HealthRingState();
}

class _HealthRingState extends State<_HealthRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.score.clamp(0, 100)) / 100.0;
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35);
    final size = 78.0 * scale;
    final stroke = 7.5 * scale;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                color: const Color(0xFFFFFFFF),
                progress: pct,
                stroke: stroke,
                trackColor: Colors.white24,
                glow: false,
                gradientColors: const [
                  Colors.white,
                  Color(0xFFD7E6FF),
                  Colors.white,
                ],
                gradientRotation: _c.value * math.pi * 2,
              ),
            ),
          ),
          Text(
            '${widget.score}%',
            style: bitcount(
              context,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 1.6,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
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
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 2
        ..strokeCap = StrokeCap.round
        ..color = glowBase.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        glowPaint,
      );
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

class _ShiftedFloatingActionButtonLocation
    extends FloatingActionButtonLocation {
  final Offset offset;
  const _ShiftedFloatingActionButtonLocation({required this.offset});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset standardOffset =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return Offset(standardOffset.dx + offset.dx, standardOffset.dy + offset.dy);
  }
}
