import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/utils/app_log.dart';
import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/secure_action_guard.dart';
import '../../shared/widgets/skeleton.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

enum _ControlSection { pdu1, pdu2, ac }

class _ControlScreenState extends State<ControlScreen>
    with TickerProviderStateMixin {
  static const int _pdu1NodeId = 6; // Verified from SetupACPDU.har
  static const int _pdu2NodeId = 7; // Verified from SetupACPDU.har

  bool _loading = true;
  bool _refreshing = false;
  bool _writing = false;

  _NodeMetrics? _pdu1;
  _NodeMetrics? _pdu2;
  _NodeMetrics? _ac;
  String? _acHint;
  _ControlSection _section = _ControlSection.pdu1;
  late final AnimationController _tabSelC;

  @override
  void initState() {
    super.initState();
    _tabSelC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 0.0,
      upperBound: 2.0,
    );
    _fetchAll();
  }

  void _selectTab(_ControlSection s) {
    if (_section == s) return;
    setState(() => _section = s);
    _tabSelC.animateTo(
      s.index.toDouble(),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _fetchAll();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _fetchAll() async {
    try {
      final pdu1Res = await _fetchNodeWithMetricPreferAdapter(_pdu1NodeId);
      final pdu2Res = await _fetchNodeWithMetricPreferAdapter(_pdu2NodeId);
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
            'writable': acRes.rows.where((r) => r.write).length,
            'sample': [
              for (final r in acRes.rows.where((x) => x.write).take(6))
                {
                  'metric': r.metricCode,
                  'name': r.name,
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
        _pdu1 = _NodeMetrics.fromApi(pdu1Res);
        _pdu2 = _NodeMetrics.fromApi(pdu2Res);
        _ac = acRes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchNodeWithMetricPreferAdapter(int nodeId) async {
    final site = CpanelApiService.instance.currentSite;
    final siteId = site == null
        ? null
        : (int.tryParse(site['site_id']?.toString() ?? '') ??
            int.tryParse(site['id']?.toString() ?? ''));

    if (AdapterApiService.instance.isConfigured && siteId != null) {
      final res = await AdapterApiService.instance
          .fetchNodeWithMetric(siteId: siteId, nodeId: nodeId);
      if (res != null) return res;
    }
    return ApiService.instance.fetchNodeWithMetric(nodeId);
  }

  Future<_NodeMetrics?> _discoverAndFetchAc() async {
    // We can’t hardcode AC node id reliably. Try to discover it from the same
    // endpoint the vendor uses for the Power Environment list.
    //
    // If this doesn’t find AC in your deployment, we’ll need an HAR capture
    // of the AC control page to identify the correct node id + metric codes.
    try {
      // In vendor deployments the name is often just "AC" (uppercase), but the
      // backend "like" filter appears case-sensitive in some environments.
      // We prefer a lower-case wildcard and fall back if needed.
      var list = await ApiService.instance.fetchPowerEnvNodes(name: '*ac*');
      final recordsTry1 = (list?['result']?['records'] as List?) ?? const [];
      if (recordsTry1.isEmpty) {
        list = await ApiService.instance.fetchPowerEnvNodes(name: '*AC*');
      }
      final records = (list?['result']?['records'] as List?) ?? const [];
      final candidates = <Map<String, dynamic>>[];
      for (final r in records) {
        if (r is! Map) continue;
        candidates.add(r.cast<String, dynamic>());
      }

      // Pick the “most AC-like” record.
      candidates.sort((a, b) => _acScore(b).compareTo(_acScore(a)));
      final pick = candidates.isEmpty ? null : candidates.first;
      final id = pick?['id'];
      final nodeId =
          (id is num) ? id.toInt() : int.tryParse(id?.toString() ?? '');
      // ACSetup.har confirms AC can be nodeId=17 on at least one deployment.
      final resolvedNodeId = nodeId ?? 17;

      final res = await ApiService.instance.fetchNodeWithMetric(resolvedNodeId);
      final node = _NodeMetrics.fromApi(res);
      if (node == null) {
        _acHint = 'AC metrics unavailable (node $resolvedNodeId).';
      }
      return node;
    } catch (_) {
      // ACSetup.har confirms AC can be nodeId=17 on at least one deployment.
      try {
        final res = await ApiService.instance.fetchNodeWithMetric(17);
        final node = _NodeMetrics.fromApi(res);
        if (node != null) return node;
      } catch (_) {}
      _acHint =
          'AC discovery failed. Ensure the AC device is configured in the vendor system.';
      return null;
    }
  }

  int _acScore(Map<String, dynamic> r) {
    final name = (r['name'] ?? '').toString().toLowerCase();
    final type =
        (r['nodeTypeCode'] ?? r['nodeTypeName'] ?? '').toString().toLowerCase();
    int s = 0;
    if (name.contains('ac')) s += 10;
    if (name.contains('air')) s += 5;
    if (type.contains('ac')) s += 10;
    if (type.contains('air')) s += 6;
    return s;
  }

  @override
  void dispose() {
    _tabSelC.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    final isLight = Theme.of(context).brightness == Brightness.light;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? Colors.white : const Color(0xFF0E141B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = switch (_section) {
      _ControlSection.pdu1 => _pdu1,
      _ControlSection.pdu2 => _pdu2,
      _ControlSection.ac => _ac,
    };
    final hint = _section == _ControlSection.ac ? _acHint : null;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final hPadding = AppSpacing.pageHorizontal(context);
    final subTextColor = isLight
        ? AppTheme.lightTextSecondary
        : Colors.white.withValues(alpha: 0.65);

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          edgeOffset: AppConstants.headerClearance(context),
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: AppConstants.headerClearance(context)),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionButtons(),
                      const SizedBox(height: AppSpacing.sectionGapSm),
                      if (_writing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 25, left: 4),
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
                      _loading
                          ? _tableSkeleton()
                          : _nodeTable(node, hint: hint),
                      const SizedBox(height: AppSpacing.sectionGapMd),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Note: Control actions mirror the hardware dashboard. If AC controls do not appear, the device may require manual configuration on the physical panel.',
                          style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppTheme.lightTextSecondary
                                      .withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ),
                      SizedBox(height: AppSpacing.pageBottom(context)), // Bottom padding
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

  Widget _buildSectionButtons() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : const Color(0xFF0E141B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppTheme.lightStroke
                    : const Color(0x22FFFFFF)),
          ),
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _tabSelC,
                  builder: (context, _) {
                    final sel = _tabSelC.value.clamp(0.0, 2.0);

                    // Dynamic colors for PDUs, fixed for AC
                    final p1C = _getDeviceColor(_ControlSection.pdu1);
                    final p2C = _getDeviceColor(_ControlSection.pdu2);
                    const acC = Color(0xFF3271D7); // Blue like Energy

                    Color accentColor;
                    if (sel <= 1.0) {
                      accentColor = Color.lerp(p1C, p2C, sel)!;
                    } else {
                      accentColor = Color.lerp(p2C, acC, sel - 1.0)!;
                    }

                    final alignX = -1.0 + (sel * 1.0);

                    return Align(
                      alignment: Alignment(alignX, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / 3,
                        heightFactor: 1.0,
                        child: _AuraPill(color: accentColor),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    _navBtn('PDU 1', _ControlSection.pdu1),
                    _navBtn('PDU 2', _ControlSection.pdu2),
                    _navBtn('AC', _ControlSection.ac),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _navBtn(String label, _ControlSection s) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(s),
        behavior: HitTestBehavior.opaque,
        child: Center(
            child: AnimatedBuilder(
              animation: _tabSelC,
              builder: (context, _) {
                final t = _tabSelC.value.clamp(0.0, 2.0);
                final selectedness =
                    (1.0 - (t - s.index).abs()).clamp(0.0, 1.0).toDouble();
                final isLight =
                    Theme.of(context).brightness == Brightness.light;
                const selectedColor = Colors.white;
                final unselectedColor = isLight
                    ? AppTheme.lightTextSecondary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.5);
                return Text(
                  label,
                  style: TextStyle(
                    color: Color.lerp(
                        unselectedColor, selectedColor, selectedness),
                    fontSize: 12,
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
            color: Theme.of(context).brightness == Brightness.light ? Colors.white : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: Theme.of(context).brightness == Brightness.light
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: writable.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).brightness == Brightness.light 
                    ? Colors.black.withValues(alpha: 0.05) 
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            itemBuilder: (context, idx) {
              final r = writable[idx];
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
        if (writable.isEmpty)
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
    required String time, // Time is kept in signature but not displayed per request
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
              : const Color(0xFF0E141B).withValues(alpha: 0.96),
          borderColor: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightStroke
              : const Color(0x22FFFFFF),
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
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25)),
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DashboardGlass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          tint: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF0E141B).withValues(alpha: 0.96),
          borderColor: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightStroke
              : const Color(0x22FFFFFF),
          child: SafeArea(
            top: false,
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
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text('Current: ${row.displayValue}',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.light
                            ? AppTheme.lightTextSecondary
                            : Colors.white.withValues(alpha: 0.7))),
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
          ),
        );
      },
    );
  }

  Widget _chip(
      {required String label,
      required bool active,
      required VoidCallback onTap}) {
    final c =
        active ? Colors.orangeAccent : Colors.white.withValues(alpha: 0.18);
    return InkWell(
      onTap: _writing ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: active ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppTheme.lightTextPrimary
                    : Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w900)),
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
              : const Color(0xFF0E141B).withValues(alpha: 0.96),
          borderColor: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightStroke
              : const Color(0x22FFFFFF),
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
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25)),
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

    final authorized = await SecureActionGuard.ensureAuthorized(
      context,
      reason: 'Confirm to apply control setting',
      ttl: const Duration(seconds: 30),
    );
    if (!mounted) return;
    if (!authorized) return;

    setState(() => _writing = true);
    try {
      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      Map<String, dynamic>? res;
      if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.writeNodeMetric(
          siteId: siteId,
          nodeId: nodeId,
          metricTypeLibCode: metricCode,
          value: value,
        );
      }
      res ??= await ApiService.instance.writeNodeMetric(
          nodeId: nodeId, metricTypeLibCode: metricCode, value: value);

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
        border: Border.all(color: const Color(0x22FFFFFF)),
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
    final r = res['result'];
    if (r is! Map) return null;
    final id = (r['id'] is num)
        ? (r['id'] as num).toInt()
        : int.tryParse(r['id']?.toString() ?? '');
    if (id == null) return null;
    final name = r['name']?.toString() ?? 'Node $id';
    final metrics = (r['metrics'] as List?) ?? const [];
    final rows = <_MetricRow>[];
    for (final m in metrics) {
      if (m is! Map) continue;
      rows.add(_MetricRow.fromMetric(m.cast<String, dynamic>()));
    }
    return _NodeMetrics(id: id, name: name, rows: rows);
  }
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

  const _MetricRow({
    required this.metricCode,
    required this.name,
    required this.unit,
    required this.updateTime,
    required this.write,
    required this.writeMap,
    required this.currentIntValue,
    required this.displayValue,
  });

  static _MetricRow fromMetric(Map<String, dynamic> m) {
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

    return _MetricRow(
      metricCode: metricCode,
      name: name,
      unit: unit,
      updateTime: updateTime,
      write: write,
      writeMap: writeMap,
      currentIntValue: intVal,
      displayValue: display,
    );
  }
}
