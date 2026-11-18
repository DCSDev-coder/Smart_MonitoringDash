import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/auth/session_flow_service.dart';
import '../../core/controllers/global_status_poller.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../shared/widgets/safe_network_image.dart';
import '../smart_rack_console/models/smart_rack_console_snapshot.dart';
import '../smart_rack_console/services/rack_console_preferences.dart';
import '../smart_rack_console/services/smart_rack_console_repository.dart';
import '../smart_rack_console/theme/console_theme.dart';
import '../smart_rack_console/widgets/pue_charts.dart';


class FullscreenMonitoringScreen extends StatefulWidget {
  const FullscreenMonitoringScreen({super.key});

  @override
  State<FullscreenMonitoringScreen> createState() =>
      _FullscreenMonitoringScreenState();
}

class _FullscreenMonitoringScreenState
    extends State<FullscreenMonitoringScreen> {
  PageController? _pageController;
  final FocusNode _focusNode = FocusNode();
  int _currentPage = 0;
  List<Map<String, dynamic>> _branches = const [];
  bool _switchingBranch = false;

  @override
  void initState() {
    super.initState();
    final current = CpanelApiService.instance.currentSite;
    if (current != null) {
      _branches = [Map<String, dynamic>.from(current)];
    }
    _pageController = PageController(initialPage: 0);
    _loadBranches();

    // Ensure all supplemental sections are hydrated for the active branch.
    SmartRackConsoleRepository.instance.requestSections(const {
      RackConsoleSupplementalSection.overview,
      RackConsoleSupplementalSection.power,
      RackConsoleSupplementalSection.ups,
      RackConsoleSupplementalSection.ac,
      RackConsoleSupplementalSection.pdu,
    });
  }

  Future<void> _loadBranches() async {
    try {
      final raw = await CpanelApiService.instance.fetchUserSites();
      if (!mounted) return;
      final parsed = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((s) => !CpanelApiService.instance.isCurrentSiteRackConsole(s))
          .toList();
      if (parsed.isEmpty) return;

      final currentId = CpanelApiService.instance.currentSite?['site_id']?.toString();
      var initialIdx = parsed.indexWhere((s) => s['site_id']?.toString() == currentId);
      if (initialIdx < 0) initialIdx = 0;

      setState(() {
        _branches = parsed;
        _currentPage = initialIdx;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController?.hasClients == true) {
          _pageController!.jumpToPage(initialIdx);
        }
      });
    } catch (_) {
      // Keep current active site if fetch fails.
    }
  }

  String _branchName(Map<String, dynamic>? site, String fallback) {
    final name = (site?['site_name'] ?? site?['name'] ?? '').toString().trim();
    return name.isNotEmpty ? name : fallback;
  }

  Future<void> _onBranchChanged(int index) async {
    if (index < 0 || index >= _branches.length) return;
    setState(() {
      _currentPage = index;
      _switchingBranch = true;
    });
    final target = Map<String, dynamic>.from(_branches[index]);
    final currentId = CpanelApiService.instance.currentSite?['site_id']?.toString();
    final targetId = target['site_id']?.toString();
    if (currentId != targetId) {
      try {
        final merged = await CpanelApiService.instance
            .mergeCurrentMemberPermissions(target);
        CpanelApiService.instance.currentSite = merged;
        await SessionFlowService.instance.connectRackSession(merged);
        await GlobalStatusPoller.instance.fetchNow();
        await SmartRackConsoleRepository.instance.refreshSections(const {
          RackConsoleSupplementalSection.overview,
          RackConsoleSupplementalSection.power,
          RackConsoleSupplementalSection.ups,
          RackConsoleSupplementalSection.ac,
          RackConsoleSupplementalSection.pdu,
        });
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _switchingBranch = false);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (_branches.isEmpty) return;
    final target = index.clamp(0, _branches.length - 1);
    _pageController?.animateToPage(
      target,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goToPage(_currentPage + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goToPage(_currentPage - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: ConsoleTheme.isDark(context)
            ? const Color(0xFF060B12)
            : ConsoleTheme.appBg(context),
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NocGridBackdropPainter(
                    isDark: ConsoleTheme.isDark(context),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  SmartRackConsoleRepository.instance,
                  RackConsolePreferences.instance,
                ]),
                builder: (context, _) {
                  final snapshot =
                      SmartRackConsoleRepository.instance.currentSnapshot();
                  final totalBranches = math.max(1, _branches.length);
                  final activeBranch = (_currentPage >= 0 &&
                          _currentPage < _branches.length)
                      ? _branches[_currentPage]
                      : null;
                  final branchTitle = _branchName(
                    activeBranch,
                    snapshot.siteName,
                  );

                  return Column(
                    children: [
                      _WallboardTopBar(
                        boardTitle: _switchingBranch
                            ? 'Switching to $branchTitle...'
                            : 'Branch ${_currentPage + 1} of $totalBranches  •  $branchTitle',
                        currentPage: _currentPage,
                        totalPages: totalBranches,
                        onPrevPage: () => _goToPage(_currentPage - 1),
                        onNextPage: () => _goToPage(_currentPage + 1),
                        onSelectPage: _goToPage,
                        onExit: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: const {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: totalBranches,
                            onPageChanged: _onBranchChanged,
                            itemBuilder: (context, index) => _CommandCenterBoard(
                              key: ValueKey<String>(
                                  'branch_${_branches.isNotEmpty ? (_branches[index]['site_id'] ?? index) : index}'),
                              snapshot: snapshot,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TOP HEADER BAR
// ═════════════════════════════════════════════════════════════════════════════

class _WallboardTopBar extends StatefulWidget {
  const _WallboardTopBar({
    required this.boardTitle,
    required this.currentPage,
    required this.totalPages,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onSelectPage,
    required this.onExit,
  });

  final String boardTitle;
  final int currentPage;
  final int totalPages;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onExit;

  @override
  State<_WallboardTopBar> createState() => _WallboardTopBarState();
}

class _WallboardTopBarState extends State<_WallboardTopBar> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = CpanelApiService.instance.currentCompanyLogoUrl();
    final prefs = RackConsolePreferences.instance;
    final dateStr = DateFormat('yyyy-MM-dd').format(_now);
    final dayStr = DateFormat('EEEE').format(_now);
    final timeStr = prefs.formatClock(_now);

    final isDark = ConsoleTheme.isDark(context);
    final accent = isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A111C).withValues(alpha: 0.92)
            : ConsoleTheme.panelBg(context).withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(
            color: accent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Logo + Site Name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logoUrl != null && logoUrl.isNotEmpty)
                SafeNetworkImage(
                  logoUrl,
                  height: 30,
                  fit: BoxFit.contain,
                  errorBuilder: (_) => Image.asset(
                    'assets/DCS_Logo/DCS Logo.png',
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Image.asset(
                  'assets/DCS_Logo/DCS Logo.png',
                  height: 30,
                  fit: BoxFit.contain,
                ),
            ],
          ),

          const Spacer(),

          // Center: Title + Swipe Navigation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NocChevronButton(
                icon: Icons.chevron_left_rounded,
                enabled: widget.currentPage > 0,
                onTap: widget.onPrevPage,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Data Center Monitoring',
                    style: ConsoleTheme.font(
                      color: ConsoleTheme.textPrimary(context),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.boardTitle,
                        style: ConsoleTheme.font(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(widget.totalPages, (i) {
                        final active = i == widget.currentPage;
                        return GestureDetector(
                          onTap: () => widget.onSelectPage(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: active ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? accent
                                  : ConsoleTheme.textMuted(context)
                                      .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),
              _NocChevronButton(
                icon: Icons.chevron_right_rounded,
                enabled: widget.currentPage < widget.totalPages - 1,
                onTap: widget.onNextPage,
              ),
            ],
          ),

          const Spacer(),

          // Right: Date/Time + Exit Fullscreen
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$dateStr  $timeStr',
                    style: ConsoleTheme.font(
                      color: ConsoleTheme.textPrimary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    dayStr,
                    style: ConsoleTheme.font(
                      color: ConsoleTheme.textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Tooltip(
                message: 'Exit Fullscreen (Esc)',
                child: InkWell(
                  onTap: widget.onExit,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ConsoleTheme.innerSurface(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.fullscreen_exit_rounded,
                      color: accent,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NocChevronButton extends StatelessWidget {
  const _NocChevronButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = ConsoleTheme.isDark(context);
    final accent = isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: ConsoleTheme.innerSurface(context)
              .withValues(alpha: enabled ? 1.0 : 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? accent.withValues(alpha: 0.4)
                : ConsoleTheme.cardBorder(context),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? accent
              : ConsoleTheme.textMuted(context).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOARD 1: COMMAND CENTER OVERVIEW (3-column NOC layout)
// ═════════════════════════════════════════════════════════════════════════════

class _CommandCenterBoard extends StatelessWidget {
  const _CommandCenterBoard({super.key, required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = math.max(300.0, constraints.maxHeight - 28);
        final bottomH = ((totalH - 24) * 0.32).clamp(140.0, 420.0);

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT COLUMN
              Expanded(
                flex: 28,
                child: Column(
                  children: [
                    Expanded(
                      flex: 32,
                      child: _HealthStatisticsCard(snapshot: snapshot),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 36,
                      child: _DeviceHealthBarsCard(snapshot: snapshot),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: bottomH,
                      child: _AlarmStatisticsCard(snapshot: snapshot),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // CENTER COLUMN
              Expanded(
                flex: 44,
                child: Column(
                  children: [
                    SizedBox(
                      height: 82,
                      child: _TopKpiStrip(snapshot: snapshot),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _CenterTopologyHub(snapshot: snapshot),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: bottomH,
                      child: _TrendAnalysisNocCard(snapshot: snapshot),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // RIGHT COLUMN
              Expanded(
                flex: 28,
                child: Column(
                  children: [
                    Expanded(
                      flex: 36,
                      child: _EnvironmentCard(snapshot: snapshot),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 32,
                      child: _BottomAlarmsTableCard(snapshot: snapshot),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: bottomH,
                      child: _DoorsAndCapacityCard(snapshot: snapshot),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HealthStatisticsCard extends StatelessWidget {
  const _HealthStatisticsCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.totalDevices > 0 ? snapshot.totalDevices : 1;
    final abnormal = snapshot.devices.where((d) {
      final s = (d['status'] ?? d['deviceStatus'] ?? '').toString().toLowerCase();
      return s.contains('off') ||
          s.contains('alarm') ||
          s.contains('err') ||
          s.contains('fault');
    }).length;
    final normalPct =
        (((total - abnormal).clamp(0, total) / total) * 100).round();

    return _NocPanel(
      title: 'System & Health Statistics',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ringSize =
              (math.min(constraints.maxWidth * 0.42, constraints.maxHeight * 0.88))
                  .clamp(96.0, 175.0);
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, anim, child) => CustomPaint(
                        painter: _RingChartPainter(
                          progress: anim,
                          trackColor: ConsoleTheme.isDark(context)
                              ? const Color(0xFF16243A)
                              : const Color(0xFFDCE7F5),
                          segments: [
                            _RingSegment(
                              fraction: normalPct / 100.0,
                              color: ConsoleTheme.isDark(context)
                                  ? const Color(0xFF26D7FF)
                                  : ConsoleTheme.primaryBlue(context),
                            ),
                            _RingSegment(
                              fraction: (100 - normalPct) / 100.0,
                              color: const Color(0xFFFF4D4F),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$normalPct%',
                              style: ConsoleTheme.font(
                                color: ConsoleTheme.textPrimary(context),
                                fontSize: (ringSize * 0.2).clamp(18.0, 30.0),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Normal',
                              style: ConsoleTheme.font(
                                color: ConsoleTheme.textSecondary(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendStatRow(
                      color: ConsoleTheme.isDark(context)
                          ? const Color(0xFF26D7FF)
                          : ConsoleTheme.primaryBlue(context),
                      label: 'Normal',
                      value: '$normalPct%',
                    ),
                    const SizedBox(height: 12),
                    _LegendStatRow(
                      color: const Color(0xFFFF4D4F),
                      label: 'Abnormal',
                      value: '${100 - normalPct}%',
                    ),
                    const SizedBox(height: 12),
                    _LegendStatRow(
                      color: snapshot.healthColor,
                      label: 'Status',
                      value: snapshot.healthLabel,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceHealthBarsCard extends StatefulWidget {
  const _DeviceHealthBarsCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<_DeviceHealthBarsCard> createState() => _DeviceHealthBarsCardState();
}

class _DeviceHealthBarsCardState extends State<_DeviceHealthBarsCard> {
  String _mode = 'PE';

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final Map<String, int> counts;

    if (_mode == 'PE') {
      counts = <String, int>{
        'UPS': 0,
        'Smoke': 0,
        'Temp. & Hyd.': 0,
        'Power': 0,
        'AC': 0,
        'PDU': 0,
        'Door': 0,
      };

      for (final d in snapshot.devices) {
        final raw =
            (d['deviceType'] ?? d['typeName'] ?? d['name'] ?? '').toString().toLowerCase();
        if (raw.contains('ups')) {
          counts['UPS'] = (counts['UPS'] ?? 0) + 1;
        } else if (raw.contains('smoke')) {
          counts['Smoke'] = (counts['Smoke'] ?? 0) + 1;
        } else if (raw.contains('temp') || raw.contains('hum') || raw.contains('th')) {
          counts['Temp. & Hyd.'] = (counts['Temp. & Hyd.'] ?? 0) + 1;
        } else if (raw.contains('pdu')) {
          counts['PDU'] = (counts['PDU'] ?? 0) + 1;
        } else if (raw.contains('power') || raw.contains('meter')) {
          counts['Power'] = (counts['Power'] ?? 0) + 1;
        } else if (raw.contains('ac') || raw.contains('air')) {
          counts['AC'] = (counts['AC'] ?? 0) + 1;
        } else if (raw.contains('door') || raw.contains('access')) {
          counts['Door'] = (counts['Door'] ?? 0) + 1;
        }
      }

      if (counts.values.every((v) => v == 0)) {
        counts['UPS'] = snapshot.upsParameterRows.isNotEmpty ? 1 : 0;
        counts['Smoke'] = snapshot.smokeStatus >= 0 ? 1 : 0;
        counts['Temp. & Hyd.'] = snapshot.temperatures.length;
        counts['Power'] = snapshot.powerInletRows.isNotEmpty ? 1 : 0;
        counts['AC'] = snapshot.acMetricRows.isNotEmpty ? 1 : 0;
        counts['PDU'] =
            (snapshot.powerPdu1MetricRows.isNotEmpty ? 1 : 0) +
                (snapshot.powerPdu2MetricRows.isNotEmpty ? 1 : 0);
        counts['Door'] = snapshot.doors.length;
      }
    } else {
      final itDevices = snapshot.devices.where((d) {
        final raw =
            (d['deviceType'] ?? d['typeName'] ?? d['name'] ?? '').toString().toLowerCase();
        return raw.contains('it') ||
            raw.contains('server') ||
            raw.contains('switch') ||
            raw.contains('net') ||
            raw.contains('router');
      }).length;
      counts = <String, int>{
        'IT': itDevices,
        'NIC': snapshot.networkInterfaces.length,
        'CPU': (snapshot.cpuUsedPct ?? 0).round(),
        'RAM': (snapshot.memoryUsedPct ?? 0).round(),
        'Disk': (snapshot.diskUsedPct ?? 0).round(),
      };
    }

    final maxVal = math.max(1, counts.values.fold<int>(0, math.max));
    final abnormalCount = snapshot.issueCount;
    final healthyCount = math.max(0, snapshot.totalDevices - abnormalCount);

    final isDark = ConsoleTheme.isDark(context);
    final healthyColor = isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);

    return _NocPanel(
      title: 'Device Health',
      trailing: _NocFilterPills(
        options: const ['PE', 'IT'],
        selected: _mode,
        onSelected: (v) => setState(() => _mode = v),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MiniMetricBadge(
                icon: Icons.favorite_rounded,
                color: healthyColor,
                label: 'Healthy',
                value: '$healthyCount',
              ),
              const SizedBox(width: 14),
              _MiniMetricBadge(
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFF4D4F),
                label: 'Abnormal',
                value: '$abnormalCount',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            key: ValueKey<String>('dev_health_$_mode'),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 22),
                    child: CustomPaint(
                      painter: _BarChartGridPainter(
                        steps: math.min(4, maxVal),
                        columnCount: counts.length,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: counts.entries.map((e) {
                final ratio = e.value / maxVal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${e.value}',
                          style: ConsoleTheme.font(
                            color: ConsoleTheme.textSecondary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0.08,
                                end: ratio.clamp(0.08, 1.0),
                              ),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, child) =>
                                  FractionallySizedBox(
                                heightFactor: val,
                                child: child,
                              ),
                              child: Container(
                                width: 18,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF26D7FF),
                                      Color(0xFF1E90FF),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.key,
                          style: ConsoleTheme.font(
                            color: ConsoleTheme.textSecondary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmStatisticsCard extends StatefulWidget {
  const _AlarmStatisticsCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<_AlarmStatisticsCard> createState() => _AlarmStatisticsCardState();
}

class _AlarmStatisticsCardState extends State<_AlarmStatisticsCard> {
  String _range = 'Now';

  DateTime? _parseAlarmTime(Map a) {
    final raw = a['alarmTime'] ?? a['createTime'] ?? a['time'] ?? a['timestamp'];
    if (raw == null) return null;
    if (raw is num) {
      final ms = raw > 1000000000000 ? raw.toInt() : (raw * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.tryParse(raw.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cutoff = switch (_range) {
      'Week' => now.subtract(const Duration(days: 7)),
      'Month' => now.subtract(const Duration(days: 30)),
      _ => now.subtract(const Duration(hours: 24)),
    };

    final filtered = widget.snapshot.alarms.where((a) {
      if (a is! Map) return false;
      final dt = _parseAlarmTime(a);
      if (dt == null) return true;
      return !dt.isBefore(cutoff);
    }).toList();

    int info = 0, minor = 0, major = 0, critical = 0;
    for (final a in filtered) {
      if (a is! Map) continue;
      final lvl = (a['alarmLevel'] ?? a['level'] ?? '').toString().toLowerCase();
      if (lvl.contains('crit') || lvl.contains('urg')) {
        critical++;
      } else if (lvl.contains('maj')) {
        major++;
      } else if (lvl.contains('min') || lvl.contains('warn')) {
        minor++;
      } else {
        info++;
      }
    }
    final total = filtered.length;
    final denom = math.max(1, total);

    return _NocPanel(
      title: 'Alarm Statistics',
      trailing: _NocFilterPills(
        options: const ['Now', 'Week', 'Month'],
        selected: _range,
        onSelected: (v) => setState(() => _range = v),
      ),
      child: LayoutBuilder(
        key: ValueKey<String>('alarm_stats_$_range'),
        builder: (context, constraints) {
          final ringSize =
              (math.min(constraints.maxWidth * 0.42, constraints.maxHeight * 0.88))
                  .clamp(92.0, 165.0);
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, anim, child) => CustomPaint(
                        painter: _RingChartPainter(
                          progress: anim,
                          trackColor: ConsoleTheme.isDark(context)
                              ? const Color(0xFF16243A)
                              : const Color(0xFFDCE7F5),
                          segments: total == 0
                              ? [
                                  _RingSegment(
                                    fraction: 1.0,
                                    color: ConsoleTheme.isDark(context)
                                        ? const Color(0xFF24344D)
                                        : const Color(0xFFDCE7F5),
                                  ),
                                ]
                              : [
                                  _RingSegment(
                                    fraction: info / denom,
                                    color: const Color(0xFF26D7FF),
                                  ),
                                  _RingSegment(
                                    fraction: minor / denom,
                                    color: const Color(0xFF10B981),
                                  ),
                                  _RingSegment(
                                    fraction: major / denom,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                  _RingSegment(
                                    fraction: critical / denom,
                                    color: const Color(0xFFFF4D4F),
                                  ),
                                ],
                        ),
                        child: child,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: ConsoleTheme.font(
                                color: ConsoleTheme.textPrimary(context),
                                fontSize: (ringSize * 0.2).clamp(18.0, 30.0),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Total',
                              style: ConsoleTheme.font(
                                color: ConsoleTheme.textSecondary(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendStatRow(
                        color: const Color(0xFF26D7FF),
                        label: 'Info',
                        value: '$info'),
                    const SizedBox(height: 8),
                    _LegendStatRow(
                        color: const Color(0xFF10B981),
                        label: 'Minor',
                        value: '$minor'),
                    const SizedBox(height: 8),
                    _LegendStatRow(
                        color: const Color(0xFFF59E0B),
                        label: 'Major',
                        value: '$major'),
                    const SizedBox(height: 8),
                    _LegendStatRow(
                        color: const Color(0xFFFF4D4F),
                        label: 'Critical',
                        value: '$critical'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopKpiStrip extends StatelessWidget {
  const _TopKpiStrip({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final uptimeDays =
        (snapshot.systemUptimeDays != null && snapshot.systemUptimeDays! > 0)
            ? snapshot.systemUptimeDays!
            : 142;
    final maintDays = snapshot.maintenanceDaysLeft ?? 79;

    final isDark = ConsoleTheme.isDark(context);
    final uptimeAccent = isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);
    final alarmAccent = snapshot.issueCount > 0
        ? const Color(0xFFFF4D4F)
        : (isDark ? const Color(0xFF10B981) : const Color(0xFF059669));

    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            icon: Icons.dns_rounded,
            accent: uptimeAccent,
            title: 'Uptime',
            primaryValue: '${uptimeDays}d',
            subLabel: 'Maint: ${maintDays}d',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
            icon: Icons.memory_rounded,
            accent: const Color(0xFF1E90FF),
            title: 'Devices',
            primaryValue: '${snapshot.totalDevices}',
            subLabel: 'Active: ${snapshot.totalDevices}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
            icon: Icons.notifications_active_rounded,
            accent: alarmAccent,
            title: 'Alarms',
            primaryValue: '${snapshot.issueCount}',
            subLabel: snapshot.issueCount == 0 ? 'All Clear' : 'Attention',
          ),
        ),
      ],
    );
  }
}

class _CenterTopologyHub extends StatefulWidget {
  const _CenterTopologyHub({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<_CenterTopologyHub> createState() => _CenterTopologyHubState();
}

class _CenterTopologyHubState extends State<_CenterTopologyHub>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  double _dragAngleOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final pueText =
        snapshot.pue != null ? snapshot.pue!.toStringAsFixed(2) : '--';
    final energyText = snapshot.totalMonthEnergyKwh != null
        ? '${snapshot.totalMonthEnergyKwh!.toStringAsFixed(1)} kWh'
        : '-- kWh';
    final tempText = snapshot.temperatureC != null
        ? '${snapshot.temperatureC!.toStringAsFixed(0)}°C'
        : '--';
    final humText = snapshot.humidityPct != null
        ? '${snapshot.humidityPct!.toStringAsFixed(0)}%'
        : '--';

    final accentHeader = ConsoleTheme.isDark(context)
        ? const Color(0xFF26D7FF)
        : ConsoleTheme.primaryBlue(context);

    return _NocPanel(
      title: 'Live Rack Topology',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ConsoleTheme.innerSurface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accentHeader.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current PUE: ',
              style: ConsoleTheme.font(
                color: ConsoleTheme.textSecondary(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              pueText,
              style: ConsoleTheme.font(
                color: accentHeader,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '  •  Monthly Energy: ',
              style: ConsoleTheme.font(
                color: ConsoleTheme.textSecondary(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              energyText,
              style: ConsoleTheme.font(
                color: accentHeader,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nodes = <_TopologyNode>[
            _TopologyNode(
              label: 'AC',
              value: snapshot.acUnitStatus ?? 'Online',
              icon: Icons.ac_unit_rounded,
              ok: !(snapshot.acUnitStatus ?? '').toLowerCase().contains('off'),
            ),
            _TopologyNode(
              label: 'UPS',
              value: snapshot.upsStatusRows.isNotEmpty
                  ? snapshot.upsStatusRows.first.value
                  : 'Normal',
              icon: Icons.battery_charging_full_rounded,
              ok: true,
            ),
            _TopologyNode(
              label: 'Power',
              value: snapshot.itPowerKw != null
                  ? '${snapshot.itPowerKw!.toStringAsFixed(2)} kW'
                  : 'Active',
              icon: Icons.bolt_rounded,
              ok: true,
            ),
            _TopologyNode(
              label: 'Temp. & Hyd.',
              value: '$tempText / $humText',
              icon: Icons.thermostat_rounded,
              ok: true,
            ),
            _TopologyNode(
              label: 'Doors',
              value: '${snapshot.doors.length} Lock',
              icon: Icons.door_front_door_rounded,
              ok: !snapshot.doors.any((d) => d['isOpen'] == true),
            ),
            const _TopologyNode(
              label: 'PDU',
              value: 'Online',
              icon: Icons.power_rounded,
              ok: true,
            ),
          ];

          return AnimatedBuilder(
            animation: _spinController,
            builder: (context, _) {
              final spin =
                  (_spinController.value * 2 * math.pi) + _dragAngleOffset;
              const tilt = 0.0;
              final rx = (constraints.maxWidth * 0.42).clamp(150.0, 390.0);
              final ry = (constraints.maxHeight * 0.24).clamp(56.0, 120.0);
              final rackW = (constraints.maxHeight * 0.56).clamp(110.0, 225.0);
              final rackH = (constraints.maxHeight * 0.74).clamp(140.0, 295.0);
              final accent = ConsoleTheme.isDark(context)
                  ? const Color(0xFF26D7FF)
                  : ConsoleTheme.primaryBlue(context);

              Widget buildNodeWidget(_TopologyNode node, double depth) {
                final isDark = ConsoleTheme.isDark(context);
                final color = node.ok ? accent : const Color(0xFFFF4D4F);
                final scale = 0.88 + (depth + 1) * 0.10; // 0.88 behind -> 1.08 front
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E1B2E) : Colors.white,
                      gradient: isDark
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.alphaBlend(
                                  color.withValues(alpha: 0.18),
                                  const Color(0xFF0E1B2E),
                                ),
                                ConsoleTheme.innerSurface(context),
                              ],
                            )
                          : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: isDark ? 0.7 : 0.55),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? color.withValues(alpha: 0.28)
                                : const Color(0xFF183153).withValues(alpha: 0.10),
                            blurRadius: isDark ? 16 : 10,
                            offset: isDark ? Offset.zero : const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(node.icon, size: 16, color: color),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                node.label,
                                style: ConsoleTheme.font(
                                  color: ConsoleTheme.textPrimary(context),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                node.value,
                                style: ConsoleTheme.font(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
              }

              final backNodes = <Widget>[];
              final frontNodes = <Widget>[];
              for (var i = 0; i < nodes.length; i++) {
                final angle = (2 * math.pi * i / nodes.length) + spin;
                final depth = math.sin(angle); // <0 = behind rack, >=0 = front
                final ex = math.cos(angle) * rx;
                final ey = math.sin(angle) * ry;
                final dx = ex * math.cos(tilt) - ey * math.sin(tilt);
                final dy = ex * math.sin(tilt) + ey * math.cos(tilt);
                final positioned = Transform.translate(
                  offset: Offset(dx, dy),
                  child: buildNodeWidget(nodes[i], depth),
                );
                if (depth < -0.25) {
                  backNodes.add(positioned);
                } else {
                  frontNodes.add(positioned);
                }
              }

              return MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragAngleOffset += details.delta.dx * 0.008;
                    });
                  },
                  child: SizedBox.expand(
                    child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Back half of orbital ring + back orbiting nodes (behind rack)
                    CustomPaint(
                      size: Size(rx * 2.2, ry * 2.6),
                      painter: _TopologyRingPainter(
                        tiltRadians: tilt,
                        rx: rx,
                        ry: ry,
                        accent: accent,
                        spin: spin,
                        drawBack: true,
                        drawFront: false,
                      ),
                    ),
                    ...backNodes,

                    // 2. Modern Smart Rack Centerpiece with radial tech aura & live scan line
                    SizedBox(
                      width: rackW * 1.15,
                      height: rackH * 0.92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: rackW * 0.95,
                            height: rackH * 0.85,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accent.withValues(alpha: 0.26),
                                  accent.withValues(alpha: 0.06),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: rackW,
                            height: rackH * 0.90,
                            child: Image.asset(
                              RackConsolePreferences.instance.selectedRackImage,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Front half of orbital ring + front orbiting nodes (in front of rack)
                    CustomPaint(
                      size: Size(rx * 2.2, ry * 2.6),
                      painter: _TopologyRingPainter(
                        tiltRadians: tilt,
                        rx: rx,
                        ry: ry,
                        accent: accent,
                        spin: spin,
                        drawBack: false,
                        drawFront: true,
                      ),
                    ),
                    ...frontNodes,
                  ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BottomAlarmsTableCard extends StatelessWidget {
  const _BottomAlarmsTableCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final alarms = snapshot.alarms;
    return _NocPanel(
      title: 'Alarms',
      child: alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: const Color(0xFF26D7FF).withValues(alpha: 0.7),
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No Active Alarms',
                    style: ConsoleTheme.font(
                      color: ConsoleTheme.textSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: math.min(alarms.length, 6),
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: ConsoleTheme.divider(context),
              ),
              itemBuilder: (context, i) {
                final a = alarms[i] is Map ? alarms[i] as Map : const {};
                final level = (a['alarmLevel'] ?? 'INFO').toString();
                final time = (a['alarmTime'] ?? a['createTime'] ?? '--').toString();
                final item = (a['alarmItem'] ?? 'System').toString();
                final content = (a['content'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          level,
                          style: ConsoleTheme.font(
                            color: const Color(0xFFFF4D4F),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item,
                          style: ConsoleTheme.font(
                            color: ConsoleTheme.textPrimary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          content,
                          style: ConsoleTheme.font(
                            color: ConsoleTheme.textSecondary(context),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: ConsoleTheme.font(
                          color: ConsoleTheme.textMuted(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _EnvironmentCard extends StatefulWidget {
  const _EnvironmentCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<_EnvironmentCard> createState() => _EnvironmentCardState();
}

class _EnvironmentCardState extends State<_EnvironmentCard> {
  String _tab = 'Temp. & Hyd.';

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;

    return _NocPanel(
      title: 'Environment',
      trailing: _NocFilterPills(
        options: const ['Temp. & Hyd.', 'Smoke & Leak'],
        selected: _tab,
        onSelected: (v) => setState(() => _tab = v),
      ),
      child: _tab == 'Temp. & Hyd.'
          ? _buildTempHumList(snapshot)
          : _buildSmokeLeakRow(snapshot),
    );
  }

  Widget _buildTempHumList(SmartRackConsoleSnapshot snapshot) {
    final rows = <_TempHumPair>[];
    final count =
        math.max(snapshot.temperatures.length, snapshot.humidities.length);
    for (var i = 0; i < math.min(count, 4); i++) {
      final t = i < snapshot.temperatures.length ? snapshot.temperatures[i] : null;
      final h = i < snapshot.humidities.length ? snapshot.humidities[i] : null;
      final label = (t?['cabinetName'] ??
              t?['name'] ??
              h?['cabinetName'] ??
              'Cabinet ${i + 1}')
          .toString();
      final tv = double.tryParse((t?['value'] ?? '').toString()) ?? 0;
      final hv = double.tryParse((h?['value'] ?? '').toString()) ?? 0;
      rows.add(_TempHumPair(label: label, temp: tv, hum: hv));
    }

    if (rows.isEmpty) {
      rows.add(_TempHumPair(
        label: 'Cabinet 1',
        temp: snapshot.temperatureC ?? 0,
        hum: snapshot.humidityPct ?? 0,
      ));
    }

    return Column(
      key: const ValueKey<String>('env_th'),
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _SmallDotLabel(color: Color(0xFFF59E0B), label: 'Temp'),
            SizedBox(width: 8),
            _SmallDotLabel(color: Color(0xFF26D7FF), label: 'Humidity'),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows.map((r) {
              final tempFrac = (r.temp / 50.0).clamp(0.05, 1.0);
              final humFrac = (r.hum / 100.0).clamp(0.05, 1.0);
              final trackColor = ConsoleTheme.isDark(context)
                  ? const Color(0xFF1A283D)
                  : const Color(0xFFDCE7F5);
              return Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      r.label,
                      style: ConsoleTheme.font(
                        color: ConsoleTheme.textSecondary(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(4)),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.05, end: tempFrac),
                          duration: const Duration(milliseconds: 750),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) => FractionallySizedBox(
                            widthFactor: val,
                            child: child,
                          ),
                          child: Container(
                            height: 8,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(4)),
                              gradient: LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFFF8A00)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: ConsoleTheme.textMuted(context).withValues(alpha: 0.6),
                  ),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4)),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.05, end: humFrac),
                          duration: const Duration(milliseconds: 750),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) => FractionallySizedBox(
                            widthFactor: val,
                            child: child,
                          ),
                          child: Container(
                            height: 8,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(4)),
                              gradient: LinearGradient(
                                colors: [Color(0xFF18D2C3), Color(0xFF26D7FF)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    child: Text(
                      '${r.temp.toStringAsFixed(0)}°C / ${r.hum.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: ConsoleTheme.font(
                        color: ConsoleTheme.textPrimary(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSmokeLeakRow(SmartRackConsoleSnapshot snapshot) {
    final smokeOk = snapshot.smokeStatus != 1;
    final leakOk = snapshot.floodStatus != 1;

    return Row(
      key: const ValueKey<String>('env_smoke_leak'),
      children: [
        Expanded(
          child: _SensorStateTile(
            icon: Icons.smoke_free_rounded,
            label: 'Smoke',
            value: snapshot.smokeLabel,
            ok: smokeOk,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SensorStateTile(
            icon: Icons.water_drop_rounded,
            label: 'Water-leak',
            value: snapshot.waterLeakLabel,
            ok: leakOk,
          ),
        ),
      ],
    );
  }
}

class _NocFilterPills extends StatelessWidget {
  const _NocFilterPills({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = ConsoleTheme.isDark(context);
    final accent = isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ConsoleTheme.innerSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(
                        color: accent.withValues(alpha: 0.5),
                      )
                    : null,
              ),
              child: Text(
                opt,
                style: ConsoleTheme.font(
                  color: isSelected
                      ? accent
                      : ConsoleTheme.textSecondary(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TrendAnalysisNocCard extends StatefulWidget {
  const _TrendAnalysisNocCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<_TrendAnalysisNocCard> createState() => _TrendAnalysisNocCardState();
}

class _TrendAnalysisNocCardState extends State<_TrendAnalysisNocCard> {
  String _selectedMetric = 'PUE';
  String _selectedHours = '8 Hours';
  bool _isLoading = true;
  String? _error;
  List<FlSpot> _puePoints = const [];
  List<FlSpot> _powerPoints = const [];
  List<String> _bottomTitles = const [];
  List<dynamic> _trendTitleSource = const [];
  String _lastSiteName = '';

  @override
  void initState() {
    super.initState();
    _lastSiteName = widget.snapshot.siteName;
    RackConsolePreferences.instance.addListener(_handleTimeFormatChange);
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant _TrendAnalysisNocCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.siteName != _lastSiteName) {
      _lastSiteName = widget.snapshot.siteName;
      _fetchData();
    }
  }

  @override
  void dispose() {
    RackConsolePreferences.instance.removeListener(_handleTimeFormatChange);
    super.dispose();
  }

  void _handleTimeFormatChange() {
    if (!mounted) return;
    setState(() {
      _bottomTitles = _titlesFromTrend(_trendTitleSource);
    });
  }

  int _hoursValue() {
    switch (_selectedHours) {
      case '12 Hours':
        return 12;
      case '24 Hours':
        return 24;
      case 'Last Month':
        return 720;
      default:
        return 8;
    }
  }

  int _currentSiteId() {
    final site = CpanelApiService.instance.currentSite;
    return site != null
        ? (int.tryParse(site['site_id']?.toString() ?? '') ??
            int.tryParse(site['id']?.toString() ?? '1') ??
            1)
        : 1;
  }

  List<FlSpot> _spotsFromTrend(List<dynamic> points) {
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final raw = points[i];
      if (raw is! Map) continue;
      final point = Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
      final value = double.tryParse(point['trendVal']?.toString() ?? '') ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  List<String> _titlesFromTrend(List<dynamic> points) {
    final titles = <String>[];
    for (final raw in points) {
      if (raw is! Map) continue;
      final point = Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
      final stamp = (point['trendTime'] ??
              point['time'] ??
              point['timestamp'] ??
              point['date'] ??
              '')
          .toString();
      titles.add(RackConsolePreferences.instance.formatTrendLabel(stamp));
    }
    return titles;
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final siteId = _currentSiteId();
      final now = DateTime.now();
      final endTime = now.millisecondsSinceEpoch;
      final startTime =
          now.subtract(Duration(hours: _hoursValue())).millisecondsSinceEpoch;

      final pueRes = await AdapterApiService.instance.fetchPueRangeTrend(
        siteId: siteId,
        trendType: 0,
        startTime: startTime,
        endTime: endTime,
      );
      final powerRes = await AdapterApiService.instance.fetchPueRangeTrend(
        siteId: siteId,
        trendType: 1,
        startTime: startTime,
        endTime: endTime,
      );

      final puePoints =
          _spotsFromTrend((pueRes?['result'] as List?) ?? const []);
      final powerPoints =
          _spotsFromTrend((powerRes?['result'] as List?) ?? const []);

      if (!mounted) return;
      final trendTitleSource = (pueRes?['result'] as List?) ??
          (powerRes?['result'] as List?) ??
          const [];
      setState(() {
        _puePoints = puePoints;
        _powerPoints = powerPoints;
        _trendTitleSource = List<dynamic>.from(trendTitleSource);
        _bottomTitles = _titlesFromTrend(_trendTitleSource);
        _error = (puePoints.isEmpty && powerPoints.isEmpty)
            ? 'No trend data returned.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load trend data.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ConsoleTheme.isDark(context);
    final accent =
        isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);

    return _NocPanel(
      title: 'Trend Analysis',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            initialValue: _selectedHours,
            onSelected: (val) {
              setState(() => _selectedHours = val);
              _fetchData();
            },
            offset: const Offset(0, 28),
            itemBuilder: (context) => const [
              '8 Hours',
              '12 Hours',
              '24 Hours',
              'Last Month',
            ].map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: ConsoleTheme.innerSurface(context),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedHours,
                    style: ConsoleTheme.font(
                      color: ConsoleTheme.textPrimary(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: ConsoleTheme.textSecondary(context),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _NocFilterPills(
            options: const ['PUE', 'Power Consumption'],
            selected: _selectedMetric,
            onSelected: (v) => setState(() => _selectedMetric = v),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 6),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: accent,
                ),
              )
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: ConsoleTheme.font(
                        color: ConsoleTheme.textSecondary(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : PueTrendLineChart(
                    puePoints: _selectedMetric == 'PUE'
                        ? _puePoints
                        : const [FlSpot(0, 0)],
                    itEnergyPoints: const [FlSpot(0, 0)],
                    totalEnergyPoints: _selectedMetric == 'Power Consumption'
                        ? _powerPoints
                        : const [FlSpot(0, 0)],
                    bottomTitles: _bottomTitles,
                  ),
      ),
    );
  }
}

class _DoorsAndCapacityCard extends StatelessWidget {
  const _DoorsAndCapacityCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  String _shortDoorName(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('front')) return 'Front Door';
    if (lower.contains('rear') || lower.contains('back')) return 'Back Door';
    return raw.trim().isEmpty ? 'Door' : raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cap = snapshot.capacityUsedPct ?? 0.0;
    final logs = snapshot.recentDoorLogs;
    final accent = ConsoleTheme.isDark(context)
        ? const Color(0xFF26D7FF)
        : ConsoleTheme.primaryBlue(context);

    return _NocPanel(
      title: 'Space Capacity & Door History',
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Overall Capacity',
                style: ConsoleTheme.font(
                  color: ConsoleTheme.textSecondary(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${cap.toStringAsFixed(1)}%',
                style: ConsoleTheme.font(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: (cap / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) => LinearProgressIndicator(
                value: val,
                minHeight: 8,
                backgroundColor: ConsoleTheme.isDark(context)
                    ? const Color(0xFF1A283D)
                    : const Color(0xFFDCE7F5),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No recent door access history',
                      style: ConsoleTheme.font(
                        color: ConsoleTheme.textSecondary(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(math.min(logs.length, 4), (i) {
                      final log = logs[i];
                      final user = (log['opUser'] ??
                              log['openUser'] ??
                              log['userName'] ??
                              log['username'] ??
                              log['user'] ??
                              'User')
                          .toString();
                      final door = _shortDoorName(
                          (log['accessName'] ?? log['doorName'] ?? 'Door')
                              .toString());
                      final time = (log['opTime'] ??
                              log['time'] ??
                              log['accessTime'] ??
                              '')
                          .toString();
                      final isFront = door.toLowerCase().contains('front');
                      final doorColor =
                          isFront ? accent : const Color(0xFF10B981);
                      final initial =
                          user.trim().isNotEmpty ? user.trim()[0].toUpperCase() : 'U';

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              bottom: i < math.min(logs.length, 4) - 1 ? 4 : 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: ConsoleTheme.innerSurface(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: doorColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: doorColor.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: doorColor.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      initial,
                                      style: ConsoleTheme.font(
                                        color: doorColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    user,
                                    style: ConsoleTheme.font(
                                      color: ConsoleTheme.textPrimary(context),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: doorColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    door,
                                    maxLines: 1,
                                    style: ConsoleTheme.font(
                                      color: doorColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      time,
                                      maxLines: 1,
                                      style: ConsoleTheme.font(
                                        color: ConsoleTheme.textMuted(context),
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED NOC PRIMITIVES & PAINTERS
// ═════════════════════════════════════════════════════════════════════════════

class _NocPanel extends StatelessWidget {
  const _NocPanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = ConsoleTheme.isDark(context);
    final accent = isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C1422).withValues(alpha: 0.88)
            : ConsoleTheme.panelBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF26D7FF).withValues(alpha: 0.24)
              : const Color(0xFFCBD9EC),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF1E90FF).withValues(alpha: 0.06)
                : const Color(0xFF183153).withValues(alpha: 0.06),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: ConsoleTheme.font(
                    color: ConsoleTheme.textPrimary(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.primaryValue,
    required this.subLabel,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String primaryValue;
  final String subLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = ConsoleTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C1422).withValues(alpha: 0.9)
            : ConsoleTheme.panelBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? accent.withValues(alpha: 0.35)
              : const Color(0xFFCBD9EC),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ConsoleTheme.font(
                    color: ConsoleTheme.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        primaryValue,
                        style: ConsoleTheme.font(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subLabel,
                        style: ConsoleTheme.font(
                          color: ConsoleTheme.textSecondary(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorStateTile extends StatelessWidget {
  const _SensorStateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final isDark = ConsoleTheme.isDark(context);
    final okColor = isDark ? const Color(0xFF26D7FF) : ConsoleTheme.primaryBlue(context);
    final color = ok ? okColor : const Color(0xFFFF4D4F);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ConsoleTheme.innerSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: ConsoleTheme.font(
              color: ConsoleTheme.textSecondary(context),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: ConsoleTheme.font(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendStatRow extends StatelessWidget {
  const _LegendStatRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ConsoleTheme.font(
            color: ConsoleTheme.textSecondary(context),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ConsoleTheme.font(
              color: ConsoleTheme.textPrimary(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMetricBadge extends StatelessWidget {
  const _MiniMetricBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          '$label ',
          style: ConsoleTheme.font(
            color: ConsoleTheme.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: ConsoleTheme.font(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SmallDotLabel extends StatelessWidget {
  const _SmallDotLabel({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: ConsoleTheme.font(
            color: ConsoleTheme.textSecondary(context),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TopologyNode {
  const _TopologyNode({
    required this.label,
    required this.value,
    required this.icon,
    required this.ok,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool ok;
}

class _TempHumPair {
  const _TempHumPair({
    required this.label,
    required this.temp,
    required this.hum,
  });

  final String label;
  final double temp;
  final double hum;
}

class _RingSegment {
  const _RingSegment({required this.fraction, required this.color});

  final double fraction;
  final Color color;
}

class _RingChartPainter extends CustomPainter {
  const _RingChartPainter({
    required this.segments,
    this.progress = 1.0,
    this.trackColor = const Color(0xFF16243A),
  });

  final List<_RingSegment> segments;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) / 2) - 8;
    const stroke = 11.0;

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bgPaint);

    var startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweep = seg.fraction * 2 * math.pi * progress;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter oldDelegate) => true;
}

class _TopologyRingPainter extends CustomPainter {
  const _TopologyRingPainter({
    required this.tiltRadians,
    required this.rx,
    required this.ry,
    required this.accent,
    required this.spin,
    required this.drawBack,
    required this.drawFront,
  });

  final double tiltRadians;
  final double rx;
  final double ry;
  final Color accent;
  final double spin;
  final bool drawBack;
  final bool drawFront;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltRadians);

    final startArc = drawBack ? math.pi : 0.0;
    const sweepArc = math.pi;
    final alphaScale = drawBack ? 0.65 : 1.0;

    // 1. Modern beveled gear-tooth outer ring (36 precision-cut gear blocks)
    const gearTeeth = 36;
    const toothSpan = (2 * math.pi / gearTeeth) * 0.46;
    final gearFill = Paint()
      ..color = accent.withValues(alpha: 0.22 * alphaScale)
      ..style = PaintingStyle.fill;
    final gearStroke = Paint()
      ..color = accent.withValues(alpha: 0.55 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < gearTeeth; i++) {
      final a1 = (2 * math.pi * i / gearTeeth) + spin;
      final a2 = a1 + toothSpan;
      final mid = (a1 + a2) / 2;
      final isBackTooth = math.sin(mid) < 0;
      if ((isBackTooth && drawBack) || (!isBackTooth && drawFront)) {
        final path = Path()
          ..moveTo(math.cos(a1) * rx * 1.05, math.sin(a1) * ry * 1.05)
          ..lineTo(math.cos(a1 + 0.015) * rx * 1.13,
              math.sin(a1 + 0.015) * ry * 1.13)
          ..lineTo(math.cos(a2 - 0.015) * rx * 1.13,
              math.sin(a2 - 0.015) * ry * 1.13)
          ..lineTo(math.cos(a2) * rx * 1.05, math.sin(a2) * ry * 1.05)
          ..close();
        canvas.drawPath(path, gearFill);
        canvas.drawPath(path, gearStroke);
      }
    }

    // 2. Main orbital ring with continuous uniform glow
    final mainRect = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2.0,
      height: ry * 2.0,
    );
    final mainGlowPaint = Paint()
      ..color = accent.withValues(alpha: 0.22 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final mainTrackPaint = Paint()
      ..color = accent.withValues(alpha: 0.65 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawArc(mainRect, startArc, sweepArc, false, mainGlowPaint);
    canvas.drawArc(mainRect, startArc, sweepArc, false, mainTrackPaint);

    // 3. Counter-rotating dashed middle ring (POV depth)
    final midRx = rx * 0.80;
    final midRy = ry * 0.80;
    final midRect = Rect.fromCenter(
      center: Offset.zero,
      width: midRx * 2.0,
      height: midRy * 2.0,
    );
    final dashPaint = Paint()
      ..color = accent.withValues(alpha: 0.42 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const dashCount = 24;
    for (var i = 0; i < dashCount; i++) {
      final a = -spin * 0.7 + (2 * math.pi * i / dashCount);
      final isBackDash = math.sin(a) < 0;
      if ((isBackDash && drawBack) || (!isBackDash && drawFront)) {
        canvas.drawArc(midRect, a, 0.12, false, dashPaint);
      }
    }

    // 4. Inner bright ring + soft radial disc behind Smart Rack (drawBack only)
    final innerRect = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 1.18,
      height: ry * 1.18,
    );
    if (drawBack) {
      final discFill = Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ).createShader(mainRect);
      canvas.drawOval(mainRect, discFill);
    }

    final innerPaint = Paint()
      ..color = accent.withValues(alpha: 0.42 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawArc(innerRect, startArc, sweepArc, false, innerPaint);

    // Subtle radial telemetry spoke lines on the POV disc
    final spokePaint = Paint()
      ..color = accent.withValues(alpha: 0.14 * alphaScale)
      ..strokeWidth = 1.0;
    for (var i = 0; i < 6; i++) {
      final a = spin + (i * math.pi / 3);
      final isBackSpoke = math.sin(a) < 0;
      if ((isBackSpoke && drawBack) || (!isBackSpoke && drawFront)) {
        canvas.drawLine(
          Offset(math.cos(a) * rx * 0.59, math.sin(a) * ry * 0.59),
          Offset(math.cos(a) * rx * 1.0, math.sin(a) * ry * 1.0),
          spokePaint,
        );
      }
    }

    // 5. Traveling glowing energy orbs along the main orbital ring
    final orbPaint = Paint()..color = accent.withValues(alpha: alphaScale);
    final orbGlow = Paint()
      ..color = accent.withValues(alpha: 0.55 * alphaScale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (var i = 0; i < 3; i++) {
      final a = (spin * 1.6) + (i * 2 * math.pi / 3);
      final isBackOrb = math.sin(a) < 0;
      if ((isBackOrb && drawBack) || (!isBackOrb && drawFront)) {
        final pos = Offset(math.cos(a) * rx, math.sin(a) * ry);
        canvas.drawCircle(pos, 5.5, orbGlow);
        canvas.drawCircle(pos, 2.8, orbPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TopologyRingPainter oldDelegate) =>
      oldDelegate.tiltRadians != tiltRadians ||
      oldDelegate.rx != rx ||
      oldDelegate.ry != ry ||
      oldDelegate.accent != accent ||
      oldDelegate.spin != spin ||
      oldDelegate.drawBack != drawBack ||
      oldDelegate.drawFront != drawFront;
}

class _BarChartGridPainter extends CustomPainter {
  const _BarChartGridPainter({
    required this.steps,
    required this.columnCount,
    this.isDark = true,
  });

  final int steps;
  final int columnCount;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final hPaint = Paint()
      ..color = isDark
          ? const Color(0xFF26D7FF).withValues(alpha: 0.14)
          : const Color(0xFF183153).withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final vPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E90FF).withValues(alpha: 0.08)
          : const Color(0xFF183153).withValues(alpha: 0.06)
      ..strokeWidth = 1;

    final safeSteps = math.max(1, steps);
    for (var i = 0; i <= safeSteps; i++) {
      final y = size.height * (i / safeSteps);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }

    if (columnCount > 0) {
      final colWidth = size.width / columnCount;
      for (var i = 0; i < columnCount; i++) {
        final x = colWidth * (i + 0.5);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), vPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartGridPainter oldDelegate) =>
      oldDelegate.steps != steps ||
      oldDelegate.columnCount != columnCount ||
      oldDelegate.isDark != isDark;
}

class _NocGridBackdropPainter extends CustomPainter {
  const _NocGridBackdropPainter({this.isDark = true});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? const Color(0xFF1E90FF).withValues(alpha: 0.045)
          : const Color(0xFF2F80FF).withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NocGridBackdropPainter oldDelegate) => false;
}
