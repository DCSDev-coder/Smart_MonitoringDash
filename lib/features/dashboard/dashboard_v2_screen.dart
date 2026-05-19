import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/app_log.dart';
import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../report/report_screen.dart';
import '../../core/controllers/global_status_poller.dart';
import '../../core/controllers/smart_polling_settings.dart';
import '../../shared/widgets/secure_action_guard.dart';

// New Modular Widgets
import 'widgets/pue_hero_card.dart';
import 'widgets/environment_gauges.dart';
import 'widgets/service_notice_card.dart';
import 'widgets/door_control_section.dart';
import 'widgets/device_health_section.dart';
import '../../core/constants/app_constants.dart';

/// Dashboard V2 (dark-only) matching `DashboardV2_Page.png`.
///
/// Refactored to be modular and cleaner.
class DashboardV2Screen extends StatefulWidget {
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMenuTap;
  final int notificationCount;
  final bool? notificationCriticalGlow;
  final bool isActive;

  const DashboardV2Screen({
    super.key,
    this.onNotificationTap,
    this.onMenuTap,
    this.notificationCount = 0,
    this.notificationCriticalGlow,
    this.isActive = true,
  });

  @override
  State<DashboardV2Screen> createState() => _DashboardV2ScreenState();
}

class _DashboardV2ScreenState extends State<DashboardV2Screen>
    with WidgetsBindingObserver {
  Timer? _timer;
  final ScrollController _scrollController = ScrollController();
  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;

  bool _loading = true;
  bool _refreshing = false;

  // Environment gauge source
  List<Map<String, dynamic>> _temperatures = [];
  List<Map<String, dynamic>> _humidities = [];

  // Device health source
  List<dynamic> _devices = [];

  // Doors
  List<Map<String, dynamic>>? _doors;

  // Maintenance
  DateTime? _lastMaintenance;

  // Energy
  double _pue = 0.0;
  String _pueStatus = 'down'; // ok | unavailable | error | down
  Map<String, double> _powerMonth = {};

  // Site Environment
  int _smokeStatus = -1;
  int _floodStatus = -1;

  DateTime? _lastTempHumFetch;
  DateTime? _lastDoorsFetch;
  DateTime? _lastPowerMonthFetch;
  DateTime? _lastPueFetch;

  Duration _tickInterval = const Duration(seconds: 10);
  bool _loggedPueUnavailable = false;
  bool _loggedPuePayload = false;

  bool get _canControlDoors {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return true;

    final v = site['can_control_doors'];
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
    WidgetsBinding.instance.addObserver(this);
    _poller.addListener(_syncFromPoller);
    SmartPollingSettings.instance.addListener(_restartTimerIfNeeded);
    _syncFromPoller();
    if (widget.isActive) {
      _fetchAll(isInitial: true);
      _startTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.removeListener(_syncFromPoller);
    SmartPollingSettings.instance.removeListener(_restartTimerIfNeeded);
    _stopTimer();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncFromPoller() {
    if (!mounted) return;
    // Keep dashboard state aligned with global polling to avoid duplicated calls.
    setState(() {
      _smokeStatus = _poller.smokeStatus;
      _floodStatus = _poller.floodStatus;
      _devices = _poller.devices;

      // When the adapter dashboard bundle is active, the global poller carries
      // PUE/power/doors too. This avoids extra per-screen API chatter.
      if (_poller.powerMonth != null) {
        _powerMonth = _poller.powerMonth!;
      }
      if (_poller.pue != null) {
        _pue = _poller.pue!;
      }
      if (_poller.pueStatus != null) {
        _pueStatus = _poller.pueStatus!;
      }
      if (_poller.doors != null) {
        _doors = _poller.doors;
      }
    });
    _restartTimerIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isActive) {
        _startTimer();
        _fetchAll(isInitial: true); // Fresh fetch on resume
      }
    }
  }

  @override
  void didUpdateWidget(covariant DashboardV2Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _fetchAll(isInitial: true);
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    _tickInterval = _desiredTickInterval();
    _timer = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    _fetchAll();
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      // Force a full refresh of all key dashboard endpoints.
      await _fetchAll(isInitial: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Duration _desiredTickInterval() {
    if (_poller.emergencyMode) return const Duration(seconds: 5);
    final base = SmartPollingSettings.instance.normalInterval();
    if (base >= const Duration(seconds: 30)) return const Duration(seconds: 15);
    return const Duration(seconds: 10);
  }

  void _restartTimerIfNeeded() {
    if (!widget.isActive) return;
    final next = _desiredTickInterval();
    if (_timer != null && next == _tickInterval) return;
    _startTimer();
  }

  Future<Map<String, dynamic>?> _fetchPowerMonthWithFallback({
    required int? siteId,
    required String? cabinetId,
  }) async {
    if (AdapterApiService.instance.isConfigured && siteId != null) {
      final viaAdapter =
          await AdapterApiService.instance.fetchPowerMonth(siteId: siteId);
      if (viaAdapter != null) return viaAdapter;
    }
    return ApiService.instance.fetchPowerMonth(id: cabinetId);
  }

  Future<Map<String, dynamic>?> _fetchPueWithFallback({
    required int? siteId,
    required String? cabinetId,
  }) async {
    if (AdapterApiService.instance.isConfigured && siteId != null) {
      final viaAdapter = await AdapterApiService.instance.fetchPue(siteId: siteId);
      if (viaAdapter != null) return viaAdapter;
    }
    return ApiService.instance.fetchPue(id: cabinetId);
  }

  Future<Map<String, dynamic>?> _fetchDoorsWithFallback({
    required int? siteId,
    required String? cabinetId,
  }) async {
    if (AdapterApiService.instance.isConfigured && siteId != null) {
      final viaAdapter =
          await AdapterApiService.instance.fetchDoors(siteId: siteId);
      if (viaAdapter != null) return viaAdapter;
    }
    final parsed = int.tryParse(cabinetId ?? '');
    return ApiService.instance.fetchCabinetDoors(cabinetId: parsed ?? 1);
  }

  Future<void> _fetchAll({bool isInitial = false}) async {
    final now = DateTime.now();

    final mediumInterval = _poller.emergencyMode
        ? const Duration(seconds: 5)
        : SmartPollingSettings.instance.normalInterval();
    final lowInterval = mediumInterval < const Duration(seconds: 15)
        ? const Duration(seconds: 60)
        : Duration(seconds: (mediumInterval.inSeconds * 4).clamp(60, 180));

    final fetchTempHum = isInitial ||
        _lastTempHumFetch == null ||
        now.difference(_lastTempHumFetch!) >= mediumInterval;
    final site = CpanelApiService.instance.currentSite;
    final siteId = site == null
        ? null
        : (int.tryParse(site['site_id']?.toString() ?? '') ??
            int.tryParse(site['id']?.toString() ?? ''));
    final bool adapterBundleActive =
        AdapterApiService.instance.isConfigured && siteId != null;

    // If the adapter bundle is active, PUE/power/doors are pulled by the global
    // poller (`/v1/sites/:id/dashboard`). DashboardV2 only needs the Temp/Hum
    // TopN list (not included in the bundle yet).
    final fetchDoors = !adapterBundleActive &&
        (isInitial ||
            _lastDoorsFetch == null ||
            now.difference(_lastDoorsFetch!) >= mediumInterval);
    final fetchPowerMonth = !adapterBundleActive &&
        (isInitial ||
            _lastPowerMonthFetch == null ||
            now.difference(_lastPowerMonthFetch!) >= lowInterval);
    final fetchPue = !adapterBundleActive &&
        (isInitial ||
            _lastPueFetch == null ||
            now.difference(_lastPueFetch!) >= lowInterval);

    if (!fetchTempHum && !fetchDoors && !fetchPowerMonth && !fetchPue) return;

    // Power Month still talks to Dahua directly for now. We'll move it behind the
    // adapter once the contract is stable.
    final rawCabinetId = site != null
        ? (site['dahua_cabinet_id'] ??
                site['cabinet_id'] ??
                site['cabinetId'] ??
                site['rack_cabinet_id'])
            ?.toString()
        : null;
    final cabinetId =
        rawCabinetId == null ? null : int.tryParse(rawCabinetId)?.toString();

    final results = await Future.wait([
      fetchTempHum
          ? ApiService.instance.fetchTempHumTopN()
          : Future.value(null),
      fetchPowerMonth
          ? _fetchPowerMonthWithFallback(siteId: siteId, cabinetId: cabinetId)
          : Future.value(null),
      fetchPue
          ? _fetchPueWithFallback(siteId: siteId, cabinetId: cabinetId)
          : Future.value(null),
      fetchDoors
          ? _fetchDoorsWithFallback(siteId: siteId, cabinetId: cabinetId)
          : Future.value(null),
    ]);

    if (!mounted) return;

    final th = results[0];
    final pm = results[1];
    final pueRes = results[2];
    final gatesRes = results[3];

    final shouldUpdate = isInitial ||
        th != null ||
        pm != null ||
        pueRes != null ||
        gatesRes != null;
    if (!shouldUpdate) return;

    setState(() {
      _loading = false;

      if (th != null && th['result'] != null) {
        if (kDebugMode) {
          AppLog.d('[Dashboard] Environment (Temp/Hum) fetch SUCCESS.');
        }
        _lastTempHumFetch = now;
        _temperatures = (th['result']['temperature'] as List?)?.map((e) {
              final map = e as Map<String, dynamic>;
              return {...map};
            }).toList() ??
            [];
        _humidities = (th['result']['humidity'] as List?)?.map((e) {
              final map = e as Map<String, dynamic>;
              return {...map};
            }).toList() ??
            [];
      }

      if (pm != null && pm['result'] is Map) {
        if (kDebugMode) {
          AppLog.d(
              '[Dashboard] Power fetch SUCCESS. Raw Data: ${pm['result']}');
        }
        _lastPowerMonthFetch = now;
        _powerMonth = (pm['result'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
        );

        // Flexible key lookup for Total Power
        final totalE = _powerMonth['Total'] ??
            _powerMonth['TOTAL'] ??
            _powerMonth['total_power'] ??
            _powerMonth['totalPower'] ??
            0.0;

        // Flexible key lookup for IT Power
        final itE = _powerMonth['IT Device'] ??
            _powerMonth['IT DEVICE'] ??
            _powerMonth['IT'] ??
            _powerMonth['it_power'] ??
            _powerMonth['itPower'] ??
            _powerMonth['IT_DEVICE'] ??
            0.0;

        if (itE > 0) {
          _pue = totalE / itE;
        }
      }

      // 3. PUE Processing
      // Prefer adapter-normalized shape when available; otherwise fall back to
      // the legacy Dahua-direct response format.
      if (pueRes != null && pueRes is Map && pueRes.containsKey('pueStatus')) {
        _lastPueFetch = now;
        final status = pueRes['pueStatus']?.toString() ?? 'error';
        _pueStatus = status;

        final v = pueRes['pue'];
        final parsed = (v is num)
            ? v.toDouble()
            : double.tryParse(v?.toString() ?? '');

        if (kDebugMode && !_loggedPuePayload) {
          _loggedPuePayload = true;
          AppLog.d('PUE payload (adapter)', tag: 'DASH', fields: {
            'pueStatus': status,
            'pue': pueRes['pue'],
            'vendorPue': pueRes['vendorPue'],
          });
        }

        if (parsed != null && parsed > 0) {
          _pue = parsed;
        } else {
          _pue = 0.0;
        }
      } else if (pueRes != null &&
          pueRes is Map &&
          pueRes['result'] != null &&
          pueRes['result'] != false) {
        _lastPueFetch = now;
        _pueStatus = 'ok';

        final res = pueRes['result'];
        double parsed = 0.0;

        if (res is num) {
          parsed = res.toDouble();
        } else if (res is Map) {
          final v =
              res['pue'] ?? res['pueValue'] ?? res['axisY'] ?? res['pue_value'];
          if (v is num) {
            parsed = v.toDouble();
          } else {
            parsed = double.tryParse(v?.toString() ?? '') ?? 0.0;
          }
        } else if (res is List && res.isNotEmpty) {
          final last = res.last;
          if (last is Map) {
            final v = last['pue'] ??
                last['pueValue'] ??
                last['axisY'] ??
                last['pue_value'];
            if (v is num) {
              parsed = v.toDouble();
            } else {
              parsed = double.tryParse(v?.toString() ?? '') ?? 0.0;
            }
          } else {
            parsed = double.tryParse(last.toString()) ?? 0.0;
          }
        } else {
          parsed = double.tryParse(res.toString()) ?? 0.0;
        }

        _pue = parsed > 0 ? parsed : 0.0;
        if (_pue <= 0) _pueStatus = 'unavailable';
      } else {
        _pueStatus = 'down';
        _pue = 0.0;
      }

      // 4. Site Maintenance Info (Cpanel)
      final site = CpanelApiService.instance.currentSite;
      if (site != null && site['last_maintenance'] != null) {
        _lastMaintenance = DateTime.tryParse(site['last_maintenance']);
      }

      if (gatesRes != null) {
        _lastDoorsFetch = now;
        final raw = gatesRes['result'];
        final List cabinets = raw is List
            ? raw
            : (raw is Map
                ? ((raw['list'] as List?) ?? (raw['data'] as List?) ?? const [])
                : const []);

        final List<Map<String, dynamic>> loadedDoors = [];
        final existingDoors = _doors ?? const <Map<String, dynamic>>[];
        for (final cabinet in cabinets) {
          if (cabinet is! Map) continue;

          final details = (cabinet['detailList'] as List?) ??
              (cabinet['detail_list'] as List?) ??
              (cabinet['accessList'] as List?) ??
              (cabinet['doorList'] as List?) ??
              const [];

          for (final door in details) {
            if (door is! Map) continue;
            final existing = existingDoors.firstWhere(
              (d) => d['id'] == door['id'],
              orElse: () => {},
            );

            final rawCab = cabinet['cabinetItemName']?.toString() ?? '';
            final rawDoor =
                (door['accessName'] ?? door['name'] ?? '').toString().trim();

            final dynamic idRaw =
                door['id'] ?? door['accessId'] ?? door['access_id'];
            final int? doorId = idRaw == null
                ? null
                : (idRaw is num
                    ? idRaw.toInt()
                    : int.tryParse(idRaw.toString()));
            if (doorId == null) continue;

            final cabLabel = rawCab
                .replaceAll(
                    RegExp(r'Cabinet\s*Item\s*', caseSensitive: false), 'C')
                .trim();
            final doorSide =
                rawDoor.toUpperCase().contains('FRONT') ? 'Front' : 'Back';
            final cabNumText = RegExp(r'\d+').firstMatch(cabLabel)?.group(0) ??
                RegExp(r'\d+').firstMatch(rawCab)?.group(0);
            final cabIndex = int.tryParse(cabNumText ?? '');

            loadedDoors.add({
              'id': doorId,
              'name': doorSide,
              'side': doorSide,
              'cabIndex': cabIndex,
              'isOpen': existing.isNotEmpty
                  ? existing['isOpen']
                  : (door['open'] ?? door['isOpen'] ?? false),
            });
          }
        }

        loadedDoors.sort((a, b) {
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
        for (final d in loadedDoors) {
          final side = d['side']?.toString().toLowerCase();
          if (side == 'front') {
            front += 1;
            d['name'] = 'Front $front';
          } else {
            back += 1;
            d['name'] = 'Back $back';
          }
        }

        _doors = loadedDoors;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final bool wideLayout = screenW >= 1100;
    final uiScale = screenW >= 900 ? (screenW / 1150).clamp(1.0, 1.25) : 1.0;
    // Keep the web/tablet dashboard feeling "grid-like": top cards taller,
    // bottom cards shorter (per WebDashboard.png).
    final wideTopHeight = wideLayout
        ? (media.size.height * 0.40).clamp(320.0, 460.0) * uiScale
        : null;
    final wideBottomHeight = wideLayout
        ? (media.size.height * 0.24).clamp(200.0, 280.0) * uiScale
        : null;
    final envGaugeHeight = wideLayout ? (wideTopHeight! - 80) : null;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: TickerMode(
          enabled: ModalRoute.of(context)?.isCurrent ?? true,
          child: Stack(
            children: [
              // Content
              Positioned.fill(
                child: RefreshIndicator(
                  edgeOffset: AppConstants.headerClearance(context),
                  onRefresh: _onRefresh,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      14,
                      AppConstants.headerClearance(context),
                      16,
                      24 + 110,
                    ),
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          // Prevent ultra-wide stretching on big screens.
                          constraints: BoxConstraints(
                            maxWidth: wideLayout ? 1400 : double.infinity,
                          ),
                          child: Column(
                            children: [
                              if (wideLayout) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: SizedBox(
                                        height: wideTopHeight,
                                        child: PueHeroCard(
                                          pue: _pue,
                                          pueStatus: _pueStatus,
                                          monthlyEnergyKwh:
                                              _powerMonth['Total'],
                                          loading: _loading || _refreshing,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: SizedBox(
                                        height: wideTopHeight,
                                        child: EnvironmentRow(
                                          temperatures: _temperatures,
                                          humidities: _humidities,
                                          alarms: _poller.recentAlarms,
                                          gaugeHeight: envGaugeHeight ?? 260,
                                          loading: _loading || _refreshing,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                PueHeroCard(
                                  pue: _pue,
                                  pueStatus: _pueStatus,
                                  monthlyEnergyKwh: _powerMonth['Total'],
                                  loading: _loading || _refreshing,
                                ),
                                const SizedBox(height: 20),
                                EnvironmentRow(
                                  temperatures: _temperatures,
                                  humidities: _humidities,
                                  alarms: _poller.recentAlarms,
                                  loading: _loading || _refreshing,
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (wideLayout) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: wideBottomHeight,
                                        child: ServiceNoticeCard(
                                          lastService: _lastMaintenance,
                                          cycleDays: 90,
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const ReportScreen(
                                                        initialTabIndex: 1),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: SizedBox(
                                        height: wideBottomHeight,
                                        child: DoorControlSection(
                                          doors: _doors ?? const [],
                                          loading: _doors == null && _loading,
                                          canUnlock: _canControlDoors,
                                          onUnlock: _handleDoorUnlock,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                ServiceNoticeCard(
                                  lastService: _lastMaintenance,
                                  cycleDays: 90,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const ReportScreen(
                                            initialTabIndex: 1),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                DoorControlSection(
                                  doors: _doors ?? const [],
                                  loading: _doors == null && _loading,
                                  canUnlock: _canControlDoors,
                                  onUnlock: _handleDoorUnlock,
                                ),
                              ],
                              const SizedBox(height: 16),
                              DeviceHealthSection(
                                smokeStatus: _smokeStatus,
                                floodStatus: _floodStatus,
                                alarms: _poller.recentAlarms,
                                devices: _devices,
                                temperatures: _temperatures,
                                humidities: _humidities,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDoorUnlock(int id, String name) async {
    if (!_canControlDoors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to unlock doors.'),
        ),
      );
      return;
    }

    final authorized = await SecureActionGuard.ensureAuthorized(
      context,
      reason: 'Confirm to unlock $name',
      ttl: const Duration(seconds: 30),
    );
    if (!authorized) return;

    try {
      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      Map<String, dynamic>? res;
      if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.openCloseDoor(
          siteId: siteId,
          accessId: id,
          status: 1,
          accessType: '1',
        );
      }
      res ??= await ApiService.instance.openCloseDoor(id, 1);

      if (!mounted) return;
      final okSuccess = res != null && res['success'] == true;
      if (okSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name unlocked!')),
        );
      } else {
        final msg = res?['message']?.toString() ??
            'Unlock failed. If your session expired, please login again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock failed. Try again.')),
      );
    }
  }
}
