import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/controllers/smart_polling_settings.dart';
import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/utils/app_log.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/config/site_runtime_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';

import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/skeleton.dart';

class RackViewScreen extends StatefulWidget {
  final bool isActive;

  const RackViewScreen({super.key, this.isActive = true});

  const RackViewScreen.active({
    super.key,
    required this.isActive,
  });

  @override
  State<RackViewScreen> createState() => _RackViewScreenState();
}

class _RackViewScreenState extends State<RackViewScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  bool _refreshing = false;
  Timer? _refreshTimer;
  Duration _interval = SmartPollingSettings.instance.normalInterval();

  // PDU rated capacity for load calculation
  static const double _outletMaxWatts = 3600.0;
  static const double _totalRackMaxKw = 7.0;

  // Real-time telemetry
  double _inletV = 0.0;
  double _inletA = 0.0;
  double _inletP = 0.0;
  bool _inletOnline = false;

  // PDU 1 (Node 6)
  double _pdu1P = 0.0;
  double _pdu1A = 0.0;
  bool _pdu1Online = false;
  final Map<int, double> _pdu1Outlets = {};
  final Map<int, bool> _pdu1OutletOnline = {};
  final Map<int, String?> _pdu1OutletControlCodes = {};
  final Map<int, int?> _pdu1OutletControlValues = {};
  List<dynamic> _pdu1Records = [];

  // PDU 2 (Node 7)
  double _pdu2P = 0.0;
  double _pdu2A = 0.0;
  bool _pdu2Online = false;
  final Map<int, double> _pdu2Outlets = {};
  final Map<int, bool> _pdu2OutletOnline = {};
  final Map<int, String?> _pdu2OutletControlCodes = {};
  final Map<int, int?> _pdu2OutletControlValues = {};
  List<dynamic> _pdu2Records = [];

  bool _pdu1Expanded = false;
  bool _pdu2Expanded = false;
  int _adapterMissStreak = 0;
  bool get _showAdapterDegraded => _adapterMissStreak >= 2;

  @override
  void initState() {
    super.initState();
    SmartPollingSettings.instance.addListener(_onPollingSettingsChanged);
    if (widget.isActive) {
      _fetchRackData();
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant RackViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;

    if (widget.isActive) {
      _fetchRackData();
      _startTimer();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SmartPollingSettings.instance.removeListener(_onPollingSettingsChanged);
    super.dispose();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_interval, (_) => _fetchRackData());
  }

  void _onPollingSettingsChanged() {
    _interval = SmartPollingSettings.instance.normalInterval();
    if (widget.isActive) _startTimer();
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _fetchRackData();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _fetchRackData() async {
    try {
      // Prefer adapter-normalized rack telemetry when configured.
      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      if (AdapterApiService.instance.isConfigured && siteId != null) {
        final telem =
            await AdapterApiService.instance.fetchRackTelemetry(siteId: siteId);

        if (!mounted) return;
        if (telem != null) {
          _adapterMissStreak = 0;
          setState(() {
            final inlet = telem['inlet'];
            final pdu1 = telem['pdu1'];
            final pdu2 = telem['pdu2'];

            // Keep raw records for outlet control lookup (metricCode discovery),
            // but prefer adapter-normalized numeric values for display.
            final inletRecords =
                (inlet is Map) ? (inlet['records'] as List?) : null;
            final pdu1Records =
                (pdu1 is Map) ? (pdu1['records'] as List?) : null;
            final pdu2Records =
                (pdu2 is Map) ? (pdu2['records'] as List?) : null;
            _pdu1Records = pdu1Records ?? const [];
            _pdu2Records = pdu2Records ?? const [];

            double readNum(dynamic v) {
              if (v is num) return v.toDouble();
              return double.tryParse(v?.toString() ?? '') ?? 0.0;
            }

            // Inlet
            final inletKw = (inlet is Map) ? readNum(inlet['kw']) : 0.0;
            final inletOnline =
                (inlet is Map) ? (inlet['online'] == true) : false;
            _inletP = inletKw;
            _inletOnline = inletOnline || (inletRecords?.isNotEmpty == true);
            // We intentionally do not depend on VOLTS/AMPS (omitted in UI).
            _inletV = 0.0;
            _inletA = 0.0;

            // PDU summaries
            _pdu1P = (pdu1 is Map) ? readNum(pdu1['kw']) : 0.0;
            _pdu1A = (pdu1 is Map) ? readNum(pdu1['amps']) : 0.0;
            _pdu1Online = (pdu1 is Map)
                ? (pdu1['online'] == true || _pdu1P > 0 || _pdu1A > 0)
                : false;
            _pdu2P = (pdu2 is Map) ? readNum(pdu2['kw']) : 0.0;
            _pdu2A = (pdu2 is Map) ? readNum(pdu2['amps']) : 0.0;
            _pdu2Online = (pdu2 is Map)
                ? (pdu2['online'] == true || _pdu2P > 0 || _pdu2A > 0)
                : false;
            _pdu1Records = (pdu1 is Map && pdu1['records'] is List)
                ? List<dynamic>.from(pdu1['records'] as List)
                : [];
            _pdu2Records = (pdu2 is Map && pdu2['records'] is List)
                ? List<dynamic>.from(pdu2['records'] as List)
                : [];

            // Per-outlet watts (prefer adapter-normalized list)
            void fillOutlets(
              dynamic pduObj,
              Map<int, double> wattsTarget,
              Map<int, bool> onlineTarget,
              Map<int, String?> controlCodeTarget,
              Map<int, int?> controlValueTarget,
            ) {
              for (int i = 1; i <= 16; i++) {
                wattsTarget[i] = 0.0;
                onlineTarget[i] = false;
                controlCodeTarget[i] = null;
                controlValueTarget[i] = null;
              }
              if (pduObj is! Map) return;
              final outs = pduObj['outlets'];
              if (outs is! List) return;
              for (final o in outs) {
                if (o is! Map) continue;
                final idxRaw = o['index'];
                final idx = (idxRaw is num)
                    ? idxRaw.toInt()
                    : int.tryParse(idxRaw?.toString() ?? '');
                if (idx == null) continue;
                wattsTarget[idx] = readNum(o['watts']);
                final c = o['control'];
                final controlSaysOn = c is Map && c['value'] == 1;
                onlineTarget[idx] = o['isOn'] == true ||
                    wattsTarget[idx]! > 0.5 ||
                    controlSaysOn;
                if (c is Map) {
                  controlCodeTarget[idx] = c['metricCode']?.toString();
                  final v = c['value'];
                  if (v is num) {
                    controlValueTarget[idx] = v.toInt();
                  } else if (v is String) {
                    controlValueTarget[idx] = int.tryParse(v);
                  }
                }
              }
            }

            fillOutlets(pdu1, _pdu1Outlets, _pdu1OutletOnline,
                _pdu1OutletControlCodes, _pdu1OutletControlValues);
            fillOutlets(pdu2, _pdu2Outlets, _pdu2OutletOnline,
                _pdu2OutletControlCodes, _pdu2OutletControlValues);

            _loading = false;
          });

          AppLog.d(
            'rack-telemetry kw sample',
            tag: 'RackView',
            fields: {
              'inletKw': (telem['inlet'] as Map?)?['kw'],
              'pdu1Kw': (telem['pdu1'] as Map?)?['kw'],
              'pdu2Kw': (telem['pdu2'] as Map?)?['kw'],
            },
          );
          return;
        }

        _adapterMissStreak += 1;
        if (!_showAdapterDegraded) {
          // Avoid mixed-source polling spikes for short adapter blips.
          AppLog.w(
            'Adapter rack telemetry returned null; retrying adapter before direct fallback',
            tag: 'RackView',
            fields: {'siteId': siteId, 'missStreak': _adapterMissStreak},
          );
          setState(() => _loading = false);
          return;
        }

        AppLog.w(
          'Adapter degraded; enabling direct rack fallback',
          tag: 'RackView',
          fields: {'siteId': siteId, 'missStreak': _adapterMissStreak},
        );
      }

      final results = await Future.wait([
        ApiService.instance.fetchNodeWithMetric(6), // PDU 1 rich snapshot
        ApiService.instance.fetchNodeWithMetric(7), // PDU 2 rich snapshot
        ApiService.instance.fetchNodeWithMetric(1), // Main UPS rich snapshot
        ApiService.instance.fetchNodeMetrics(6), // PDU 1 metric list fallback
        ApiService.instance.fetchNodeMetrics(7), // PDU 2 metric list fallback
        ApiService.instance
            .fetchNodeMetrics(1), // Main UPS metric list fallback
      ]);

      if (!mounted) return;

      setState(() {
        _adapterMissStreak = 0;
        List<dynamic> recordsFrom(dynamic payload) {
          if (payload is! Map) return const [];
          final result = payload['result'];
          if (result is! Map) return const [];
          final metrics = result['metrics'];
          if (metrics is List) return List<dynamic>.from(metrics);
          final records = result['records'];
          if (records is List) return List<dynamic>.from(records);
          final list = result['list'];
          if (list is List) return List<dynamic>.from(list);
          final data = result['data'];
          if (data is List) return List<dynamic>.from(data);
          return const [];
        }

        // PDU 1 (Node 6)
        final pdu1Res = results[0];
        final pdu1MetricRes = results[3];
        final pdu1Records = _mergeMetricRecords(
          recordsFrom(pdu1Res),
          recordsFrom(pdu1MetricRes),
        );
        if (pdu1Records.isNotEmpty) {
          final records = pdu1Records;
          _pdu1Records = records;
          _pdu1P = _getMetric(
                  records,
                  SiteRuntimeConfig.metricCodeForNode(
                    CpanelApiService.instance.currentSite,
                    6,
                    fallback: 'pdu_active_power_single_phase',
                  )) /
              1000.0;
          if (_pdu1P == 0) {
            _pdu1P = _getMetric(records, 'activepowersinglephase_') / 1000.0;
          }
          if (_pdu1P == 0) {
            _pdu1P = _getMetric(records, 'active_power_single_phase') / 1000.0;
          }
          _pdu1A = _getMetric(records, 'currenvaluesinglephase_');
          if (_pdu1A == 0) _pdu1A = _getMetric(records, 'current_single_phase');
          for (int i = 1; i <= 16; i++) {
            _pdu1Outlets[i] = _getOutletActivePower(records, i);
            final control = _findOutletControl(records, i);
            _pdu1OutletControlCodes[i] = control.code;
            _pdu1OutletControlValues[i] = control.value;
            _pdu1OutletOnline[i] = _outletIsOn(
                records: records, watts: _pdu1Outlets[i] ?? 0.0, index: i);
          }
          _pdu1Online = _pdu1P > 0 || _pdu1A > 0 || records.isNotEmpty;
        }

        // PDU 2 (Node 7)
        final pdu2Res = results[1];
        final pdu2MetricRes = results[4];
        final pdu2Records = _mergeMetricRecords(
          recordsFrom(pdu2Res),
          recordsFrom(pdu2MetricRes),
        );
        if (pdu2Records.isNotEmpty) {
          final records = pdu2Records;
          _pdu2Records = records;
          _pdu2P = _getMetric(
                  records,
                  SiteRuntimeConfig.metricCodeForNode(
                    CpanelApiService.instance.currentSite,
                    7,
                    fallback: 'pdu_active_power_single_phase',
                  )) /
              1000.0;
          if (_pdu2P == 0) {
            _pdu2P = _getMetric(records, 'activepowersinglephase_') / 1000.0;
          }
          if (_pdu2P == 0) {
            // Some firmware uses non-hashed metric codes.
            _pdu2P = _getMetric(records, 'active_power_single_phase') / 1000.0;
          }

          _pdu2A = _getMetric(records, 'currenvaluesinglephase_');
          if (_pdu2A == 0) _pdu2A = _getMetric(records, 'current_single_phase');
          for (int i = 1; i <= 16; i++) {
            _pdu2Outlets[i] = _getOutletActivePower(records, i);
            final control = _findOutletControl(records, i);
            _pdu2OutletControlCodes[i] = control.code;
            _pdu2OutletControlValues[i] = control.value;
            _pdu2OutletOnline[i] = _outletIsOn(
                records: records, watts: _pdu2Outlets[i] ?? 0.0, index: i);
          }
          _pdu2Online = _pdu2P > 0 || _pdu2A > 0 || records.isNotEmpty;
        }

        // Main UPS (Node 1)
        final inletRes = results[2];
        final inletMetricRes = results[5];
        final inletRecords = _mergeMetricRecords(
          recordsFrom(inletRes),
          recordsFrom(inletMetricRes),
        );
        _inletV = _getMetric(inletRecords, 'voltagevaluesinglephase_');
        if (_inletV == 0) _inletV = _getMetric(inletRecords, 'voltage');

        _inletA = _getMetric(inletRecords, 'currenvaluesinglephase_');
        if (_inletA == 0) _inletA = _getMetric(inletRecords, 'current');

        _inletP = _getMetric(
                inletRecords,
                SiteRuntimeConfig.metricCodeForNode(
                  CpanelApiService.instance.currentSite,
                  1,
                  fallback: 'pdu_active_power_single_phase',
                )) /
            1000.0;
        if (_inletP == 0) _inletP = (_pdu1P + _pdu2P);

        if (_inletA == 0 && _inletP > 0 && _inletV > 0) {
          _inletA = (_inletP * 1000) / _inletV;
        }
        _inletOnline = _inletV > 0 || _inletP > 0 || inletRecords.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _getMetric(List<dynamic> records, String codePrefix) {
    for (final r in records) {
      final code =
          (r['code'] ?? r['metricTypeLibCode'] ?? r['name'])?.toString() ?? '';
      if (code.startsWith(codePrefix) || code == codePrefix) {
        final val = r['value'] ?? r['val'];
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? 0.0;
      }
    }
    return 0.0;
  }

  double _getMetricByExactName(List<dynamic> records, String name) {
    final want = name.trim().toLowerCase();
    for (final r in records) {
      final currentName = (r['name'])?.toString().trim().toLowerCase() ?? '';
      if (currentName != want) continue;
      final val = r['value'] ?? r['val'];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
  }

  double _getOutletActivePower(List<dynamic> records, int index) {
    final byCode = _getMetric(records, 'outlet${index}activepower_');
    if (byCode != 0) return byCode;
    final altCode = _getMetric(records, 'outlet_${index}_active_power');
    if (altCode != 0) return altCode;
    return _getMetricByExactName(records, 'Outlet $index Active Power');
  }

  double _getOutletCurrent(List<dynamic> records, int index) {
    final byCode = _getMetric(records, 'outlet${index}current_');
    if (byCode != 0) return byCode;
    final altCode = _getMetric(records, 'outlet_${index}_current');
    if (altCode != 0) return altCode;
    return _getMetricByExactName(records, 'Outlet $index Current');
  }

  double _getOutletEnergy(List<dynamic> records, int index) {
    final byCode = _getMetric(records, 'outlet_${index}_electrical_energy');
    if (byCode != 0) return byCode;
    final altCode = _getMetric(records, 'outlet${index}electricenergy_');
    if (altCode != 0) return altCode;
    return _getMetricByExactName(records, 'Outlet $index Energy');
  }

  double _getOutletPowerFactor(List<dynamic> records, int index) {
    final byCode = _getMetric(records, 'outlet_${index}_power_factor');
    if (byCode != 0) return byCode;
    return _getMetricByExactName(records, 'Outlet $index Power Factor');
  }

  List<dynamic> _mergeMetricRecords(
      List<dynamic> primary, List<dynamic> extra) {
    final out = <dynamic>[];
    final seen = <String>{};
    for (final r in [...primary, ...extra]) {
      final key =
          ((r['code'] ?? r['metricTypeLibCode'] ?? r['name'])?.toString() ?? '')
              .trim()
              .toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(r);
    }
    return out;
  }

  ({String? code, int? value}) _findOutletControl(
      List<dynamic> records, int index) {
    final patterns = <String>[
      'outlet${index}onoffcontrol_',
      'outlet_${index}_onoffcontrol_',
      'outlet_${index}_on_off_control',
    ];
    for (final r in records) {
      final code =
          (r['code'] ?? r['metricTypeLibCode'] ?? r['name'])?.toString() ?? '';
      final lower = code.toLowerCase();
      final matched = patterns.any((p) => lower.startsWith(p)) ||
          (lower.contains('outlet$index') &&
              lower.contains('control') &&
              lower.contains('on')) ||
          (lower.contains('outlet_${index}_') && lower.contains('control')) ||
          ((r['name']?.toString().trim().toLowerCase() ?? '') ==
              'outlet $index output control'.toLowerCase());
      if (!matched) continue;
      final raw = r['value'] ?? r['val'] ?? r['writerVal'];
      int? value;
      if (raw is num) {
        value = raw.toInt();
      } else if (raw is String) {
        value = int.tryParse(raw);
      }
      return (code: code, value: value);
    }
    return (code: null, value: null);
  }


  bool _outletIsOn(
      {required List<dynamic> records,
      required double watts,
      required int index}) {
    final amps = _getOutletCurrent(records, index);
    final control = _findOutletControl(records, index);
    final controlSaysOn = control.value == 1;
    return watts > 0.5 || amps > 0.05 || controlSaysOn;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final uiScale =
        screenWidth >= 900 ? (screenWidth / 1150).clamp(1.0, 1.25) : 1.0;

    final isVerySmall = screenWidth < 360;
    final hPadding = screenWidth * 0.06;
    final columns = isVerySmall ? 3 : 4;
    final bool sideBySide = screenWidth >= 720;
    final int effectivePduColumns =
        sideBySide ? (screenWidth >= 1100 ? 4 : 2) : columns;
    final showSkeleton = _loading || _refreshing;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          edgeOffset: AppConstants.headerClearance(context),
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(
                hPadding, AppConstants.headerClearance(context), hPadding, AppSpacing.pageBottom(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showAdapterDegraded) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB020).withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFFFB020).withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Text(
                        'Data source reconnecting...',
                        style: TextStyle(
                          color: Color(0xFFFFD479),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
                showSkeleton
                    ? _buildInletCardSkeleton(uiScale)
                    : _buildInletCard(uiScale),
                const SizedBox(height: 16),
                showSkeleton
                    ? _buildOutletCardSkeleton(
                        columns: effectivePduColumns,
                        uiScale: uiScale,
                        sideBySide: sideBySide)
                    : _buildOutletCard(
                        columns: effectivePduColumns,
                        uiScale: uiScale,
                        sideBySide: sideBySide),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInletCardSkeleton(double uiScale) {
    return DashboardGlass(
      radius: 22 * uiScale,
      padding: EdgeInsets.all(18 * uiScale),
      tint: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: Theme.of(context).brightness == Brightness.light
          ? AppTheme.lightStroke
          : const Color(0x22FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(
                  width: 70 * uiScale,
                  height: 14 * uiScale,
                  borderRadius: BorderRadius.circular(8)),
              const Spacer(),
              Skeleton(
                  width: 18 * uiScale,
                  height: 18 * uiScale,
                  borderRadius: BorderRadius.circular(6)),
            ],
          ),
          SizedBox(height: 14 * uiScale),
          Skeleton(
              height: 18 * uiScale, borderRadius: BorderRadius.circular(10)),
          SizedBox(height: 10 * uiScale),
          Row(
            children: [
              Expanded(
                  child: Skeleton(
                      height: 44 * uiScale,
                      borderRadius: BorderRadius.circular(16))),
              SizedBox(width: 12 * uiScale),
              Expanded(
                  child: Skeleton(
                      height: 44 * uiScale,
                      borderRadius: BorderRadius.circular(16))),
            ],
          ),
          SizedBox(height: 14 * uiScale),
          Skeleton(
              height: 10 * uiScale, borderRadius: BorderRadius.circular(8)),
        ],
      ),
    );
  }

  Widget _buildOutletCardSkeleton(
      {required int columns,
      required double uiScale,
      required bool sideBySide}) {
    Widget pduSkeleton() => DashboardGlass(
          radius: 18 * uiScale,
          padding: EdgeInsets.all(14 * uiScale),
          tint: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF0B0F14).withValues(alpha: 0.65),
          borderColor: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightStroke
              : const Color(0x22FFFFFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Skeleton(
                      width: 110 * uiScale,
                      height: 12 * uiScale,
                      borderRadius: BorderRadius.circular(8)),
                  const Spacer(),
                  Skeleton(
                      width: 18 * uiScale,
                      height: 18 * uiScale,
                      borderRadius: BorderRadius.circular(6)),
                ],
              ),
              SizedBox(height: 12 * uiScale),
              Skeleton(
                  height: 12 * uiScale, borderRadius: BorderRadius.circular(8)),
              SizedBox(height: 10 * uiScale),
              Wrap(
                spacing: 10 * uiScale,
                runSpacing: 10 * uiScale,
                children: List.generate(
                    sideBySide ? 8 : columns * 2,
                    (_) => Skeleton(
                        width: (sideBySide ? 96 : 86) * uiScale,
                        height: 42 * uiScale,
                        borderRadius: BorderRadius.circular(14))),
              ),
            ],
          ),
        );

    return DashboardGlass(
      radius: 22 * uiScale,
      padding: EdgeInsets.all(18 * uiScale),
      tint: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: Theme.of(context).brightness == Brightness.light
          ? AppTheme.lightStroke
          : const Color(0x22FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(
                  width: 80 * uiScale,
                  height: 14 * uiScale,
                  borderRadius: BorderRadius.circular(8)),
              const Spacer(),
              Skeleton(
                  width: 18 * uiScale,
                  height: 18 * uiScale,
                  borderRadius: BorderRadius.circular(6)),
            ],
          ),
          SizedBox(height: 14 * uiScale),
          if (sideBySide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: pduSkeleton()),
              SizedBox(width: 12 * uiScale),
              Expanded(child: pduSkeleton())
            ])
          else ...[
            pduSkeleton(),
            SizedBox(height: 12 * uiScale),
            pduSkeleton()
          ],
        ],
      ),
    );
  }

  Widget _buildInletCard(double uiScale) {
    final loadPct = (_inletP / _totalRackMaxKw).clamp(0.0, 1.0);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DashboardGlass(
      radius: 22 * uiScale,
      padding: EdgeInsets.all(18 * uiScale),
      tint: isLight
          ? Colors.white
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: isLight ? AppTheme.lightStroke : const Color(0x22FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded,
                  color: AppTheme.accentGreen, size: 18 * uiScale),
              const SizedBox(width: 8),
              Text('INLET',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextPrimary
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1)),
              const SizedBox(width: 8),
              _infoIcon(
                  uiScale: uiScale,
                  onTap: () => _showInfoDialog(
                      title: 'Inlet (Total Rack Load)',
                      body:
                          'Total Rack Load is the active power feeding the rack.')),
              const Spacer(),
              _statusPill(online: _inletOnline, uiScale: uiScale),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_inletP.toStringAsFixed(2)} kW',
            style: TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 38 * uiScale,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Total Rack Load',
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontSize: 13.5 * uiScale,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // VOLTS/AMPS are omitted because many vendor builds report them as null/0.
          const SizedBox(height: 4),
          Row(
            children: [
              Text('RACK LOAD',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextSecondary
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
              const Spacer(),
              Text(
                  '${(loadPct * 100).round()}% of ${_totalRackMaxKw.toInt()}kW',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextSecondary
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: loadPct,
              minHeight: 12,
              // Light mode needs a visible track behind the green fill.
              backgroundColor: isLight
                  ? const Color(0xFFD0D5DD)
                  : Colors.white.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard(
      {required int columns,
      required double uiScale,
      required bool sideBySide}) {
    final pdu1 = _buildPduPanel(
        nodeId: 6,
        title: 'RACK PDU 1',
        online: _pdu1Online,
        pKw: _pdu1P,
        pA: _pdu1A,
        records: _pdu1Records,
        outlets: _pdu1Outlets,
        outletOnline: _pdu1OutletOnline,
        outletControlCodes: _pdu1OutletControlCodes,
        outletControlValues: _pdu1OutletControlValues,
        expanded: _pdu1Expanded,
        columns: columns,
        uiScale: uiScale,
        onToggle: sideBySide
            ? null
            : () => setState(() => _pdu1Expanded = !_pdu1Expanded));
    final pdu2 = _buildPduPanel(
        nodeId: 7,
        title: 'RACK PDU 2',
        online: _pdu2Online,
        pKw: _pdu2P,
        pA: _pdu2A,
        records: _pdu2Records,
        outlets: _pdu2Outlets,
        outletOnline: _pdu2OutletOnline,
        outletControlCodes: _pdu2OutletControlCodes,
        outletControlValues: _pdu2OutletControlValues,
        expanded: _pdu2Expanded,
        columns: columns,
        uiScale: uiScale,
        onToggle: sideBySide
            ? null
            : () => setState(() => _pdu2Expanded = !_pdu2Expanded));

    return DashboardGlass(
      radius: 22 * uiScale,
      padding: EdgeInsets.all(18 * uiScale),
      tint: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: Theme.of(context).brightness == Brightness.light
          ? AppTheme.lightStroke
          : const Color(0x22FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.outlet_rounded,
                  color: Colors.lightBlueAccent, size: 18 * uiScale),
              const SizedBox(width: 8),
              Text('OUTLET',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextPrimary
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1)),
              const SizedBox(width: 8),
              _infoIcon(
                  uiScale: uiScale,
                  onTap: () => _showInfoDialog(
                      title: 'Outlet (PDU Outputs)',
                      body:
                          'Each PDU card shows total power (kW) and current (A), plus per-outlet active power.')),
            ],
          ),
          const SizedBox(height: 14),
          if (sideBySide) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: pdu1),
              const SizedBox(width: 14),
              Expanded(child: pdu2)
            ]),
            const SizedBox(height: 14),
            Center(
              child: InkWell(
                onTap: () => setState(() {
                  _pdu1Expanded = !_pdu1Expanded;
                  _pdu2Expanded = _pdu1Expanded;
                }),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_pdu1Expanded ? 'COLLAPSE ALL' : 'EXPAND ALL',
                          style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                      Icon(
                          _pdu1Expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.orangeAccent)
                    ])),
              ),
            ),
          ] else ...[
            pdu1,
            const SizedBox(height: 14),
            pdu2
          ],
        ],
      ),
    );
  }

  Widget _buildPduPanel(
      {required int nodeId,
      required String title,
      required bool online,
      required double pKw,
      required double pA,
      required List<dynamic> records,
      required Map<int, double> outlets,
      required Map<int, bool> outletOnline,
      Map<int, String?>? outletControlCodes,
      Map<int, int?>? outletControlValues,
      required bool expanded,
      required int columns,
      required double uiScale,
      VoidCallback? onToggle}) {
    final allOutlets = List.generate(16, (i) => i + 1);
    final activeOrKnown =
        allOutlets.where((i) => (outlets[i] ?? 0.0) > 0.5).toList();
    final showing = expanded
        ? allOutlets
        : (activeOrKnown.isNotEmpty ? activeOrKnown : allOutlets);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AnimatedSize(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding: EdgeInsets.all(12 * uiScale),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18 * uiScale),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14 * uiScale,
                            color: isLight
                                ? const Color(0xFFFFB020)
                                : const Color(0xFFFFD15C),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${pKw.toStringAsFixed(2)} kW',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextSecondary
                                  : Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.speed_rounded,
                            size: 14 * uiScale,
                            color: isLight
                                ? const Color(0xFF2F7BFF)
                                : const Color(0xFF7DB7FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${pA.toStringAsFixed(1)}A',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextSecondary
                                  : Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              reverseDuration: const Duration(milliseconds: 340),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: GridView.builder(
                key: ValueKey<String>(
                    'pdu_${nodeId}_${expanded}_${showing.length}'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: columns == 3 ? 0.76 : 0.65,
                ),
                itemCount: showing.length,
                itemBuilder: (context, idx) {
                  final n = showing[idx];
                  final w = outlets[n] ?? 0.0;
                  return _outletTile(
                    nodeId: nodeId,
                    outletNum: n,
                    watts: w,
                    isOn: w > 0.5,
                    records: records,
                    controlMetricCode: outletControlCodes?[n],
                    controlCurrentValue: outletControlValues?[n],
                    uiScale: uiScale,
                  );
                },
              ),
            ),
            if (onToggle != null)
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    turns: expanded ? 0.0 : 0.5,
                    child: const Icon(Icons.keyboard_arrow_up,
                        color: Colors.orangeAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOutletDetailsSheet({
    required int nodeId,
    required int outletNum,
    required double watts,
    required bool isOn,
    required List<dynamic> records,
    required double uiScale,
  }) async {
    final amps = _getOutletCurrent(records, outletNum);
    final kwh = _getOutletEnergy(records, outletNum);
    final pf = _getOutletPowerFactor(records, outletNum);
    final hasEnergy = kwh > 0;
    final hasPf = pf > 0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        final sheetTint = isLight ? Colors.white : const Color(0xFF0E141B);
        final sheetBorder =
            isLight ? AppTheme.lightStroke : const Color(0x22FFFFFF);
        final labelColor =
            isLight ? AppTheme.lightTextSecondary : Colors.white70;
        final valueColor = isLight ? AppTheme.lightTextPrimary : Colors.white;
        final iconColor = isLight
            ? AppTheme.lightTextSecondary.withValues(alpha: 0.80)
            : Colors.white.withValues(alpha: 0.75);

        Widget row({
          required String label,
          required String value,
          IconData? icon,
        }) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5 * uiScale,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13 * uiScale,
                  ),
                ),
              ],
            ),
          );
        }

        return DashboardGlass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          tint: sheetTint.withValues(alpha: isLight ? 0.98 : 0.96),
          borderColor: sheetBorder,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'PDU $nodeId  Outlet $outletNum',
                    style: TextStyle(
                        color: valueColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14 * uiScale),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppTheme.accentGreen.withValues(alpha: 0.18)
                      : (isLight
                          ? const Color(0xFFE5E7EB)
                          : Colors.white.withValues(alpha: 0.10)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOn ? Icons.power_rounded : Icons.power_off_rounded,
                      size: 18,
                      color: isOn
                          ? AppTheme.accentGreen
                          : (isLight
                              ? AppTheme.lightTextSecondary
                              : Colors.white.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isOn ? 'Status: On' : 'Status: Off',
                      style: TextStyle(
                        color: valueColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              row(
                label: 'Power (Watts)',
                value: '${watts.round()} W',
                icon: Icons.bolt_rounded,
              ),
              row(
                label: 'Current (Amps)',
                value: '${amps.toStringAsFixed(2)} A',
                icon: Icons.speed_rounded,
              ),
              if (hasEnergy)
                row(
                  label: 'Energy (kWh)',
                  value: kwh.toStringAsFixed(2),
                  icon: Icons.stacked_line_chart_rounded,
                ),
              if (hasPf)
                row(
                  label: 'Power factor',
                  value: pf.toStringAsFixed(2),
                  icon: Icons.tune_rounded,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _outletTile(
      {required int nodeId,
      required int outletNum,
      required double watts,
      required bool isOn,
      required List<dynamic> records,
      String? controlMetricCode,
      int? controlCurrentValue,
      required double uiScale}) {
    final pct = (watts / _outletMaxWatts).clamp(0.0, 1.0);
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Outlet tile palette tuned to match WhitePower.png:
    // - ON: solid green tile with white text
    // - OFF: solid grey tile with dark text
    const onFill = AppTheme.accentGreen;
    const offFillLight = Color(0xFFD9D9D9);
    final offFillDark = Colors.white.withValues(alpha: 0.10);
    final fill = isOn ? onFill : (isLight ? offFillLight : offFillDark);

    const onText = Colors.white;
    const offTextLight = Color(0xFF555555);
    final offTextDark = Colors.white.withValues(alpha: 0.70);
    final text = isOn ? onText : (isLight ? offTextLight : offTextDark);

    // Give every slot a subtle stroke so the grid reads nicely.
    // In light mode, use a soft black stroke; in dark mode, a soft white stroke.
    final border = isLight
        ? Colors.black.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.12);
    return InkWell(
      onTap: () => _showOutletDetailsSheet(
        nodeId: nodeId,
        outletNum: outletNum,
        watts: watts,
        isOn: isOn,
        records: records,
        uiScale: uiScale,
      ),
      borderRadius: BorderRadius.circular(14 * uiScale),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14 * uiScale),
          border: Border.all(color: border, width: 1.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('U$outletNum',
                style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w900,
                    fontSize: 11 * uiScale)),
            if (isOn) ...[
              Text('${watts.round()}W',
                  style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5 * uiScale)),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.90)
                      : text.withValues(alpha: 0.85),
                  fontSize: 10 * uiScale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ] else
              Text('OFF',
                  style: TextStyle(
                      color: text,
                      fontSize: 11 * uiScale,
                      fontWeight: FontWeight.w900)),
            // Tap opens a read-only details sheet (switching is in Control Panel).
          ],
        ),
      ),
    );
  }

  Widget _statusPill({required bool online, required double uiScale}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final c = online ? AppTheme.accentGreen : AppTheme.statusError;
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 16 * uiScale, vertical: 6 * uiScale),
      decoration: BoxDecoration(
        color: online
            ? c
            : (isLight
                ? const Color(0xFFE5E7EB)
                : Colors.white.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(999),
        boxShadow: online
            ? [
                BoxShadow(
                  color: c.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
        border: online
            ? null
            : Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.10),
              ),
      ),
      child: Text(
        online ? 'ONLINE' : 'OFFLINE',
        style: TextStyle(
          color: online
              ? Colors.white
              : (isLight
                  ? AppTheme.lightTextPrimary
                  : Colors.white.withValues(alpha: 0.85)),
          fontSize: 11.5 * uiScale,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _infoIcon({required VoidCallback onTap, required double uiScale}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      onTap: onTap,
      child: Icon(
        Icons.info_outline_rounded,
        size: 16 * uiScale,
        color: isLight
            ? AppTheme.lightTextSecondary.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.4),
      ),
    );
  }

  void _showInfoDialog({required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: DashboardGlass(
            radius: 18,
            padding: const EdgeInsets.all(18),
            tint: isLight ? Colors.white : const Color(0xFF0E141B),
            borderColor:
                isLight ? AppTheme.lightStroke : const Color(0x22FFFFFF),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isLight
                              ? AppTheme.lightTextPrimary
                              : Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white70,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: TextStyle(
                    color:
                        isLight ? AppTheme.lightTextSecondary : Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
