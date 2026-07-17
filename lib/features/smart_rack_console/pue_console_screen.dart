import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/network/adapter_api_service.dart';
import '../../../core/network/cpanel_api_service.dart';
import '../dashboard/widgets/environment_gauges.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'services/rack_console_preferences.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/pue_charts.dart';

Widget _buildPueLegendItem(BuildContext context, String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 2, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          color: ConsoleTheme.textSecondary(context),
          fontSize: 12,
        ),
      ),
    ],
  );
}

int _currentSiteId() {
  final site = CpanelApiService.instance.currentSite;
  return site != null
      ? (int.tryParse(site['site_id']?.toString() ?? '') ??
          int.tryParse(site['id']?.toString() ?? '1') ??
          1)
      : 1;
}

double _readDouble(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
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

List<String> _titlesFromTrend(List<dynamic> points, {bool useMonth = false}) {
  final titles = <String>[];
  for (final raw in points) {
    if (raw is! Map) continue;
    final point = Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
    if (useMonth) {
      titles.add((point['monthStr'] ?? '').toString());
      continue;
    }
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

class PueConsoleScreen extends StatelessWidget {
  const PueConsoleScreen({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final SmartRackConsoleSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = compact || width < 800;

    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: ConsoleTheme.pageBgGradient(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  return AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCustomTab(
                              context,
                              tabController,
                              0,
                              'Current Energy Consumption',
                            ),
                            const SizedBox(width: 16),
                            _buildCustomTab(
                              context,
                              tabController,
                              1,
                              'Historical Energy Consumption',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildCurrentTab(context, isNarrow),
                  _buildHistoricalTab(context, isNarrow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTab(
    BuildContext context,
    TabController controller,
    int index,
    String text,
  ) {
    final isSelected = controller.index == index;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ConsoleTheme.primaryBlue(context)
              .withValues(alpha: isSelected ? 1.0 : 0.5),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color:
                      ConsoleTheme.primaryBlue(context).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: isSelected
            ? ConsoleTheme.primaryBlue(context)
            : ConsoleTheme.primaryBlue(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(19),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => controller.animateTo(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : ConsoleTheme.textSecondary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab(BuildContext context, bool isNarrow) {
    final q1 = _buildCurrentPueQuadrant(context);
    const q2 = EightHoursQuadrant();
    const q3 = EnergyQuadrant(
      title: 'Current Energy Consumption Statistics',
      powerType: 0,
    );
    const q4 = EnergyQuadrant(
      title: 'Total For The Month Statistics',
      powerType: 1,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ConsoleTheme.sm),
      child: isNarrow
          ? Column(
              children: [
                q1,
                const SizedBox(height: ConsoleTheme.lg),
                q2,
                const SizedBox(height: ConsoleTheme.lg),
                q3,
                const SizedBox(height: ConsoleTheme.lg),
                q4,
              ],
            )
          : Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: q1),
                      const SizedBox(width: ConsoleTheme.lg),
                      const Expanded(child: q2),
                    ],
                  ),
                ),
                const SizedBox(height: ConsoleTheme.lg),
                const IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: q3),
                      SizedBox(width: ConsoleTheme.lg),
                      Expanded(child: q4),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHistoricalTab(BuildContext context, bool isNarrow) {
    const top = HistoricalTrendAnalysisQuadrant();
    const bottomLeft = AnnualOperationQuadrant();
    const bottomRight = AnnualPueTrendQuadrant();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ConsoleTheme.sm),
      child: Column(
        children: [
          top,
          const SizedBox(height: ConsoleTheme.lg),
          isNarrow
              ? const Column(
                  children: [
                    bottomLeft,
                    SizedBox(height: ConsoleTheme.lg),
                    bottomRight,
                  ],
                )
              : const IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: bottomLeft),
                      SizedBox(width: ConsoleTheme.lg),
                      Expanded(child: bottomRight),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Color _getPueColor(double pue) {
    if (pue <= 0) return const Color(0xFF8A94A6);
    if (pue <= 1.2) return const Color(0xFF00A174);
    if (pue < 2.0) return const Color(0xFFFF8A00);
    return const Color(0xFFFF3B30);
  }

  Widget _buildCurrentPueQuadrant(BuildContext context) {
    final pueValue = snapshot.pue;
    final pueColor = _getPueColor(pueValue ?? 0);

    return ConsoleSectionCard(
      title: 'Current PUE',
      minHeight: 350,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ArcGauge(
                    progress: pueValue == null
                        ? 0
                        : ((pueValue - 1.0) / (3.0 - 1.0)).clamp(0.0, 1.0),
                    glowColor: pueColor,
                    baseColor: ConsoleTheme.isDark(context)
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFC0D3EB),
                    strokeWidth: 16.0,
                    sweepDegrees: 255,
                    startDegrees: 145,
                    glowIntensity: ConsoleTheme.isRackConsoleLite ? 0.18 : 1.0,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        pueValue?.toStringAsFixed(2) ?? '--',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: ConsoleTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        'PUE',
                        style: TextStyle(
                          fontSize: 14,
                          color: pueColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 16,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Total Energy Consumption Of The Month',
                    style: TextStyle(
                      color: ConsoleTheme.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const TotalMonthEnergyText(),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'kW·h',
                        style: TextStyle(
                          color: ConsoleTheme.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PuePillToggle extends StatelessWidget {
  const PuePillToggle({
    super.key,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? ConsoleTheme.primaryBlue(context)
                  : ConsoleTheme.textSecondary(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive
                  ? ConsoleTheme.primaryBlue(context)
                  : ConsoleTheme.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class EightHoursQuadrant extends StatefulWidget {
  const EightHoursQuadrant({super.key});

  @override
  State<EightHoursQuadrant> createState() => _EightHoursQuadrantState();
}

class _EightHoursQuadrantState extends State<EightHoursQuadrant> {
  String _selectedMetric = 'PUE';
  bool _isLoading = true;
  String? _error;
  List<FlSpot> _puePoints = [];
  List<FlSpot> _itEnergyPoints = [];
  List<FlSpot> _totalEnergyPoints = [];
  List<String> _bottomTitles = [];
  List<dynamic> _trendTitleSource = const [];

  void _handleTimeFormatChange() {
    if (!mounted) return;
    setState(() {
      _bottomTitles = _titlesFromTrend(_trendTitleSource);
    });
  }

  @override
  void initState() {
    super.initState();
    RackConsolePreferences.instance.addListener(_handleTimeFormatChange);
    _fetchData();
  }

  @override
  void dispose() {
    RackConsolePreferences.instance.removeListener(_handleTimeFormatChange);
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final siteId = _currentSiteId();
      final pueRes = await AdapterApiService.instance.fetchPueRangeTrend(
        siteId: siteId,
        trendType: 0,
        startTime:
            DateTime.now().subtract(const Duration(hours: 8)).millisecondsSinceEpoch,
        endTime: DateTime.now().millisecondsSinceEpoch,
      );
      final itRes = await AdapterApiService.instance.fetchPueRangeTrend(
        siteId: siteId,
        trendType: 2,
        startTime:
            DateTime.now().subtract(const Duration(hours: 8)).millisecondsSinceEpoch,
        endTime: DateTime.now().millisecondsSinceEpoch,
      );
      final totalRes = await AdapterApiService.instance.fetchPueRangeTrend(
        siteId: siteId,
        trendType: 1,
        startTime:
            DateTime.now().subtract(const Duration(hours: 8)).millisecondsSinceEpoch,
        endTime: DateTime.now().millisecondsSinceEpoch,
      );

      final puePoints = _spotsFromTrend((pueRes?['result'] as List?) ?? const []);
      final itPoints = _spotsFromTrend((itRes?['result'] as List?) ?? const []);
      final totalPoints =
          _spotsFromTrend((totalRes?['result'] as List?) ?? const []);

      if (!mounted) return;
      final trendTitleSource = (pueRes?['result'] as List?) ??
          (itRes?['result'] as List?) ??
          (totalRes?['result'] as List?) ??
          const [];
      setState(() {
        _puePoints = puePoints;
        _itEnergyPoints = itPoints;
        _totalEnergyPoints = totalPoints;
        _trendTitleSource = List<dynamic>.from(trendTitleSource);
        _bottomTitles = _titlesFromTrend(_trendTitleSource);
        _error = (puePoints.isEmpty && itPoints.isEmpty && totalPoints.isEmpty)
            ? 'No adapter trend data returned.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load adapter trend data.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleSectionCard(
      title: '8 Hours',
      trailing: Row(
        children: [
          PuePillToggle(
            label: 'PUE',
            isActive: _selectedMetric == 'PUE',
            onTap: () => setState(() => _selectedMetric = 'PUE'),
          ),
          const SizedBox(width: 8),
          PuePillToggle(
            label: 'IT Energy',
            isActive: _selectedMetric == 'IT Energy',
            onTap: () => setState(() => _selectedMetric = 'IT Energy'),
          ),
          const SizedBox(width: 8),
          PuePillToggle(
            label: 'Total Energy',
            isActive: _selectedMetric == 'Total Energy',
            onTap: () => setState(() => _selectedMetric = 'Total Energy'),
          ),
        ],
      ),
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, right: 16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : PueTrendLineChart(
                      puePoints: _selectedMetric == 'PUE'
                          ? _puePoints
                          : const [FlSpot(0, 0)],
                      itEnergyPoints: _selectedMetric == 'IT Energy'
                          ? _itEnergyPoints
                          : const [FlSpot(0, 0)],
                      totalEnergyPoints: _selectedMetric == 'Total Energy'
                          ? _totalEnergyPoints
                          : const [FlSpot(0, 0)],
                      bottomTitles: _bottomTitles,
                    ),
        ),
      ),
    );
  }
}

class EnergyQuadrant extends StatefulWidget {
  const EnergyQuadrant({
    super.key,
    required this.title,
    required this.powerType,
  });

  final String title;
  final int powerType;

  @override
  State<EnergyQuadrant> createState() => _EnergyQuadrantState();
}

class _EnergyQuadrantState extends State<EnergyQuadrant> {
  bool _isLoading = true;
  String? _error;
  List<double> _values = [];
  final List<String> _labels = const [
    'Total',
    'IT Device',
    'Aircon',
    'Power',
    'Lighting',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = widget.powerType == 0
          ? await AdapterApiService.instance.fetchPowerToday(
              siteId: _currentSiteId(),
            )
          : await AdapterApiService.instance.fetchPowerMonth(
              siteId: _currentSiteId(),
            );
      final result = (data?['result'] as Map?)?.cast<String, dynamic>() ??
          (data?['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final values = [
        _readDouble(result, const ['Total', 'total']),
        _readDouble(result, const ['IT Device', 'itDevice']),
        _readDouble(result, const ['Aircon', 'aircon']),
        _readDouble(result, const ['Power', 'power']),
        _readDouble(result, const ['Lighting', 'lighting']),
        _readDouble(result, const ['Other', 'other']),
      ];

      if (!mounted) return;
      setState(() {
        _values = values;
        _error = values.every((v) => v == 0)
            ? 'No adapter energy data returned.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load adapter energy data.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleSectionCard(
      title: widget.title,
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  'Unit: (kW·h)',
                  style: TextStyle(
                    color: ConsoleTheme.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : PueConsumptionBarChart(
                            values: _values,
                            labels: _labels,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TotalMonthEnergyText extends StatefulWidget {
  const TotalMonthEnergyText({super.key});

  @override
  State<TotalMonthEnergyText> createState() => _TotalMonthEnergyTextState();
}

class _TotalMonthEnergyTextState extends State<TotalMonthEnergyText> {
  String _totalText = '--';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await AdapterApiService.instance.fetchPowerMonth(
        siteId: _currentSiteId(),
      );
      final result = (data?['result'] as Map?)?.cast<String, dynamic>() ??
          (data?['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final total = _readDouble(result, const ['Total', 'total']);
      if (!mounted) return;
      setState(() {
        _totalText = total > 0 ? total.toStringAsFixed(2) : '--';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _totalText,
      style: TextStyle(
        color: ConsoleTheme.cyan(context),
        fontSize: 32,
        fontWeight: FontWeight.bold,
        shadows: ConsoleTheme.isRackConsoleLite
            ? const []
            : [
                Shadow(
                  color: ConsoleTheme.cyan(context).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
      ),
    );
  }
}

class HistoricalTrendAnalysisQuadrant extends StatefulWidget {
  const HistoricalTrendAnalysisQuadrant({super.key});

  @override
  State<HistoricalTrendAnalysisQuadrant> createState() =>
      _HistoricalTrendAnalysisQuadrantState();
}

class _HistoricalTrendAnalysisQuadrantState
    extends State<HistoricalTrendAnalysisQuadrant> {
  String _selectedMetric = 'PUE';
  String _selectedHours = '8 Hours';
  bool _isLoading = true;
  String? _error;
  List<FlSpot> _puePoints = [];
  List<FlSpot> _powerPoints = [];
  List<String> _bottomTitles = [];
  List<dynamic> _trendTitleSource = const [];

  void _handleTimeFormatChange() {
    if (!mounted) return;
    setState(() {
      _bottomTitles = _titlesFromTrend(_trendTitleSource);
    });
  }

  @override
  void initState() {
    super.initState();
    RackConsolePreferences.instance.addListener(_handleTimeFormatChange);
    _fetchData();
  }

  @override
  void dispose() {
    RackConsolePreferences.instance.removeListener(_handleTimeFormatChange);
    super.dispose();
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

      final puePoints = _spotsFromTrend((pueRes?['result'] as List?) ?? const []);
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
            ? 'No adapter trend data returned.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load adapter trend data.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Trend Analysis',
      trailing: Row(
        children: [
          PopupMenuButton<String>(
            initialValue: _selectedHours,
            onSelected: (val) {
              setState(() => _selectedHours = val);
              _fetchData();
            },
            offset: const Offset(0, 32),
            itemBuilder: (context) => const [
              '8 Hours',
              '12 Hours',
              '24 Hours',
              'Last Month',
            ].map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: ConsoleTheme.textSecondary(context)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedHours,
                    style: TextStyle(
                      color: ConsoleTheme.textPrimary(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: ConsoleTheme.textPrimary(context),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          PuePillToggle(
            label: 'PUE',
            isActive: _selectedMetric == 'PUE',
            onTap: () => setState(() => _selectedMetric = 'PUE'),
          ),
          const SizedBox(width: 8),
          PuePillToggle(
            label: 'Power Consumption',
            isActive: _selectedMetric == 'Power Consumption',
            onTap: () => setState(() => _selectedMetric = 'Power Consumption'),
          ),
        ],
      ),
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, right: 16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : PueTrendLineChart(
                      puePoints: _selectedMetric == 'PUE'
                          ? _puePoints
                          : const [FlSpot(0, 0)],
                      itEnergyPoints: const [FlSpot(0, 0)],
                      totalEnergyPoints:
                          _selectedMetric == 'Power Consumption'
                              ? _powerPoints
                              : const [FlSpot(0, 0)],
                      bottomTitles: _bottomTitles,
                    ),
        ),
      ),
    );
  }
}

class AnnualOperationQuadrant extends StatefulWidget {
  const AnnualOperationQuadrant({super.key});

  @override
  State<AnnualOperationQuadrant> createState() =>
      _AnnualOperationQuadrantState();
}

class _AnnualOperationQuadrantState extends State<AnnualOperationQuadrant> {
  String _selectedMetric = 'PUE';
  bool _isLoading = true;
  String? _error;
  int _currentYear = DateTime.now().year;
  int _prevYear = DateTime.now().year - 1;
  List<FlSpot> _currentPoints = [];
  List<FlSpot> _prevPoints = [];
  final List<String> _bottomTitles = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trendType = _selectedMetric == 'PUE'
          ? 0
          : _selectedMetric == 'IT Energy'
              ? 2
              : 1;
      final data = await AdapterApiService.instance.fetchYearTrendForCabinet(
        siteId: _currentSiteId(),
        trendType: trendType,
      );
      final result = (data?['result'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final current = _spotsFromTrend((result['current'] as List?) ?? const []);
      final prev = _spotsFromTrend((result['prev'] as List?) ?? const []);

      if (!mounted) return;
      setState(() {
        _currentPoints = current;
        _prevPoints = prev;
        _currentYear =
            int.tryParse(result['currentYear']?.toString() ?? '') ??
                DateTime.now().year;
        _prevYear =
            int.tryParse(result['prevYear']?.toString() ?? '') ??
                DateTime.now().year - 1;
        _error = (current.isEmpty && prev.isEmpty)
            ? 'No annual trend data returned.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load annual trend data.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Annual Operation Trend',
      trailing: Row(
        children: [
          PuePillToggle(
            label: 'PUE',
            isActive: _selectedMetric == 'PUE',
            onTap: () {
              setState(() => _selectedMetric = 'PUE');
              _fetchData();
            },
          ),
          const SizedBox(width: 8),
          PuePillToggle(
            label: 'IT Energy',
            isActive: _selectedMetric == 'IT Energy',
            onTap: () {
              setState(() => _selectedMetric = 'IT Energy');
              _fetchData();
            },
          ),
          const SizedBox(width: 8),
          PuePillToggle(
            label: 'Total Energy',
            isActive: _selectedMetric == 'Total Energy',
            onTap: () {
              setState(() => _selectedMetric = 'Total Energy');
              _fetchData();
            },
          ),
        ],
      ),
      child: SizedBox(
        height: 420,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, right: 16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildPueLegendItem(
                              context,
                              '$_prevYear',
                              const Color(0xFFF97316),
                            ),
                            const SizedBox(width: 16),
                            _buildPueLegendItem(
                              context,
                              '$_currentYear',
                              ConsoleTheme.cyan(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: PueTrendLineChart(
                            puePoints: _currentPoints,
                            itEnergyPoints: _prevPoints,
                            totalEnergyPoints: const [FlSpot(0, 0)],
                            bottomTitles: _bottomTitles,
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 36,
                            columnSpacing: 24,
                            horizontalMargin: 16,
                            headingRowColor: WidgetStateProperty.all(
                              ConsoleTheme.primaryBlue(context)
                                  .withValues(alpha: 0.2),
                            ),
                            headingTextStyle: TextStyle(
                              color: ConsoleTheme.textSecondary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            dataTextStyle: TextStyle(
                              color: ConsoleTheme.textPrimary(context),
                              fontSize: 11,
                            ),
                            dividerThickness: 0.5,
                            columns: [
                              const DataColumn(label: Text('Year')),
                              ..._bottomTitles
                                  .map((c) => DataColumn(label: Text(c))),
                            ],
                            rows: [
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '$_prevYear',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ..._bottomTitles.asMap().entries.map(
                                        (entry) => DataCell(
                                          Text(
                                            entry.key < _prevPoints.length
                                                ? _prevPoints[entry.key]
                                                    .y
                                                    .toStringAsFixed(2)
                                                : '-',
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '$_currentYear',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ..._bottomTitles.asMap().entries.map(
                                        (entry) => DataCell(
                                          Text(
                                            entry.key < _currentPoints.length
                                                ? _currentPoints[entry.key]
                                                    .y
                                                    .toStringAsFixed(2)
                                                : '-',
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class AnnualPueTrendQuadrant extends StatefulWidget {
  const AnnualPueTrendQuadrant({super.key});

  @override
  State<AnnualPueTrendQuadrant> createState() =>
      _AnnualPueTrendQuadrantState();
}

class _AnnualPueTrendQuadrantState extends State<AnnualPueTrendQuadrant> {
  bool _isLoading = true;
  String? _error;
  List<FlSpot> _puePoints = [];
  List<FlSpot> _lowBaseline = [];
  List<FlSpot> _bestBaseline = [];
  final List<String> _bottomTitles = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data =
          await AdapterApiService.instance.fetchYearPueTrendForCabinet(
        siteId: _currentSiteId(),
      );
      final result = (data?['result'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final pue = _spotsFromTrend((result['pue'] as List?) ?? const []);
      final low = _spotsFromTrend((result['low'] as List?) ?? const []);
      final best = _spotsFromTrend((result['best'] as List?) ?? const []);

      if (!mounted) return;
      setState(() {
        _puePoints = pue;
        _lowBaseline = low;
        _bestBaseline = best;
        _error = (pue.isEmpty && low.isEmpty && best.isEmpty)
            ? 'No annual PUE data returned.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load annual PUE data.';
        _isLoading = false;
      });
    }
  }

  List<DataRow> _buildAnnualRows() {
    List<String> seriesCells(List<FlSpot> points) {
      return List<String>.generate(_bottomTitles.length, (index) {
        return index < points.length ? points[index].y.toStringAsFixed(2) : '-';
      });
    }

    final pueCells = seriesCells(_puePoints);
    final lowCells = seriesCells(_lowBaseline);
    final runCells = List<String>.filled(
      _bottomTitles.length,
      '1.50',
      growable: false,
    );
    final bestCells = seriesCells(_bestBaseline);

    DataRow rowFrom(String label, List<String> values, {bool bold = false}) {
      return DataRow(
        cells: [
          DataCell(
            Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          ...values.map(
            (value) => DataCell(Text(value)),
          ),
        ],
      );
    }

    return [
      rowFrom('PUE', pueCells, bold: true),
      rowFrom('Lower Baseline', lowCells),
      rowFrom('Run Baseline', runCells),
      rowFrom('Best Baseline', bestCells),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Annual PUE Trend',
      trailing: Row(
        children: [
          _buildPueLegendItem(
            context,
            'Lower Baseline',
            ConsoleTheme.cyan(context),
          ),
          const SizedBox(width: 8),
          _buildPueLegendItem(
            context,
            'Run Baseline',
            ConsoleTheme.primaryBlue(context),
          ),
          const SizedBox(width: 8),
          _buildPueLegendItem(
            context,
            'Best Baseline',
            const Color(0xFFF59E0B),
          ),
        ],
      ),
      child: SizedBox(
        height: 560,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, right: 16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: PueTrendLineChart(
                            puePoints: _puePoints,
                            itEnergyPoints: _lowBaseline,
                            totalEnergyPoints: _bestBaseline,
                            bottomTitles: _bottomTitles,
                            baselines: [
                              HorizontalLine(
                                y: _lowBaseline.isNotEmpty
                                    ? _lowBaseline.first.y
                                    : 1,
                                color: ConsoleTheme.cyan(context),
                                strokeWidth: 2,
                              ),
                              HorizontalLine(
                                y: 1.5,
                                color: ConsoleTheme.primaryBlue(context),
                                strokeWidth: 2,
                              ),
                              HorizontalLine(
                                y: _bestBaseline.isNotEmpty
                                    ? _bestBaseline.first.y
                                    : 1.2,
                                color: const Color(0xFFF59E0B),
                                strokeWidth: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 34,
                            dataRowMaxHeight: 34,
                            columnSpacing: 20,
                            horizontalMargin: 16,
                            headingRowColor: WidgetStateProperty.all(
                              ConsoleTheme.primaryBlue(context)
                                  .withValues(alpha: 0.2),
                            ),
                            headingTextStyle: TextStyle(
                              color: ConsoleTheme.textSecondary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            dataTextStyle: TextStyle(
                              color: ConsoleTheme.textPrimary(context),
                              fontSize: 11,
                            ),
                            dividerThickness: 0.5,
                            columns: [
                              const DataColumn(label: Text('Series')),
                              ..._bottomTitles
                                  .map((c) => DataColumn(label: Text(c))),
                            ],
                            rows: _buildAnnualRows(),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
