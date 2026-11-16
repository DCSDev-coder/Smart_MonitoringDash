import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/auth/session_flow_service.dart';
import '../../core/controllers/global_status_poller.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../shared/widgets/safe_network_image.dart';
import '../smart_rack_console/models/smart_rack_console_snapshot.dart';
import '../smart_rack_console/services/rack_console_preferences.dart';
import '../smart_rack_console/services/smart_rack_console_repository.dart';
import '../smart_rack_console/theme/console_theme.dart';

/// Fullscreen NOC / Command-Center monitoring wallboard for DCS Dashboard.
/// Displays every live subsystem status at a glance and supports horizontal
/// swiping (touch, mouse drag, arrows, and keyboard) across multiple boards.
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
        backgroundColor: const Color(0xFF060B12),
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NocGridBackdropPainter(),
                ),
              ),
            ),
            SafeArea(
              child: ListenableBuilder(
                listenable: SmartRackConsoleRepository.instance,
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
                        siteName: branchTitle,
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
    required this.siteName,
    required this.boardTitle,
    required this.currentPage,
    required this.totalPages,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onSelectPage,
    required this.onExit,
  });

  final String siteName;
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

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A111C).withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF26D7FF).withValues(alpha: 0.25),
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
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF132033),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF26D7FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  widget.siteName,
                  style: ConsoleTheme.font(
                    color: const Color(0xFF26D7FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                      color: Colors.white,
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
                          color: const Color(0xFF26D7FF),
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
                                  ? const Color(0xFF26D7FF)
                                  : Colors.white.withValues(alpha: 0.25),
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
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    dayStr,
                    style: ConsoleTheme.font(
                      color: const Color(0xFF8FA7C4),
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
                      color: const Color(0xFF132033),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF26D7FF).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.fullscreen_exit_rounded,
                      color: Color(0xFF26D7FF),
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
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF132033).withValues(alpha: enabled ? 1.0 : 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? const Color(0xFF26D7FF).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? const Color(0xFF26D7FF)
              : Colors.white.withValues(alpha: 0.25),
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
                Expanded(
                  flex: 32,
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
                  flex: 62,
                  child: _CenterTopologyHub(snapshot: snapshot),
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 38,
                  child: _BottomAlarmsTableCard(snapshot: snapshot),
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
                  flex: 38,
                  child: _TempHumidityComparisonCard(snapshot: snapshot),
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 26,
                  child: _SmokeAndLeakCard(snapshot: snapshot),
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 36,
                  child: _DoorsAndCapacityCard(snapshot: snapshot),
                ),
              ],
            ),
          ),
        ],
      ),
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
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: SizedBox(
                width: 110,
                height: 110,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, anim, child) => CustomPaint(
                    painter: _RingChartPainter(
                      progress: anim,
                      segments: [
                        _RingSegment(
                          fraction: normalPct / 100.0,
                          color: const Color(0xFF26D7FF),
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Normal',
                          style: ConsoleTheme.font(
                            color: const Color(0xFF8FA7C4),
                            fontSize: 10,
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
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendStatRow(
                  color: const Color(0xFF26D7FF),
                  label: 'Normal',
                  value: '$normalPct%',
                ),
                const SizedBox(height: 10),
                _LegendStatRow(
                  color: const Color(0xFFFF4D4F),
                  label: 'Abnormal',
                  value: '${100 - normalPct}%',
                ),
                const SizedBox(height: 10),
                _LegendStatRow(
                  color: snapshot.healthColor,
                  label: 'Status',
                  value: snapshot.healthLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceHealthBarsCard extends StatelessWidget {
  const _DeviceHealthBarsCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      'UPS': 0,
      'Smoke': 0,
      'T&H': 0,
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
        counts['T&H'] = (counts['T&H'] ?? 0) + 1;
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
      counts['T&H'] = snapshot.temperatures.length;
      counts['Power'] = snapshot.powerInletRows.isNotEmpty ? 1 : 0;
      counts['AC'] = snapshot.acMetricRows.isNotEmpty ? 1 : 0;
      counts['PDU'] =
          (snapshot.powerPdu1MetricRows.isNotEmpty ? 1 : 0) +
              (snapshot.powerPdu2MetricRows.isNotEmpty ? 1 : 0);
      counts['Door'] = snapshot.doors.length;
    }

    final maxVal = math.max(1, counts.values.fold<int>(0, math.max));
    final abnormalCount = snapshot.issueCount;
    final healthyCount = math.max(0, snapshot.totalDevices - abnormalCount);

    return _NocPanel(
      title: 'Device Health',
      child: Column(
        children: [
          Row(
            children: [
              _MiniMetricBadge(
                icon: Icons.favorite_rounded,
                color: const Color(0xFF26D7FF),
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 22),
                    child: CustomPaint(
                      painter: _BarChartGridPainter(
                        steps: math.min(4, maxVal),
                        columnCount: counts.length,
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
                            color: const Color(0xFF9AC5E8),
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
                                width: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
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
                            color: const Color(0xFF8FA7C4),
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

class _AlarmStatisticsCard extends StatelessWidget {
  const _AlarmStatisticsCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    int info = 0, minor = 0, major = 0, critical = 0;
    for (final a in snapshot.alarms) {
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
    final total = snapshot.alarms.length;
    final denom = math.max(1, total);

    return _NocPanel(
      title: 'Alarm Statistics',
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: SizedBox(
                width: 104,
                height: 104,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, anim, child) => CustomPaint(
                    painter: _RingChartPainter(
                      progress: anim,
                      segments: total == 0
                          ? const [
                              _RingSegment(
                                fraction: 1.0,
                                color: Color(0xFF24344D),
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Total',
                          style: ConsoleTheme.font(
                            color: const Color(0xFF8FA7C4),
                            fontSize: 10,
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
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendStatRow(
                    color: const Color(0xFF26D7FF),
                    label: 'Info',
                    value: '$info'),
                const SizedBox(height: 6),
                _LegendStatRow(
                    color: const Color(0xFF10B981),
                    label: 'Minor',
                    value: '$minor'),
                const SizedBox(height: 6),
                _LegendStatRow(
                    color: const Color(0xFFF59E0B),
                    label: 'Major',
                    value: '$major'),
                const SizedBox(height: 6),
                _LegendStatRow(
                    color: const Color(0xFFFF4D4F),
                    label: 'Critical',
                    value: '$critical'),
              ],
            ),
          ),
        ],
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

    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            icon: Icons.dns_rounded,
            accent: const Color(0xFF26D7FF),
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
            accent: snapshot.issueCount > 0
                ? const Color(0xFFFF4D4F)
                : const Color(0xFF10B981),
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

    return _NocPanel(
      title: 'Live Rack Topology',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final radius = (size * 0.36).clamp(70.0, 140.0);

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
              label: 'T&H',
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
              final spin = _spinController.value * 2 * math.pi;
              return SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                  CustomPaint(
                    size: Size(radius * 2.4, radius * 2.4),
                    painter: _TopologyRingPainter(
                      nodeCount: nodes.length,
                      rotationRadians: spin,
                    ),
                  ),
                  // Center PUE / Energy Core
                  Container(
                    width: radius * 1.08,
                    height: radius * 1.08,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1E90FF).withValues(alpha: 0.28),
                          const Color(0xFF0C1524),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF26D7FF).withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF26D7FF).withValues(alpha: 0.18),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'PUE',
                          style: ConsoleTheme.font(
                            color: const Color(0xFF8FA7C4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          pueText,
                          style: ConsoleTheme.font(
                            color: const Color(0xFF26D7FF),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          energyText,
                          style: ConsoleTheme.font(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Orbiting Subsystem Nodes
                  ...List.generate(nodes.length, (i) {
                    final angle =
                        (2 * math.pi * i / nodes.length) - math.pi / 2 + spin;
                    final dx = math.cos(angle) * radius * 1.15;
                    final dy = math.sin(angle) * radius * 0.95;
                    final node = nodes[i];
                    final color = node.ok
                        ? const Color(0xFF26D7FF)
                        : const Color(0xFFFF4D4F);
                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1828),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: color.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.15),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(node.icon, size: 15, color: color),
                            const SizedBox(width: 6),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node.label,
                                  style: ConsoleTheme.font(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  node.value,
                                  style: ConsoleTheme.font(
                                    color: color,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
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
                      color: const Color(0xFF8FA7C4),
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
                color: Colors.white.withValues(alpha: 0.06),
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
                            color: Colors.white,
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
                            color: const Color(0xFF8FA7C4),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: ConsoleTheme.font(
                          color: const Color(0xFF6B829E),
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

class _TempHumidityComparisonCard extends StatelessWidget {
  const _TempHumidityComparisonCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
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

    return _NocPanel(
      title: 'Temperature & Humidity',
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SmallDotLabel(color: Color(0xFFF59E0B), label: 'Temp'),
          SizedBox(width: 8),
          _SmallDotLabel(color: Color(0xFF26D7FF), label: 'Humidity'),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: rows.map((r) {
          final tempFrac = (r.temp / 50.0).clamp(0.05, 1.0);
          final humFrac = (r.hum / 100.0).clamp(0.05, 1.0);
          return Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  r.label,
                  style: ConsoleTheme.font(
                    color: const Color(0xFF8FA7C4),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
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
                        borderRadius:
                            BorderRadius.horizontal(left: Radius.circular(4)),
                        gradient: LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFFF8A00)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
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
                        borderRadius:
                            BorderRadius.horizontal(right: Radius.circular(4)),
                        gradient: LinearGradient(
                          colors: [Color(0xFF18D2C3), Color(0xFF26D7FF)],
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
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SmokeAndLeakCard extends StatelessWidget {
  const _SmokeAndLeakCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final smokeOk = snapshot.smokeStatus != 1;
    final leakOk = snapshot.floodStatus != 1;

    return _NocPanel(
      title: 'Smoke & Water-leak',
      child: Row(
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
      ),
    );
  }
}

class _DoorsAndCapacityCard extends StatelessWidget {
  const _DoorsAndCapacityCard({required this.snapshot});

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cap = snapshot.capacityUsedPct ?? 0.0;
    return _NocPanel(
      title: 'Space Capacity & Doors',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Text(
                'Overall Capacity',
                style: ConsoleTheme.font(
                  color: const Color(0xFF8FA7C4),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${cap.toStringAsFixed(1)}%',
                style: ConsoleTheme.font(
                  color: const Color(0xFF26D7FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: (cap / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) => LinearProgressIndicator(
                value: val,
                minHeight: 8,
                backgroundColor: const Color(0xFF1A283D),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF26D7FF)),
              ),
            ),
          ),
          const Divider(height: 8, color: Color(0xFF1B2B42)),
          Row(
            children: (snapshot.doors.isEmpty
                    ? const [
                        {'name': 'Front Door', 'isOpen': false},
                        {'name': 'Back Door', 'isOpen': false},
                      ]
                    : snapshot.doors.take(2).toList())
                .map((d) {
              final isOpen = d['isOpen'] == true;
              final name = (d['accessName'] ?? d['name'] ?? 'Door').toString();
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1726),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isOpen
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981))
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOpen
                            ? Icons.sensor_door_outlined
                            : Icons.lock_outline_rounded,
                        size: 16,
                        color: isOpen
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          style: ConsoleTheme.font(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1422).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF26D7FF).withValues(alpha: 0.24),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E90FF).withValues(alpha: 0.06),
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
                  color: const Color(0xFF26D7FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: ConsoleTheme.font(
                    color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1422).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
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
                    color: const Color(0xFF8FA7C4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
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
                    Expanded(
                      child: Text(
                        subLabel,
                        style: ConsoleTheme.font(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
    final color = ok ? const Color(0xFF26D7FF) : const Color(0xFFFF4D4F);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1828),
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
              color: const Color(0xFF8FA7C4),
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
        Expanded(
          child: Text(
            label,
            style: ConsoleTheme.font(
              color: const Color(0xFF8FA7C4),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: ConsoleTheme.font(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
            color: const Color(0xFF8FA7C4),
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
            color: const Color(0xFF8FA7C4),
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
  });

  final List<_RingSegment> segments;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) / 2) - 8;
    const stroke = 11.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF16243A)
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
    required this.nodeCount,
    required this.rotationRadians,
  });

  final int nodeCount;
  final double rotationRadians;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = math.min(size.width, size.height) / 2;

    final ringPaint = Paint()
      ..color = const Color(0xFF26D7FF).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, outerRadius * 0.72, ringPaint);
    canvas.drawCircle(center, outerRadius * 0.92, ringPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF1E90FF).withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    for (var i = 0; i < nodeCount; i++) {
      final angle =
          (2 * math.pi * i / nodeCount) - math.pi / 2 + rotationRadians;
      final end = Offset(
        center.dx + math.cos(angle) * outerRadius * 0.92,
        center.dy + math.sin(angle) * outerRadius * 0.85,
      );
      canvas.drawLine(center, end, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyRingPainter oldDelegate) =>
      oldDelegate.nodeCount != nodeCount ||
      oldDelegate.rotationRadians != rotationRadians;
}

class _BarChartGridPainter extends CustomPainter {
  const _BarChartGridPainter({
    required this.steps,
    required this.columnCount,
  });

  final int steps;
  final int columnCount;

  @override
  void paint(Canvas canvas, Size size) {
    final hPaint = Paint()
      ..color = const Color(0xFF26D7FF).withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final vPaint = Paint()
      ..color = const Color(0xFF1E90FF).withValues(alpha: 0.08)
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
      oldDelegate.steps != steps || oldDelegate.columnCount != columnCount;
}

class _NocGridBackdropPainter extends CustomPainter {
  const _NocGridBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E90FF).withValues(alpha: 0.045)
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
