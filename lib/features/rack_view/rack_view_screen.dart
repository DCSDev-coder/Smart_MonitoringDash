import 'dart:async';
import 'dart:ui';
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
import '../../shared/widgets/header_refresh_bar.dart';
import '../../shared/utils/pull_to_refresh_gate.dart';

import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/kiosk_user_pin_sheet.dart';
import '../../shared/widgets/secure_action_guard.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/utils/app_toast.dart';

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
  RefreshIndicatorStatus? _refreshStatus;
  Timer? _refreshTimer;
  Duration _interval = SmartPollingSettings.instance.normalInterval();
  final PullToRefreshGate _refreshGate = PullToRefreshGate();

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

  final ScrollController _scrollController = ScrollController();

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
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    _refreshGate.beginRefresh();
    setState(() => _refreshing = true);
    try {
      await _fetchRackData();
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
        if (!ApiService.instance.canUseDirectFallback) {
          setState(() => _loading = false);
          return;
        }
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

    if (mounted) {
      AppToast.setReconnecting(context, _showAdapterDegraded);
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
    final hPadding = AppSpacing.pageHorizontal(context);
    final columns = isVerySmall ? 3 : 4;
    final bool sideBySide = screenWidth >= 720;
    final int effectivePduColumns =
        columns; // Use the same 4 columns everywhere since PDU takes half screen on tablet
    final showSkeleton = _loading || _refreshing;

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
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      hPadding,
                      AppConstants.headerClearance(context),
                      hPadding,
                      AppSpacing.pageBottom(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        showSkeleton
                            ? _buildInletCardSkeleton(uiScale)
                            : (sideBySide
                                ? _buildInletCardDesktop(uiScale)
                                : _buildInletCardMobile(uiScale)),
                        const SizedBox(height: 16),
                        showSkeleton
                            ? _buildOutletCardSkeleton(
                                columns: effectivePduColumns,
                                uiScale: uiScale,
                                sideBySide: sideBySide)
                            : (sideBySide
                                ? _buildOutletCardDesktop(
                                    columns: effectivePduColumns,
                                    uiScale: uiScale,
                                    sideBySide: sideBySide)
                                : _buildOutletCardMobile(
                                    columns: effectivePduColumns,
                                    uiScale: uiScale)),
                      ],
                    ),
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

  Widget _buildInletCardSkeleton(double uiScale) {
    return DashboardGlass(
      radius: 22 * uiScale,
      padding: EdgeInsets.all(18 * uiScale),
      tint: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF111922).withValues(alpha: 0.92),
      borderColor: Theme.of(context).brightness == Brightness.light
          ? AppTheme.lightStroke
          : Colors.transparent,
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
              : Colors.transparent,
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
          : const Color(0xFF111922).withValues(alpha: 0.92),
      borderColor: Theme.of(context).brightness == Brightness.light
          ? AppTheme.lightStroke
          : Colors.transparent,
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

  Future<void> _toggleOutlet({
    required int nodeId,
    required int outletNum,
    required bool desiredOn,
    String? controlMetricCode,
  }) async {
    final site = CpanelApiService.instance.currentSite;
    final siteId = SiteRuntimeConfig.siteId(site);
    final metricCode = controlMetricCode ?? 'outlet${outletNum}onoffcontrol_';
    final targetVal = desiredOn ? 1 : 0;
    final isRackConsoleMode =
        CpanelApiService.instance.isCurrentSiteRackConsole(site);

    RackConsoleApprovalResult? rackConsoleApproval;
    if (isRackConsoleMode) {
      rackConsoleApproval = await RackConsoleUserPinSheet.show(
        context,
        title: 'RACK CONSOLE CONTROL APPROVAL',
        reason:
            'Enter the approving user PIN to turn ${desiredOn ? "ON" : "OFF"} PDU $nodeId Outlet $outletNum.',
        confirmLabel: 'Approve and Switch',
      );
      if (!mounted || rackConsoleApproval == null) return;
    } else {
      final authorized = await SecureActionGuard.ensureAuthorized(
        context,
        reason:
            'Confirm to turn ${desiredOn ? "ON" : "OFF"} PDU $nodeId Outlet $outletNum',
        ttl: const Duration(seconds: 30),
        allowPin: true,
      );
      if (!mounted || !authorized) return;
    }

    if (!mounted) return;
    AppToast.show(
        context, 'Switching Outlet $outletNum ${desiredOn ? "ON" : "OFF"}...');

    try {
      Map<String, dynamic>? res;
      if (isRackConsoleMode && siteId != null && rackConsoleApproval != null) {
        res = await AdapterApiService.instance.writeNodeMetricWithUserPin(
          siteId: siteId,
          nodeId: nodeId,
          metricTypeLibCode: metricCode,
          value: targetVal,
          pin: rackConsoleApproval.pin,
        );
      } else if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.writeNodeMetric(
          siteId: siteId,
          nodeId: nodeId,
          metricTypeLibCode: metricCode,
          value: targetVal,
        );
      }
      if (!isRackConsoleMode && ApiService.instance.canUseDirectFallback) {
        res ??= await ApiService.instance.writeNodeMetric(
          nodeId: nodeId,
          metricTypeLibCode: metricCode,
          value: targetVal,
        );
      }

      if (!mounted) return;
      final ok = (res?['success'] == true) ||
          (res?['code']?.toString() == '20000');
      if (ok) {
        AppToast.showSuccess(
            context, 'Outlet $outletNum switched ${desiredOn ? "ON" : "OFF"}');
        setState(() {
          if (nodeId == 6) {
            _pdu1OutletOnline[outletNum] = desiredOn;
            _pdu1OutletControlValues[outletNum] = targetVal;
          } else if (nodeId == 7) {
            _pdu2OutletOnline[outletNum] = desiredOn;
            _pdu2OutletControlValues[outletNum] = targetVal;
          }
        });
        _fetchRackData();
      } else {
        final msg = res?['message']?.toString() ?? 'Failed to switch outlet';
        AppToast.showError(context, msg);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to switch outlet: $e');
      }
    }
  }

  Future<void> _confirmToggleOutlet({
    required int nodeId,
    required int outletNum,
    required bool currentlyOn,
    String? controlMetricCode,
  }) async {
    final desiredOn = !currentlyOn;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isLight ? Colors.white : const Color(0xFF131D2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.1)
                : const Color(0xFF1E2D3D),
          ),
        ),
        title: Row(
          children: [
            Icon(
              desiredOn ? Icons.power_rounded : Icons.power_off_rounded,
              color: desiredOn ? const Color(0xFF00E676) : Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              '${desiredOn ? "Turn ON" : "Turn OFF"} Outlet U$outletNum?',
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to turn ${desiredOn ? "ON" : "OFF"} PDU $nodeId Outlet $outletNum?',
          style: TextStyle(
            color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: desiredOn
                  ? const Color(0xFF00A174)
                  : Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(desiredOn ? 'Turn ON' : 'Turn OFF'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _toggleOutlet(
        nodeId: nodeId,
        outletNum: outletNum,
        desiredOn: desiredOn,
        controlMetricCode: controlMetricCode,
      );
    }
  }

  Widget _buildInletCardMobile(double uiScale) {
    final loadPct = (_inletP / _totalRackMaxKw).clamp(0.0, 1.0);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22 * uiScale),
      ),
      child: Padding(
        padding: EdgeInsets.all(18 * uiScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on_rounded,
                    color: const Color(0xFF00A174), size: 18 * uiScale),
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
                _statusPillMobile(online: _inletOnline, uiScale: uiScale),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${_inletP.toStringAsFixed(2)} kW',
              style: TextStyle(
                color: const Color(0xFF00A174),
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
                backgroundColor: isLight
                    ? const Color(0xFFD0D5DD)
                    : Colors.white.withValues(alpha: 0.12),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF00A174)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInletCardDesktop(double uiScale) {
    final loadPct = (_inletP / _totalRackMaxKw).clamp(0.0, 1.0);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [Colors.white, const Color(0xFFF8FAFC)]
              : [const Color(0xFF131D2A), const Color(0xFF0C131D)],
        ),
        borderRadius: BorderRadius.circular(20 * uiScale),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.10)
              : const Color(0xFF1E2D3D),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20 * uiScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32 * uiScale,
                  height: 32 * uiScale,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    Icons.flash_on_rounded,
                    color: const Color(0xFF00E5FF),
                    size: 18 * uiScale,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'INLET',
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontSize: 14 * uiScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                _infoIcon(
                  uiScale: uiScale,
                  onTap: () => _showInfoDialog(
                    title: 'Inlet (Total Rack Load)',
                    body:
                        'Total Rack Load is the active power feeding the rack.',
                  ),
                ),
                const Spacer(),
                _statusPillDesktop(online: _inletOnline, uiScale: uiScale),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _inletP.toStringAsFixed(2),
                  style: TextStyle(
                    color: const Color(0xFF00E5FF),
                    fontSize: 42 * uiScale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'kW',
                  style: TextStyle(
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.70),
                    fontSize: 18 * uiScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total Rack Load',
              style: TextStyle(
                color: isLight
                    ? AppTheme.lightTextSecondary
                    : Colors.white.withValues(alpha: 0.75),
                fontSize: 13.5 * uiScale,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'RACK LOAD',
                  style: TextStyle(
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 11 * uiScale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${(loadPct * 100).round()}% of ${_totalRackMaxKw.toInt()}kW',
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF00E5FF),
                      fontSize: 11.5 * uiScale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFE2E8F0)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: loadPct.clamp(0.015, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF00E676)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF00E5FF).withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletCardMobile(
      {required int columns, required double uiScale}) {
    final pdu1 = _buildPduPanelMobile(
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
        onToggle: () {
          setState(() => _pdu1Expanded = !_pdu1Expanded);
          if (_pdu1Expanded) _scrollToBottom();
        });
    final pdu2 = _buildPduPanelMobile(
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
        onToggle: () {
          setState(() => _pdu2Expanded = !_pdu2Expanded);
          if (_pdu2Expanded) _scrollToBottom();
        });

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22 * uiScale),
      ),
      child: Padding(
        padding: EdgeInsets.all(18 * uiScale),
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
            pdu1,
            const SizedBox(height: 14),
            pdu2,
          ],
        ),
      ),
    );
  }

  Widget _buildOutletCardDesktop(
      {required int columns,
      required double uiScale,
      required bool sideBySide}) {
    final pdu1 = _buildPduPanelDesktop(
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
            : () {
                setState(() => _pdu1Expanded = !_pdu1Expanded);
                if (_pdu1Expanded) _scrollToBottom();
              });
    final pdu2 = _buildPduPanelDesktop(
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
            : () {
                setState(() => _pdu2Expanded = !_pdu2Expanded);
                if (_pdu2Expanded) _scrollToBottom();
              });

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [Colors.white, const Color(0xFFF8FAFC)]
              : [const Color(0xFF131D2A), const Color(0xFF0C131D)],
        ),
        borderRadius: BorderRadius.circular(20 * uiScale),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.10)
              : const Color(0xFF1E2D3D),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20 * uiScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32 * uiScale,
                  height: 32 * uiScale,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    Icons.outlet_rounded,
                    color: const Color(0xFF00E5FF),
                    size: 18 * uiScale,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'OUTLET',
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontSize: 14 * uiScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                _infoIcon(
                  uiScale: uiScale,
                  onTap: () => _showInfoDialog(
                    title: 'Outlet (PDU Outputs)',
                    body:
                        'Each PDU card shows total power (kW) and current (A), plus individual outlet control & telemetry. Tap an outlet to toggle power or view live readings.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sideBySide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: pdu1),
                  const SizedBox(width: 16),
                  Expanded(child: pdu2),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    setState(() {
                      _pdu1Expanded = !_pdu1Expanded;
                      _pdu2Expanded = _pdu1Expanded;
                    });
                    if (_pdu1Expanded) _scrollToBottom();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _pdu1Expanded ? 'COLLAPSE ALL' : 'EXPAND ALL',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _pdu1Expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.orangeAccent,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              pdu1,
              const SizedBox(height: 16),
              pdu2,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPduPanelMobile(
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
          color: isLight
              ? Colors.white
              : const Color(0xFF0B0F14).withValues(alpha: 0.35),
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
                    alignment: Alignment.topCenter,
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
                  mainAxisExtent: 82 * uiScale,
                ),
                itemCount: showing.length,
                itemBuilder: (context, idx) {
                  final n = showing[idx];
                  final w = outlets[n] ?? 0.0;
                  return _outletTileMobile(
                    nodeId: nodeId,
                    outletNum: n,
                    watts: w,
                    isOn: w > 0.5,
                    records: records,
                    uiScale: uiScale,
                  );
                },
              ),
            ),
            if (onToggle != null)
              InkWell(
                borderRadius: BorderRadius.circular(999),
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

  Widget _buildPduPanelDesktop(
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
        padding: EdgeInsets.all(14 * uiScale),
        decoration: BoxDecoration(
          color: isLight
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF0F1722),
          borderRadius: BorderRadius.circular(16 * uiScale),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : const Color(0xFF1B2838),
            width: 1.0,
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
                      Container(
                        width: 8 * uiScale,
                        height: 8 * uiScale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online
                              ? const Color(0xFF00E676)
                              : const Color(0xFF64748B),
                          boxShadow: online
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E676)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13 * uiScale,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9100).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFF9100).withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 13 * uiScale,
                            color: const Color(0xFFFFB300),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pKw.toStringAsFixed(2)} kW',
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFFFD15C),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5 * uiScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            size: 13 * uiScale,
                            color: const Color(0xFF00E5FF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pA.toStringAsFixed(1)}A',
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF80E5FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5 * uiScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    alignment: Alignment.topCenter,
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
                  mainAxisExtent: 74 *
                      uiScale, // Fixed compact height so they are never "too big"
                ),
                itemCount: showing.length,
                itemBuilder: (context, idx) {
                  final n = showing[idx];
                  final w = outlets[n] ?? 0.0;
                  final ctrl = _findOutletControl(records, n);
                  final code = outletControlCodes?[n] ?? (ctrl.code?.isNotEmpty == true ? ctrl.code : null);
                  final val = outletControlValues?[n] ?? ctrl.value;
                  final isOutletOn = outletOnline[n] ?? ((val != null) ? (val == 1) : (w > 0.5));
                  return _outletTileDesktop(
                    nodeId: nodeId,
                    outletNum: n,
                    watts: w,
                    isOn: isOutletOn,
                    records: records,
                    controlMetricCode: code,
                    controlCurrentValue: val,
                    uiScale: uiScale,
                  );
                },
              ),
            ),
            if (onToggle != null)
              InkWell(
                borderRadius: BorderRadius.circular(999),
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

  Future<void> _showOutletDetailsSheetMobile({
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        final sheetTint = isLight ? Colors.white : const Color(0xFF111922);
        final sheetBorder = isLight ? AppTheme.lightStroke : Colors.transparent;
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

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: DashboardGlass(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            tint: sheetTint.withValues(alpha: isLight ? 0.98 : 0.96),
            borderColor: sheetBorder,
            child: SingleChildScrollView(
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
                          ? const Color(0xFF00A174).withValues(alpha: 0.18)
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
                              ? const Color(0xFF00A174)
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOutletDetailsSheetDesktop({
    required int nodeId,
    required int outletNum,
    required double watts,
    required bool isOn,
    required List<dynamic> records,
    String? controlMetricCode,
    required double uiScale,
  }) async {
    final amps = _getOutletCurrent(records, outletNum);
    final kwh = _getOutletEnergy(records, outletNum);
    final pf = _getOutletPowerFactor(records, outletNum);
    final hasEnergy = kwh > 0;
    final hasPf = pf > 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        final sheetTint = isLight ? Colors.white : const Color(0xFF0F1722);
        final sheetBorder = isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E2D3D);
        final labelColor = isLight ? const Color(0xFF64748B) : Colors.white60;
        final valueColor = isLight ? const Color(0xFF0F172A) : Colors.white;

        Widget metricCard({
          required String label,
          required String value,
          required IconData icon,
          required Color accentColor,
        }) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFF131D2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLight
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF1F2E3E),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16 * uiScale, color: accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11 * uiScale,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          color: valueColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5 * uiScale,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: sheetTint,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: sheetBorder, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isOn
                              ? const Color(0xFF00E676).withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isOn
                                ? const Color(0xFF00E676).withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Icon(
                          isOn ? Icons.power_rounded : Icons.power_off_rounded,
                          size: 18 * uiScale,
                          color: isOn ? const Color(0xFF00E676) : Colors.white60,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PDU $nodeId • Outlet $outletNum',
                              style: TextStyle(
                                color: valueColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15 * uiScale,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOn ? 'CIRCUIT ENERGIZED • ON' : 'CIRCUIT DISCONNECTED • OFF',
                              style: TextStyle(
                                color: isOn
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                fontSize: 11 * uiScale,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: isLight
                                ? AppTheme.lightTextSecondary
                                : Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Power Control Box (Interactive)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isLight
                            ? [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)]
                            : [const Color(0xFF131D2A), const Color(0xFF0D141E)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOn
                            ? const Color(0xFF00E676).withValues(alpha: 0.35)
                            : const Color(0xFF1E2D3D),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Power Control',
                                    style: TextStyle(
                                      color: valueColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5 * uiScale,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOn
                                        ? 'Switch to cut circuit power immediately'
                                        : 'Switch to energize outlet load',
                                    style: TextStyle(
                                      color: labelColor,
                                      fontSize: 11 * uiScale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isOn,
                              activeThumbColor: const Color(0xFF00E676),
                              activeTrackColor:
                                  const Color(0xFF00E676).withValues(alpha: 0.35),
                              onChanged: (newVal) async {
                                Navigator.pop(context);
                                await _toggleOutlet(
                                  nodeId: nodeId,
                                  outletNum: outletNum,
                                  desiredOn: newVal,
                                  controlMetricCode: controlMetricCode,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              isOn
                                  ? Icons.power_settings_new_rounded
                                  : Icons.flash_on_rounded,
                              size: 16 * uiScale,
                            ),
                            label: Text(
                              isOn ? 'TURN OFF OUTLET' : 'TURN ON OUTLET',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOn
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                  : const Color(0xFF00E676).withValues(alpha: 0.18),
                              foregroundColor: isOn
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFF00E676),
                              side: BorderSide(
                                color: isOn
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                    : const Color(0xFF00E676).withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await _toggleOutlet(
                                nodeId: nodeId,
                                outletNum: outletNum,
                                desiredOn: !isOn,
                                controlMetricCode: controlMetricCode,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'TELEMETRY READINGS',
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11 * uiScale,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: metricCard(
                          label: 'Active Power',
                          value: '${watts.round()} W',
                          icon: Icons.bolt_rounded,
                          accentColor: const Color(0xFFFFB300),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: metricCard(
                          label: 'Current',
                          value: '${amps.toStringAsFixed(2)} A',
                          icon: Icons.speed_rounded,
                          accentColor: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: metricCard(
                          label: 'Energy Consumption',
                          value: hasEnergy
                              ? '${kwh.toStringAsFixed(2)} kWh'
                              : '0.00 kWh',
                          icon: Icons.stacked_line_chart_rounded,
                          accentColor: const Color(0xFFA855F7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: metricCard(
                          label: 'Power Factor',
                          value: hasPf ? pf.toStringAsFixed(2) : '--',
                          icon: Icons.tune_rounded,
                          accentColor: const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _outletTileMobile(
      {required int nodeId,
      required int outletNum,
      required double watts,
      required bool isOn,
      required List<dynamic> records,
      required double uiScale}) {
    final pct = (watts / _outletMaxWatts).clamp(0.0, 1.0);
    final isLight = Theme.of(context).brightness == Brightness.light;

    const onFill = Color(0xFF00A174);
    const offFillLight = Color(0xFFD9D9D9);
    final offFillDark = Colors.white.withValues(alpha: 0.10);
    final fill = isOn ? onFill : (isLight ? offFillLight : offFillDark);

    const onText = Colors.white;
    const offTextLight = Color(0xFF555555);
    final offTextDark = Colors.white.withValues(alpha: 0.70);
    final text = isOn ? onText : (isLight ? offTextLight : offTextDark);

    final border = isLight
        ? Colors.black.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.12);
    return InkWell(
      onTap: () => _showOutletDetailsSheetMobile(
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
          ],
        ),
      ),
    );
  }

  Widget _outletTileDesktop(
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showOutletDetailsSheetDesktop(
          nodeId: nodeId,
          outletNum: outletNum,
          watts: watts,
          isOn: isOn,
          records: records,
          controlMetricCode: controlMetricCode,
          uiScale: uiScale,
        ),
        onLongPress: () => _confirmToggleOutlet(
          nodeId: nodeId,
          outletNum: outletNum,
          currentlyOn: isOn,
          controlMetricCode: controlMetricCode,
        ),
        borderRadius: BorderRadius.circular(12 * uiScale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: EdgeInsets.symmetric(
            horizontal: 8 * uiScale,
            vertical: 6 * uiScale,
          ),
          decoration: BoxDecoration(
            gradient: isOn
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLight
                        ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]
                        : [const Color(0xFF0B2419), const Color(0xFF071710)],
                  )
                : null,
            color: isOn
                ? null
                : (isLight
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFF111923)),
            borderRadius: BorderRadius.circular(12 * uiScale),
            border: Border.all(
              color: isOn
                  ? (isLight
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF00E676).withValues(alpha: 0.5))
                  : (isLight
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF1E2D3E)),
              width: isOn ? 1.2 : 1.0,
            ),
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E676)
                          .withValues(alpha: isLight ? 0.15 : 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'U$outletNum',
                    style: TextStyle(
                      color: isOn
                          ? (isLight
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFF86EFAC))
                          : (isLight
                              ? const Color(0xFF64748B)
                              : Colors.white.withValues(alpha: 0.5)),
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5 * uiScale,
                    ),
                  ),
                  Container(
                    width: 5.5 * uiScale,
                    height: 5.5 * uiScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOn
                          ? const Color(0xFF00E676)
                          : (isLight
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF334155)),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E676)
                                    .withValues(alpha: 0.8),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isOn) ...[
                Text(
                  '${watts.round()}W',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF14532D)
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13 * uiScale,
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF15803D)
                        : const Color(0xFF00E676),
                    fontSize: 9.5 * uiScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                Text(
                  'OFF',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontSize: 11 * uiScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '-',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
                    fontSize: 9.5 * uiScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPillMobile({required bool online, required double uiScale}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final c = online ? const Color(0xFF00A174) : AppTheme.statusError;
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

  Widget _statusPillDesktop({required bool online, required double uiScale}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * uiScale,
        vertical: 5 * uiScale,
      ),
      decoration: BoxDecoration(
        color: online
            ? const Color(0xFF00E676).withValues(alpha: 0.12)
            : (isLight
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF1E293B)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: online
              ? const Color(0xFF00E676).withValues(alpha: 0.35)
              : (isLight
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF334155)),
          width: 1.0,
        ),
        boxShadow: online
            ? [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6 * uiScale,
            height: 6 * uiScale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online
                  ? const Color(0xFF00E676)
                  : const Color(0xFF94A3B8),
              boxShadow: online
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: online
                  ? (isLight
                      ? const Color(0xFF15803D)
                      : const Color(0xFF00E676))
                  : (isLight
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8)),
              fontSize: 11 * uiScale,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoIcon({required VoidCallback onTap, required double uiScale}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Icon(
          Icons.info_outline_rounded,
          size: 14 * uiScale,
          color: isLight
              ? AppTheme.lightTextSecondary.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  void _showInfoDialog({required String title, required String body}) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isLight = theme.brightness == Brightness.light;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      barrierLabel: '$title Info',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : const Color(0xFF162436),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 8,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF00A174),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: onSurface.withValues(alpha: 0.05),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: onSurface, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        body,
                        style: TextStyle(
                          color: isLight
                              ? AppTheme.lightTextSecondary
                              : Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
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
}
