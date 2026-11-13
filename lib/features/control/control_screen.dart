import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/utils/app_log.dart';
import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/kiosk_user_pin_sheet.dart';
import '../../shared/widgets/secure_action_guard.dart';
import '../../shared/widgets/skeleton.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/utils/app_toast.dart';
import '../../shared/widgets/header_refresh_bar.dart';
import '../../shared/utils/pull_to_refresh_gate.dart';

class ControlScreen extends StatefulWidget {
  final bool isActive;
  const ControlScreen({super.key, this.isActive = true});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

enum _ControlSection { pdu1, pdu2, ac }

enum _MainTab { pdu, ac }

enum _AcTab { metric, status, setting }

enum _AcSection { metric, status, setting }

class _ControlScreenState extends State<ControlScreen>
    with TickerProviderStateMixin {
  static const int _pdu1NodeId = 6; // Verified from SetupACPDU.har
  static const int _pdu2NodeId = 7; // Verified from SetupACPDU.har

  bool _loading = true;
  bool _refreshing = false;
  bool _writing = false;
  RefreshIndicatorStatus? _refreshStatus;
  final PullToRefreshGate _refreshGate = PullToRefreshGate();

  _NodeMetrics? _pdu1;
  _NodeMetrics? _pdu2;
  _NodeMetrics? _ac;
  String? _acHint;
  _MainTab _mainTab = _MainTab.pdu;
  _ControlSection _pduTab = _ControlSection.pdu1;
  _AcTab _acTab = _AcTab.metric;

  late final AnimationController _tabSelC;
  late final AnimationController _pduSubTabC;
  late final AnimationController _acSubTabC;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabSelC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 0.0,
      upperBound: 1.0,
    );
    _pduSubTabC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 0.0,
      upperBound: 1.0,
    );
    _acSubTabC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 0.0,
      upperBound: 2.0,
    );
    _fetchAll();
  }

  void _selectMainTab(_MainTab tab) {
    if (_mainTab != tab) {
      setState(() => _mainTab = tab);
      _tabSelC.animateTo(
        tab == _MainTab.pdu ? 0.0 : 1.0,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectPduTab(_ControlSection tab) {
    if (_pduTab != tab) {
      setState(() => _pduTab = tab);
      _pduSubTabC.animateTo(
        tab == _ControlSection.pdu1 ? 0.0 : 1.0,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectAcTab(_AcTab tab) {
    if (_acTab != tab) {
      setState(() => _acTab = tab);
      _acSubTabC.animateTo(
        tab.index.toDouble(),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ControlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _fetchAll();
    }
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    _refreshGate.beginRefresh();
    setState(() => _refreshing = true);
    try {
      await _fetchAll();
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

  Future<void> _fetchAll() async {
    try {
      final pdu1Node =
          await _fetchNodeSnapshot(_pdu1NodeId, fallbackName: 'PDU 1');
      final pdu2Node =
          await _fetchNodeSnapshot(_pdu2NodeId, fallbackName: 'PDU 2');
      final acRes = await _discoverAndFetchAc();

      // Diagnostics: AC values sometimes live in unexpected fields on some vendor builds.
      // Print a compact snapshot so we can see which fields contain the setpoint values.
      if (kDebugMode && acRes != null) {
        AppLog.d(
          'AC node snapshot',
          tag: 'CONTROL',
          fields: {
            'nodeId': acRes.id,
            'name': acRes.name,
            'sections': {
              'metric': acRes.rows
                  .where((r) => r.acSection == _AcSection.metric)
                  .length,
              'status': acRes.rows
                  .where((r) => r.acSection == _AcSection.status)
                  .length,
              'setting': acRes.rows
                  .where((r) => r.acSection == _AcSection.setting)
                  .length,
            },
            'sample': [
              for (final r in acRes.rows.take(8))
                {
                  'metric': r.metricCode,
                  'name': r.name,
                  'section': r.acSection.name,
                  'value': r.displayValue,
                  'unit': r.unit,
                  'ts': r.updateTime,
                }
            ],
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _pdu1 = pdu1Node;
        _pdu2 = pdu2Node;
        _ac = acRes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchNodeWithMetricPreferAdapter(
      int nodeId) async {
    final site = CpanelApiService.instance.currentSite;
    final siteId = site == null
        ? null
        : (int.tryParse(site['site_id']?.toString() ?? '') ??
            int.tryParse(site['id']?.toString() ?? ''));
    final adapterReady =
        AdapterApiService.instance.isConfigured && siteId != null;

    if (adapterReady) {
      final res = await AdapterApiService.instance
          .fetchNodeWithMetric(siteId: siteId, nodeId: nodeId);
      if (res != null) return res;
      if (!ApiService.instance.canUseDirectFallback) return null;
    }
    return ApiService.instance.fetchNodeWithMetric(nodeId);
  }

  Future<_NodeMetrics?> _fetchNodeMetricsFallback(
    int nodeId, {
    String? fallbackName,
  }) async {
    if (!ApiService.instance.canUseDirectFallback) return null;
    try {
      final res = await ApiService.instance.fetchNodeMetrics(nodeId);
      return _NodeMetrics.fromMetricList(
        res,
        fallbackNodeId: nodeId,
        fallbackName: fallbackName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_NodeMetrics?> _fetchNodeSnapshot(
    int nodeId, {
    String? fallbackName,
  }) async {
    final primary = _NodeMetrics.fromApi(
      await _fetchNodeWithMetricPreferAdapter(nodeId),
    );
    if (primary != null && primary.rows.isNotEmpty) {
      return primary;
    }

    final fallback = await _fetchNodeMetricsFallback(
      nodeId,
      fallbackName: fallbackName,
    );
    if (fallback != null && fallback.rows.isNotEmpty) {
      return fallback;
    }

    return primary ?? fallback;
  }

  Future<_NodeMetrics?> _discoverAndFetchAc() async {
    try {
      final candidates = <Map<String, dynamic>>[];
      final seenIds = <int>{};
      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));
      final adapterReady =
          AdapterApiService.instance.isConfigured && siteId != null;

      Future<void> collectCandidates(String? name) async {
        Map<String, dynamic>? list;
        if (adapterReady) {
          list = await AdapterApiService.instance.fetchPowerEnvNodes(
            siteId: siteId,
            name: name,
            pageSize: 100,
          );
          if (list == null && !ApiService.instance.canUseDirectFallback) {
            return;
          }
        }
        list ??= await ApiService.instance.fetchPowerEnvNodes(
          name: name,
          pageSize: 100,
        );
        final records = (list?['result']?['records'] as List?) ?? const [];
        for (final r in records) {
          if (r is! Map) continue;
          final item = r.cast<String, dynamic>();
          final id = item['id'];
          final nodeId =
              (id is num) ? id.toInt() : int.tryParse(id?.toString() ?? '');
          if (nodeId == null || !seenIds.add(nodeId)) continue;
          candidates.add(item);
        }
      }

      await collectCandidates('*ac*');
      await collectCandidates('*AC*');
      await collectCandidates(null);

      candidates.sort((a, b) => _acScore(b).compareTo(_acScore(a)));
      for (final pick in candidates) {
        final id = pick['id'];
        final nodeId =
            (id is num) ? id.toInt() : int.tryParse(id?.toString() ?? '');
        if (nodeId == null) continue;

        final node = await _fetchNodeSnapshot(
          nodeId,
          fallbackName: pick['name']?.toString(),
        );
        if (node != null && node.rows.isNotEmpty) {
          _acHint = node.rows.any((row) => row.write)
              ? null
              : 'AC status is available, but this device exposes read-only metrics only.';
          return node;
        }
      }

      final legacyNode = await _fetchNodeSnapshot(17, fallbackName: 'AC');
      if (legacyNode != null && legacyNode.rows.isNotEmpty) {
        _acHint = legacyNode.rows.any((row) => row.write)
            ? 'AC loaded from legacy fallback node 17.'
            : 'AC status is available from legacy node 17, but controls are read-only.';
        return legacyNode;
      }

      _acHint =
          'AC discovery failed. Ensure the AC device is configured in the vendor system.';
      return null;
    } catch (_) {
      _acHint =
          'AC discovery failed. Ensure the AC device is configured in the vendor system.';
      return null;
    }
  }

  int _acScore(Map<String, dynamic> r) {
    final name = (r['name'] ?? '').toString().toLowerCase();
    final typeName = (r['nodeTypeName'] ?? '').toString().toLowerCase();
    final typeCode = (r['nodeTypeCode'] ?? '').toString().toLowerCase();
    final typeId = int.tryParse(r['nodeTypeId']?.toString() ?? '');
    int s = 0;
    if (typeId == 15) s += 40;
    if (name == 'ac') s += 20;
    if (name.contains(' ac')) s += 16;
    if (name.contains('ac')) s += 12;
    if (name.contains('air')) s += 8;
    if (typeName == 'ac') s += 25;
    if (typeName.contains('ac')) s += 14;
    if (typeName.contains('air')) s += 8;
    if (typeCode.contains('ac')) s += 12;
    if (typeCode.contains('air')) s += 6;
    return s;
  }

  @override
  void dispose() {
    _tabSelC.dispose();
    _pduSubTabC.dispose();
    _acSubTabC.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final onSurface = isLight ? Colors.black : Colors.white;

    _NodeMetrics? node;
    String? hint;
    if (_mainTab == _MainTab.pdu) {
      if (_pduTab == _ControlSection.pdu1) {
        node = _pdu1;
      } else {
        node = _pdu2;
      }
    } else {
      node = _ac;
      hint = _acHint;
    }
    final hPadding = AppSpacing.pageHorizontal(context);
    final subTextColor = isLight
        ? AppTheme.lightTextSecondary
        : Colors.white.withValues(alpha: 0.65);

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.0)),
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
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: AppConstants.headerClearance(context),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.fromLTRB(hPadding, 12, hPadding, 16),
                          child: _buildTabs(isLight, onSurface),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: hPadding),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              if (_writing)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 25, left: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.orangeAccent
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Applying change...',
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_loading)
                                _tableSkeleton()
                              else if (_mainTab == _MainTab.pdu)
                                _nodeTable(node, hint: hint)
                              else
                                _buildAcContent(isLight, onSurface, node),
                              SizedBox(
                                height: AppSpacing.pageBottom(context),
                              ), // Bottom padding
                            ],
                          ),
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

  Widget _buildTabs(bool isLight, Color onSurface) {
    return Column(
      children: [
        // Main Tabs
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF0F1722),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.10)
                    : const Color(0xFF1E2D3D),
              ),
            ),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _tabSelC,
                    builder: (context, _) {
                      final sel = _tabSelC.value.clamp(0.0, 1.0);

                      // Dynamic colors for PDU, fixed for AC
                      final pC = _getDeviceColor(_pduTab);
                      const acC = Color(0xFF3271D7); // Blue like Energy

                      final accentColor = Color.lerp(pC, acC, sel)!;

                      final alignX = -1.0 + (sel * 2.0);

                      return Align(
                        alignment: Alignment(alignX, 0),
                        child: FractionallySizedBox(
                          widthFactor: 1 / 2,
                          heightFactor: 1.0,
                          child: _AuraPill(color: accentColor),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      _navMainBtn('PDU', _MainTab.pdu),
                      _navMainBtn('AC', _MainTab.ac),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Sub Tabs
        if (_mainTab == _MainTab.pdu)
          _buildPduSubTabs(isLight)
        else
          _buildAcSubTabs(isLight),
      ],
    );
  }

  Color _getDeviceColor(_ControlSection s) {
    if (s == _ControlSection.ac) return const Color(0xFF3271D7);

    final node = s == _ControlSection.pdu1 ? _pdu1 : _pdu2;
    if (node == null) return const Color(0xFFE6A600); // Orange for unknown

    // Check overall PDU status
    // 1=On (Green), 2=Off (Grey), 0=Uncontrollable (Orange)
    int? state;
    for (final r in node.rows) {
      if (r.metricCode.contains('onoffcontrol')) {
        if (r.currentIntValue == 1) {
          state = 1;
          break; // If any outlet is ON, consider PDU ON
        }
        if (r.currentIntValue == 2) state = 2;
        if (r.currentIntValue == 0 && state == null) state = 0;
      }
    }

    return switch (state) {
      1 => const Color(0xFF4CAF50), // Green
      2 => const Color(0xFF9E9E9E), // Grey
      _ => const Color(0xFFE6A600), // Orange (Uncontrollable/Unknown)
    };
  }

  Widget _navMainBtn(String label, _MainTab s) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectMainTab(s),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedBuilder(
            animation: _tabSelC,
            builder: (context, _) {
              final t = _tabSelC.value.clamp(0.0, 1.0);
              final targetIndex = s == _MainTab.pdu ? 0.0 : 1.0;
              final selectedness =
                  (1.0 - (t - targetIndex).abs()).clamp(0.0, 1.0).toDouble();
              final isLight = Theme.of(context).brightness == Brightness.light;
              const selectedColor = Colors.white;
              final unselectedColor = isLight
                  ? AppTheme.lightTextSecondary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.5);
              return Text(
                label,
                style: TextStyle(
                  color:
                      Color.lerp(unselectedColor, selectedColor, selectedness),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPduSubTabs(bool isLight) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF0F1722),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.10)
                : const Color(0xFF1E2D3D),
          ),
        ),
        child: SizedBox(
          height: 36,
          width: double.infinity,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _pduSubTabC,
                builder: (context, _) {
                  final sel = _pduSubTabC.value.clamp(0.0, 1.0);
                  final p1C = _getDeviceColor(_ControlSection.pdu1);
                  final p2C = _getDeviceColor(_ControlSection.pdu2);
                  final accentColor = Color.lerp(p1C, p2C, sel)!;
                  final alignX = -1.0 + (sel * 2.0);

                  return Align(
                    alignment: Alignment(alignX, 0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / 2,
                      heightFactor: 1.0,
                      child: _AuraPill(color: accentColor),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  _navSubBtn('PDU 1', () => _selectPduTab(_ControlSection.pdu1),
                      _pduSubTabC, 0.0),
                  _navSubBtn('PDU 2', () => _selectPduTab(_ControlSection.pdu2),
                      _pduSubTabC, 1.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcSubTabs(bool isLight) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF0F1722),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.10)
                : const Color(0xFF1E2D3D),
          ),
        ),
        child: SizedBox(
          height: 36,
          width: double.infinity,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _acSubTabC,
                builder: (context, _) {
                  final sel = _acSubTabC.value.clamp(0.0, 2.0);
                  const accentColor = Color(0xFF3271D7); // Fixed Blue for AC
                  final alignX = -1.0 + (sel * 1.0);

                  return Align(
                    alignment: Alignment(alignX, 0),
                    child: const FractionallySizedBox(
                      widthFactor: 1 / 3,
                      heightFactor: 1.0,
                      child: _AuraPill(color: accentColor),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  _navSubBtn('Metric', () => _selectAcTab(_AcTab.metric),
                      _acSubTabC, 0.0),
                  _navSubBtn('Status', () => _selectAcTab(_AcTab.status),
                      _acSubTabC, 1.0),
                  _navSubBtn('Setting', () => _selectAcTab(_AcTab.setting),
                      _acSubTabC, 2.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navSubBtn(String label, VoidCallback onTap, AnimationController animC,
      double targetIndex) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedBuilder(
            animation: animC,
            builder: (context, _) {
              final t = animC.value.clamp(0.0, 2.0);
              final selectedness =
                  (1.0 - (t - targetIndex).abs()).clamp(0.0, 1.0).toDouble();
              final isLight = Theme.of(context).brightness == Brightness.light;
              const selectedColor = Colors.white;
              final unselectedColor = isLight
                  ? AppTheme.lightTextSecondary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.5);
              return Text(
                label,
                style: TextStyle(
                  color:
                      Color.lerp(unselectedColor, selectedColor, selectedness),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAcContent(bool isLight, Color onSurface, _NodeMetrics? node) {
    final rows = node?.rows ?? const <_MetricRow>[];

    final categorized = <_AcSection, List<_MetricRow>>{
      _AcSection.metric: <_MetricRow>[],
      _AcSection.status: <_MetricRow>[],
      _AcSection.setting: <_MetricRow>[],
    };
    for (final row in rows) {
      categorized[row.acSection]!.add(row);
    }

    for (final bucket in categorized.values) {
      bucket.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    }

    final visibleRows = switch (_acTab) {
      _AcTab.metric => categorized[_AcSection.metric]!,
      _AcTab.status => categorized[_AcSection.status]!,
      _AcTab.setting => categorized[_AcSection.setting]!,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: isLight
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF131D2A), Color(0xFF0C131D)],
                  ),
            color: isLight ? Colors.white : null,
            borderRadius: BorderRadius.circular(20),
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
          clipBehavior: Clip.antiAlias,
          child: visibleRows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No ${_acTab.name} data available',
                      style: TextStyle(
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleRows.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : const Color(0xFF1E2D3D),
                    ),
                  ),
                  itemBuilder: (context, idx) {
                    final r = visibleRows[idx];
                    return _metricTile(
                      title: r.name,
                      value: r.displayValue,
                      unit: r.unit,
                      time: r.updateTime,
                      canSet: r.write,
                      onSet: r.write
                          ? () => _openSetDialog(nodeId: node?.id, row: r)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _tableSkeleton() {
    return Column(
      children: [
        const SizedBox(height: 6),
        Skeleton(height: 44, borderRadius: BorderRadius.circular(14)),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 10,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) =>
              Skeleton(height: 54, borderRadius: BorderRadius.circular(14)),
        ),
      ],
    );
  }

  Widget _nodeTable(_NodeMetrics? node, {String? hint}) {
    final rows = node?.rows ?? const <_MetricRow>[];
    final writable = rows.where((r) => r.write).toList();
    final visibleRows = writable.isNotEmpty ? writable : rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hint != null && hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(hint,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.4)),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.light
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF131D2A), Color(0xFF0C131D)],
                  ),
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withValues(alpha: 0.10)
                  : const Color(0xFF1E2D3D),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.light
                        ? 0.05
                        : 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleRows.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black.withValues(alpha: 0.05)
                    : const Color(0xFF1E2D3D),
              ),
            ),
            itemBuilder: (context, idx) {
              final r = visibleRows[idx];
              return _metricTile(
                title: r.name,
                value: r.displayValue,
                unit: r.unit,
                time: r.updateTime,
                canSet: r.write,
                onSet: r.write
                    ? () => _openSetDialog(nodeId: node?.id, row: r)
                    : null,
              );
            },
          ),
        ),
        if (rows.isNotEmpty && writable.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14, left: 4),
            child: Text(
              'This device is reporting status only. No writable controls were exposed by the rack API.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppTheme.lightTextSecondary
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.tune_rounded,
                      color: Colors.white.withValues(alpha: 0.15), size: 48),
                  const SizedBox(height: 12),
                  Text('No controls available',
                      style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? AppTheme.lightTextSecondary
                                  : Colors.white.withValues(alpha: 0.35),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _metricTile({
    required String title,
    required String value,
    required String unit,
    required String
        time, // Time is kept in signature but not displayed per request
    required bool canSet,
    required VoidCallback? onSet,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = isLight ? Colors.black : Colors.white;
    final subtitleColor = isLight
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _writing ? null : onSet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Text(
                    '$value${unit.isNotEmpty ? ' $unit' : ''}',
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  if (canSet) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: subtitleColor.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSetDialog(
      {required int? nodeId, required _MetricRow row}) async {
    if (nodeId == null) return;
    if (_writing) return;

    final writeMap = row.writeMap;
    if (writeMap != null && writeMap.isNotEmpty) {
      await _openEnumSetSheet(nodeId: nodeId, row: row);
      return;
    }

    await _openNumericSetDialog(nodeId: nodeId, row: row);
  }

  Future<void> _openNumericSetDialog(
      {required int nodeId, required _MetricRow row}) async {
    final controller = TextEditingController();
    controller.text = row.displayValue.replaceAll(RegExp(r'[^0-9.\\-]'), '');

    final raw = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: DashboardGlass(
          radius: 18,
          padding: const EdgeInsets.all(16),
          tint: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF111922).withValues(alpha: 0.96),
          borderColor: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightStroke
              : Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.name,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextPrimary
                          : Colors.white,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('Current: ${row.displayValue}',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextSecondary
                          : Colors.white.withValues(alpha: 0.75))),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.lightTextPrimary
                        : Colors.white,
                    fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: row.unit.isNotEmpty
                      ? 'Enter value (${row.unit})'
                      : 'Enter value',
                  hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextSecondary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.35)),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.black.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.orangeAccent.withValues(alpha: 0.55)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).brightness == Brightness.light
                                ? AppTheme.lightTextSecondary
                                : Colors.white70,
                        side: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? AppTheme.lightTextSecondary
                                        .withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.25)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Colors.orangeAccent.withValues(alpha: 0.85),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Set'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    final v = raw?.trim();
    if (v == null || v.isEmpty) return;

    // Vendor HAR often sends numeric values as strings (e.g. "25").
    await _confirmAndWrite(
      nodeId: nodeId,
      metricCode: row.metricCode,
      value: v,
      closeAfterWrite: false,
    );
  }

  Future<void> _openEnumSetSheet(
      {required int nodeId, required _MetricRow row}) async {
    final options = row.writeMap!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // Bypass 50% max-height limit
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: DashboardGlass(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            tint: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : const Color(0xFF111922).withValues(alpha: 0.96),
            borderColor: Theme.of(context).brightness == Brightness.light
                ? AppTheme.lightStroke
                : Colors.transparent,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(row.name,
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? AppTheme.lightTextPrimary
                                      : Colors.white,
                                  fontWeight: FontWeight.w900)),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final o in options)
                          _chip(
                            label: o.value.trim(),
                            active: row.currentIntValue == o.key,
                            onTap: () => _confirmAndWrite(
                                nodeId: nodeId,
                                metricCode: row.metricCode,
                                value: o.key,
                                closeAfterWrite: true),
                          ),
                      ],
                    ),
                    const SizedBox(height: 60), // Pushes the options higher
                  ],
                ),
              ), // Closes SingleChildScrollView
            ), // Closes SafeArea
          ),
        );
      },
    );
  }

  Widget _chip(
      {required String label,
      required bool active,
      required VoidCallback onTap}) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Theme-aware colors for inactive state
    final inactiveBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.08);
    final inactiveBorder = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.15);
    final inactiveText = isLight
        ? AppTheme.lightTextSecondary
        : Colors.white.withValues(alpha: 0.7);

    // Theme-aware colors for active state
    final activeBg = isLight
        ? Colors.orangeAccent.withValues(alpha: 0.15)
        : Colors.orangeAccent.withValues(alpha: 0.18);
    final activeBorder = Colors.orangeAccent.withValues(alpha: 0.5);
    final activeText =
        isLight ? Colors.orange.shade900 : Colors.orangeAccent.shade100;

    return InkWell(
      onTap: _writing ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding:
            EdgeInsets.symmetric(horizontal: active ? 16 : 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? activeBorder : inactiveBorder,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Icon(Icons.check_circle_rounded, color: activeText, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? activeText : inactiveText,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndWrite(
      {required int nodeId,
      required String metricCode,
      required Object value,
      required bool closeAfterWrite}) async {
    if (_writing) return;
    final navigator = Navigator.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: DashboardGlass(
          radius: 18,
          padding: const EdgeInsets.all(16),
          tint: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF111922).withValues(alpha: 0.96),
          borderColor: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightStroke
              : Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm Action',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextPrimary
                          : Colors.white,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('Apply this setting?',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightTextSecondary
                          : Colors.white.withValues(alpha: 0.8))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).brightness == Brightness.light
                                ? AppTheme.lightTextSecondary
                                : Colors.white70,
                        side: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? AppTheme.lightTextSecondary
                                        .withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.25)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Colors.orangeAccent.withValues(alpha: 0.85),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    final site = CpanelApiService.instance.currentSite;
    final siteId = site == null
        ? null
        : (int.tryParse(site['site_id']?.toString() ?? '') ??
            int.tryParse(site['id']?.toString() ?? ''));
    final isRackConsoleMode =
        CpanelApiService.instance.isCurrentSiteRackConsole(site);

    RackConsoleApprovalResult? rackConsoleApproval;
    if (isRackConsoleMode) {
      rackConsoleApproval = await RackConsoleUserPinSheet.show(
        context,
        title: 'RACK CONSOLE CONTROL APPROVAL',
        reason:
            'Enter the approving user PIN to apply this control setting from the Rack Console.',
        confirmLabel: 'Approve and Apply',
      );
      if (!mounted) return;
      if (rackConsoleApproval == null) return;
      if (!AdapterApiService.instance.isConfigured || siteId == null) {
        _toast('Rack Console PIN control requires the adapter connection.');
        return;
      }
    } else {
      final authorized = await SecureActionGuard.ensureAuthorized(
        context,
        reason: 'Confirm to apply control setting',
        ttl: const Duration(seconds: 30),
        allowPin: true,
      );
      if (!mounted) return;
      if (!authorized) return;
    }

    setState(() => _writing = true);
    try {
      Map<String, dynamic>? res;
      if (isRackConsoleMode && siteId != null && rackConsoleApproval != null) {
        res = await AdapterApiService.instance.writeNodeMetricWithUserPin(
          siteId: siteId,
          nodeId: nodeId,
          metricTypeLibCode: metricCode,
          value: value,
          pin: rackConsoleApproval.pin,
        );
      } else if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.writeNodeMetric(
          siteId: siteId,
          nodeId: nodeId,
          metricTypeLibCode: metricCode,
          value: value,
        );
      }
      if (!isRackConsoleMode && ApiService.instance.canUseDirectFallback) {
        res ??= await ApiService.instance.writeNodeMetric(
            nodeId: nodeId, metricTypeLibCode: metricCode, value: value);
      }

      // Helpful diagnostics: vendor sometimes returns HTTP 200 with success=false
      // or a message indicating the device is offline/uncontrollable.
      if (kDebugMode && res != null) {
        AppLog.d('writeMetric resp', tag: 'CONTROL', fields: res);
      }
      final okSuccess =
          (res?['success'] == true) || (res?['code']?.toString() == '20000');
      if (!okSuccess) {
        final msg =
            res?['message']?.toString() ?? 'Control failed (no response).';
        _toast(msg);
        return;
      }

      // Poll briefly for the metric value/timestamp to reflect the change.
      // Some devices update on a fixed interval (e.g. 30-60s), so we give it a
      // short window to avoid a confusing "it didn’t change" moment.
      await _pollForMetricUpdate(
          nodeId: nodeId, metricCode: metricCode, desired: value);
      // Only close the enum bottom sheet. For numeric-input actions we should
      // stay on the Control screen.
      if (closeAfterWrite && mounted && navigator.canPop()) {
        navigator.pop();
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _pollForMetricUpdate({
    required int nodeId,
    required String metricCode,
    required Object desired,
  }) async {
    // Capture current snapshot
    final before = await _fetchNodeWithMetricPreferAdapter(nodeId);
    final beforeNode = _NodeMetrics.fromApi(before);
    final beforeRow = beforeNode?.rows
        .where((r) => r.metricCode == metricCode)
        .cast<_MetricRow?>()
        .firstWhere((_) => true, orElse: () => null);
    final beforeTs = beforeRow?.updateTime;
    final beforeVal = beforeRow?.displayValue;

    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 650));
      final res = await _fetchNodeWithMetricPreferAdapter(nodeId);
      final node = _NodeMetrics.fromApi(res);
      if (node == null) continue;

      // Update local state as we poll so the UI refreshes even if it never matches.
      if (!mounted) return;
      setState(() {
        if (nodeId == _pdu1NodeId) _pdu1 = node;
        if (nodeId == _pdu2NodeId) _pdu2 = node;
        if (_ac?.id == nodeId) _ac = node;
      });

      final row = node.rows.where((r) => r.metricCode == metricCode).isEmpty
          ? null
          : node.rows.firstWhere((r) => r.metricCode == metricCode);

      if (row == null) continue;

      final nowTs = row.updateTime;
      final nowVal = row.displayValue;

      // If timestamp changed OR value changed, we consider it updated.
      if (nowTs != beforeTs || nowVal != beforeVal) return;

      // If it matches desired, also stop early.
      if (nowVal == desired.toString()) return;
    }

    // If we get here, we never saw an updated telemetry value in time.
    // That can be normal depending on the device/collector interval.
    _toast('Command sent. Value may update on the next device polling cycle.');
  }
}

class _AuraPill extends StatelessWidget {
  final Color color;

  const _AuraPill({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.transparent),
      ),
    );
  }
}

class _NodeMetrics {
  final int id;
  final String name;
  final List<_MetricRow> rows;

  const _NodeMetrics(
      {required this.id, required this.name, required this.rows});

  static _NodeMetrics? fromApi(Map<String, dynamic>? res) {
    if (res == null) return null;
    final normalized = res['normalized'];
    final r = res['result'];
    if (r is! Map) return null;
    final id = (r['id'] is num)
        ? (r['id'] as num).toInt()
        : int.tryParse(r['id']?.toString() ?? '');
    if (id == null) return null;
    final name = r['name']?.toString() ?? 'Node $id';
    final normalizedRows = _rowsFromNormalized(normalized);
    if (normalizedRows.isNotEmpty) {
      return _NodeMetrics(id: id, name: name, rows: normalizedRows);
    }
    final metrics = (r['metrics'] as List?) ?? const [];
    final rows = <_MetricRow>[];
    var index = 0;
    for (final m in metrics) {
      if (m is! Map) continue;
      rows.add(_MetricRow.fromMetric(
        m.cast<String, dynamic>(),
        sourceIndex: index,
      ));
      index++;
    }
    return _NodeMetrics(id: id, name: name, rows: rows);
  }

  static _NodeMetrics? fromMetricList(
    Map<String, dynamic>? res, {
    required int fallbackNodeId,
    String? fallbackName,
  }) {
    if (res == null) return null;
    final r = res['result'];
    if (r is! Map) return null;
    final metrics = (r['records'] as List?) ?? const [];
    final rows = <_MetricRow>[];
    var index = 0;
    for (final m in metrics) {
      if (m is! Map) continue;
      rows.add(_MetricRow.fromMetric(
        m.cast<String, dynamic>(),
        sourceIndex: index,
      ));
      index++;
    }
    return _NodeMetrics(
      id: fallbackNodeId,
      name: fallbackName?.trim().isNotEmpty == true
          ? fallbackName!.trim()
          : 'Node $fallbackNodeId',
      rows: rows,
    );
  }
}

List<_MetricRow> _rowsFromNormalized(dynamic normalized) {
  if (normalized is! Map) return const [];
  final normalizedMap = normalized.cast<String, dynamic>();

  final rows = <_MetricRow>[];
  final rawRows = normalizedMap['rows'];
  if (rawRows is List) {
    var index = 0;
    for (final raw in rawRows) {
      if (raw is! Map) {
        index++;
        continue;
      }
      final rawMap = Map<String, dynamic>.from(raw.cast<String, dynamic>());
      rows.add(
        _MetricRow.fromMetric(
          rawMap,
          sourceIndex: index,
          sectionOverride: _parseAcSection(
            rawMap['section'] ??
                rawMap['category'] ??
                rawMap['group'] ??
                rawMap['groupName'],
          ),
        ),
      );
      index++;
    }
    if (rows.isNotEmpty) {
      rows.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
      return rows;
    }
  }

  final sections = normalizedMap['sections'];
  if (sections is Map) {
    final sectionMap = sections.cast<String, dynamic>();
    var index = 0;
    for (final entry in [
      MapEntry('metric', sectionMap['metric']),
      MapEntry('status', sectionMap['status']),
      MapEntry('setting', sectionMap['setting']),
    ]) {
      final sectionRows = entry.value;
      if (sectionRows is! List) continue;
      for (final raw in sectionRows) {
        if (raw is! Map) {
          index++;
          continue;
        }
        rows.add(
          _MetricRow.fromMetric(
            Map<String, dynamic>.from(raw.cast<String, dynamic>()),
            sourceIndex: index,
            sectionOverride: _parseAcSection(entry.key),
          ),
        );
        index++;
      }
    }
  }

  rows.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  return rows;
}

class _MetricRow {
  final String metricCode;
  final String name;
  final String unit;
  final String updateTime;
  final bool write;
  final Map<int, String>? writeMap;
  final int? currentIntValue;
  final String displayValue;
  final _AcSection acSection;
  final int sortIndex;

  const _MetricRow({
    required this.metricCode,
    required this.name,
    required this.unit,
    required this.updateTime,
    required this.write,
    required this.writeMap,
    required this.currentIntValue,
    required this.displayValue,
    required this.acSection,
    required this.sortIndex,
  });

  static _MetricRow fromMetric(
    Map<String, dynamic> m, {
    required int sourceIndex,
    _AcSection? sectionOverride,
  }) {
    final metricCode = (m['code'] ?? m['metricTypeLibCode'] ?? '').toString();
    final name = (m['name'] ?? m['desc'] ?? metricCode).toString();
    final unit = (m['codeUnit'] ?? '').toString().trim();

    final ts = m['timestamp'];
    final dt = (ts is num)
        ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
        : DateTime.fromMillisecondsSinceEpoch(
            int.tryParse(ts?.toString() ?? '') ?? 0);
    final updateTime = dt.millisecondsSinceEpoch == 0
        ? '--'
        : '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final write = (m['write'] == true) || (m['writable'] == true);
    final sortIndex = _firstInt(
          m,
          const [
            'sortOrder',
            'sort',
            'displayOrder',
            'orderNo',
            'seq',
            'index',
            'sortIndex'
          ],
        ) ??
        sourceIndex;

    Map<int, String>? writeMap;
    final rawMap = m['writeMap'];
    if (rawMap is Map) {
      final tmp = <int, String>{};
      rawMap.forEach((k, v) {
        final ik = (k is num) ? k.toInt() : int.tryParse(k.toString());
        if (ik != null) tmp[ik] = v?.toString() ?? '';
      });
      if (tmp.isNotEmpty) writeMap = tmp;
    }

    final explicitSection = sectionOverride ??
        _parseAcSection(
          m['section'] ??
              m['category'] ??
              m['group'] ??
              m['groupName'] ??
              m['tab'] ??
              m['bucket'] ??
              m['kind'] ??
              m['type'] ??
              m['role'] ??
              m['metricCategory'],
        );

    final valueStr = m['valueStr']?.toString();
    final val = m['value'] ?? m['val'];
    int? intVal;
    if (val is num) intVal = val.toInt();
    if (val is String) intVal = int.tryParse(val);

    String display;
    if (valueStr != null && valueStr.trim().isNotEmpty) {
      display = valueStr.trim();
    } else if (writeMap != null &&
        intVal != null &&
        writeMap.containsKey(intVal)) {
      display = writeMap[intVal]!.trim();
    } else if (val == null) {
      display = '--';
    } else {
      display = val.toString();
    }

    final acSection = explicitSection ??
        (write
            ? _AcSection.setting
            : _inferAcSection(metricCode, name, unit, display));

    return _MetricRow(
      metricCode: metricCode,
      name: name,
      unit: unit,
      updateTime: updateTime,
      write: write,
      writeMap: writeMap,
      currentIntValue: intVal,
      displayValue: display,
      acSection: acSection,
      sortIndex: sortIndex,
    );
  }
}

_AcSection? _parseAcSection(dynamic raw) {
  final normalized = raw?.toString().trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'metric':
    case 'metrics':
    case 'measurement':
    case 'measurements':
    case 'reading':
    case 'readings':
    case 'sensor':
    case 'sensors':
    case 'telemetry':
      return _AcSection.metric;
    case 'status':
    case 'statuses':
    case 'state':
    case 'states':
    case 'alarm':
    case 'alarms':
    case 'fault':
    case 'faults':
    case 'warning':
    case 'warnings':
    case 'condition':
    case 'conditions':
      return _AcSection.status;
    case 'setting':
    case 'settings':
    case 'control':
    case 'controls':
    case 'config':
    case 'configuration':
    case 'parameter':
    case 'parameters':
    case 'setpoint':
    case 'setpoints':
    case 'adjustment':
    case 'adjustments':
    case 'threshold':
    case 'thresholds':
      return _AcSection.setting;
    default:
      return null;
  }
}

_AcSection _inferAcSection(
  String metricCode,
  String name,
  String unit,
  String display,
) {
  final text = [
    metricCode,
    name,
    unit,
    display,
  ].map((v) => v.trim().toLowerCase()).join(' ');

  if (text.contains('status') ||
      text.contains('state') ||
      text.contains('alarm') ||
      text.contains('fault') ||
      text.contains('warning') ||
      text.contains('error') ||
      text.contains('trip') ||
      text.contains('running') ||
      text.contains('stopped') ||
      text.contains('online') ||
      text.contains('offline') ||
      text.contains('open') ||
      text.contains('closed') ||
      text.contains('ready') ||
      text.contains('disabled') ||
      text.contains('enabled') ||
      text.contains('cooling') ||
      text.contains('heating') ||
      text.contains('standby')) {
    return _AcSection.status;
  }

  if (text.contains('setpoint') ||
      text.contains('threshold') ||
      text.contains('control') ||
      text.contains('config') ||
      text.contains('parameter') ||
      text.contains('adjustment') ||
      text.contains('preset') ||
      text.contains('reset') ||
      text.contains('power on') ||
      text.contains('power off') ||
      text.contains('enable') ||
      text.contains('disable') ||
      text.contains('mode')) {
    return _AcSection.setting;
  }

  return _AcSection.metric;
}

int? _firstInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}
