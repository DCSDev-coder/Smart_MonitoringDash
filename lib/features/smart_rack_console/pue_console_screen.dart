import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../dashboard/widgets/environment_gauges.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/pue_charts.dart';
import '../../../core/network/adapter_api_service.dart';
import '../../../core/network/cpanel_api_service.dart';

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
    final double width = MediaQuery.of(context).size.width;
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
                    builder: (context, child) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCustomTab(context, tabController, 0, 'Current Energy Consumption'),
                            const SizedBox(width: 16),
                            _buildCustomTab(context, tabController, 1, 'Historical Energy Consumption'),
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

  Widget _buildCustomTab(BuildContext context, TabController controller, int index, String text) {
    final bool isSelected = controller.index == index;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ConsoleTheme.primaryBlue(context).withValues(alpha: isSelected ? 1.0 : 0.5),
          width: 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: isSelected 
            ? ConsoleTheme.primaryBlue(context)
            : ConsoleTheme.primaryBlue(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(19), // Slightly smaller than 20 to fit inside border cleanly
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            controller.animateTo(index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : ConsoleTheme.textSecondary(context),
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
    const q3 = CurrentEnergyQuadrant();
    final q4 = _buildTotalMonthStatisticsQuadrant(context);

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: q1),
                    const SizedBox(width: ConsoleTheme.lg),
                    Expanded(child: q2),
                  ],
                ),
                const SizedBox(height: ConsoleTheme.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: q3),
                    const SizedBox(width: ConsoleTheme.lg),
                    Expanded(child: q4),
                  ],
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
              ? Column(
                  children: [
                    bottomLeft,
                    const SizedBox(height: ConsoleTheme.lg),
                    bottomRight,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: bottomLeft),
                    const SizedBox(width: ConsoleTheme.lg),
                    Expanded(child: bottomRight),
                  ],
                ),
        ],
      ),
    );
  }



  Widget _buildCurrentPueQuadrant(BuildContext context) {
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
                  progress: (2.25 - 1.0) / (3.0 - 1.0),
                  glowColor: ConsoleTheme.cyan(context),
                  baseColor: ConsoleTheme.isDark(context) ? const Color(0xFF3A3A3A) : const Color(0xFFC0D3EB),
                  strokeWidth: 16.0,
                  sweepDegrees: 210,
                  startDegrees: 195,
                  glowIntensity: 1.0,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      '2.25',
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
                        color: ConsoleTheme.cyan(context),
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
                padding: const EdgeInsets.only(bottom: 6.0),
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
                  Text(
                    '850.72',
                    style: TextStyle(
                      color: ConsoleTheme.cyan(context),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: ConsoleTheme.cyan(context).withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
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

  Widget _buildTotalMonthStatisticsQuadrant(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Total For The Month Statistics',
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
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
                child: PueConsumptionBarChart(
                  values: const [1420.25, 594.79, 0, 0, 0, 824.25],
                  labels: const ['Total', 'IT Device', 'Aircon', 'Power', 'Lighting', 'Other'],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String label, List<String> values, [double labelWidth = 30]) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                color: ConsoleTheme.textPrimary(context),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...values.map((v) => Expanded(
            child: Center(
              child: Text(
                v,
                style: TextStyle(
                  color: ConsoleTheme.textPrimary(context),
                  fontSize: 10,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: ConsoleTheme.textPrimary(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

}

class PuePillToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const PuePillToggle({
    super.key,
    required this.label,
    required this.isActive,
    this.onTap,
  });

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
            color: isActive ? ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? ConsoleTheme.primaryBlue(context) : ConsoleTheme.textSecondary(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? ConsoleTheme.primaryBlue(context) : ConsoleTheme.textSecondary(context),
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
      final site = CpanelApiService.instance.currentSite;
      final siteIdStr = site?['id']?.toString() ?? '';
      final siteId = int.tryParse(siteIdStr) ?? 1;
      
      final data = await AdapterApiService.instance.fetchOurPueHourly(siteId: siteId, hours: 8);
      
      if (data == null || data['result'] == false) {
        _useMockData();
        return;
      }

      final points = data['data'] as List<dynamic>? ?? [];
      
      final List<FlSpot> pue = [];
      final List<FlSpot> it = [];
      final List<FlSpot> total = [];
      final List<String> titles = [];
      
      for (int i = 0; i < points.length; i++) {
        final pt = points[i] as Map<String, dynamic>;
        
        final double p = double.tryParse(pt['pue']?.toString() ?? '') ?? 0.0;
        final double itVal = double.tryParse(pt['itEnergy']?.toString() ?? pt['itPower']?.toString() ?? '') ?? 0.0;
        final double tVal = double.tryParse(pt['totalEnergy']?.toString() ?? pt['totalPower']?.toString() ?? '') ?? 0.0;
        final String time = pt['time']?.toString() ?? pt['timestamp']?.toString() ?? pt['date']?.toString() ?? '';
        
        pue.add(FlSpot(i.toDouble(), p));
        it.add(FlSpot(i.toDouble(), itVal));
        total.add(FlSpot(i.toDouble(), tVal));
        titles.add(time.length > 5 ? time.substring(time.length - 5) : time);
      }

      if (pue.isEmpty) {
        _useMockData();
        return;
      }

      setState(() {
        _puePoints = pue;
        _itEnergyPoints = it;
        _totalEnergyPoints = total;
        _bottomTitles = titles;
        _isLoading = false;
      });
    } catch (e) {
      _useMockData();
    }
  }

  void _useMockData() {
    setState(() {
      _puePoints = const [
        FlSpot(0, 5), FlSpot(1, 4), FlSpot(2, 6), FlSpot(3, 4), FlSpot(4, 8),
        FlSpot(5, 5), FlSpot(6, 4), FlSpot(7, 3), FlSpot(8, 5), FlSpot(9, 4),
      ];
      _itEnergyPoints = const [
        FlSpot(0, 1), FlSpot(1, 2), FlSpot(2, 1.5), FlSpot(3, 3), FlSpot(4, 2),
        FlSpot(5, 4), FlSpot(6, 2.5), FlSpot(7, 3), FlSpot(8, 1), FlSpot(9, 2),
      ];
      _totalEnergyPoints = const [
        FlSpot(0, 6), FlSpot(1, 6), FlSpot(2, 7.5), FlSpot(3, 7), FlSpot(4, 10),
        FlSpot(5, 9), FlSpot(6, 6.5), FlSpot(7, 6), FlSpot(8, 6), FlSpot(9, 6),
      ];
      _bottomTitles = const ['04:30', '05:30', '06:30', '07:30', '08:30', '09:30', '10:30', '11:30', '', ''];
      _error = null;
      _isLoading = false;
    });
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
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _error != null 
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : PueTrendLineChart(
                  puePoints: _selectedMetric == 'PUE' ? _puePoints : const [FlSpot(0, 0)],
                  itEnergyPoints: _selectedMetric == 'IT Energy' ? _itEnergyPoints : const [FlSpot(0, 0)],
                  totalEnergyPoints: _selectedMetric == 'Total Energy' ? _totalEnergyPoints : const [FlSpot(0, 0)],
                  bottomTitles: _bottomTitles,
                ),
        ),
      ),
    );
  }
}

class CurrentEnergyQuadrant extends StatefulWidget {
  const CurrentEnergyQuadrant({super.key});

  @override
  State<CurrentEnergyQuadrant> createState() => _CurrentEnergyQuadrantState();
}

class _CurrentEnergyQuadrantState extends State<CurrentEnergyQuadrant> {
  String _selectedTimeframe = 'Current';
  bool _isLoading = true;
  String? _error;
  
  List<double> _values = [];
  List<String> _labels = ['Total', 'IT Device', 'Aircon', 'Power', 'Lighting', 'Other'];

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
      final site = CpanelApiService.instance.currentSite;
      final siteIdStr = site?['id']?.toString() ?? '';
      final siteId = int.tryParse(siteIdStr) ?? 1; 
      
      final data = await AdapterApiService.instance.fetchPowerMonth(siteId: siteId); 
      
      if (data == null || data['result'] == false) {
        _useMockData();
        return;
      }

      final result = data['data'] ?? data['result'] ?? {};
      
      final double total = double.tryParse(result['total']?.toString() ?? '') ?? 0;
      final double it = double.tryParse(result['itDevice']?.toString() ?? '') ?? 0;
      final double aircon = double.tryParse(result['aircon']?.toString() ?? '') ?? 0;
      final double power = double.tryParse(result['power']?.toString() ?? '') ?? 0;
      final double lighting = double.tryParse(result['lighting']?.toString() ?? '') ?? 0;
      final double other = double.tryParse(result['other']?.toString() ?? '') ?? 0;
      
      final hasData = total > 0 || it > 0 || aircon > 0 || power > 0 || lighting > 0 || other > 0;
      
      if (!hasData) {
        _useMockData();
        return;
      }
      
      setState(() {
        _values = [total, it, aircon, power, lighting, other];
        _isLoading = false;
      });
    } catch (e) {
      _useMockData();
    }
  }

  void _useMockData() {
    setState(() {
      _values = const [220, 100, 220, 220, 160, 0];
      _error = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Current Energy Consumption Statistics',
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
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
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
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

class HistoricalTrendAnalysisQuadrant extends StatefulWidget {
  const HistoricalTrendAnalysisQuadrant({super.key});

  @override
  State<HistoricalTrendAnalysisQuadrant> createState() => _HistoricalTrendAnalysisQuadrantState();
}

class _HistoricalTrendAnalysisQuadrantState extends State<HistoricalTrendAnalysisQuadrant> {
  String _selectedMetric = 'PUE';
  String _selectedHours = '8 Hours';
  bool _isLoading = true;
  String? _error;
  
  List<FlSpot> _puePoints = [];
  List<FlSpot> _powerPoints = [];
  List<String> _bottomTitles = [];

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
      final site = CpanelApiService.instance.currentSite;
      final siteIdStr = site?['id']?.toString() ?? '';
      final siteId = int.tryParse(siteIdStr) ?? 1;
      
      int hours = 8;
      if (_selectedHours == '12 Hours') hours = 12;
      if (_selectedHours == '24 Hours') hours = 24;
      if (_selectedHours == 'Last Month') hours = 720;
      
      final data = await AdapterApiService.instance.fetchOurPueHourly(siteId: siteId, hours: hours);
      
      if (data == null || data['result'] == false) {
        _useMockData();
        return;
      }

      final points = data['data'] as List<dynamic>? ?? [];
      
      final List<FlSpot> pue = [];
      final List<FlSpot> power = [];
      final List<String> titles = [];
      
      for (int i = 0; i < points.length; i++) {
        final pt = points[i] as Map<String, dynamic>;
        
        final double p = double.tryParse(pt['pue']?.toString() ?? '') ?? 0.0;
        final double tVal = double.tryParse(pt['totalEnergy']?.toString() ?? pt['totalPower']?.toString() ?? '') ?? 0.0;
        final String time = pt['time']?.toString() ?? pt['timestamp']?.toString() ?? pt['date']?.toString() ?? '';
        
        pue.add(FlSpot(i.toDouble(), p));
        power.add(FlSpot(i.toDouble(), tVal));
        titles.add(time.length > 5 ? time.substring(time.length - 5) : time);
      }

      if (pue.isEmpty) {
        _useMockData();
        return;
      }

      setState(() {
        _puePoints = pue;
        _powerPoints = power;
        _bottomTitles = titles;
        _isLoading = false;
      });
    } catch (e) {
      _useMockData();
    }
  }

  void _useMockData() {
    int pointsCount = 10;
    if (_selectedHours == '12 Hours') pointsCount = 12;
    if (_selectedHours == '24 Hours') pointsCount = 24;
    if (_selectedHours == 'Last Month') pointsCount = 30;

    List<FlSpot> generatedPue = [];
    List<FlSpot> generatedPower = [];
    List<String> generatedTitles = [];

    for (int i = 0; i < pointsCount; i++) {
      // Create some nice looking dummy curves
      double pueVal = 4.0 + (i % 3) + (i % 2 == 0 ? 0.5 : -0.5);
      double powerVal = 6.0 + (i % 4) + (i % 2 == 0 ? 1.0 : -1.0);
      
      generatedPue.add(FlSpot(i.toDouble(), pueVal));
      generatedPower.add(FlSpot(i.toDouble(), powerVal));
      
      if (_selectedHours == 'Last Month') {
        generatedTitles.add('Day ${i + 1}');
      } else {
        generatedTitles.add('${(i + 2).toString().padLeft(2, '0')}:00');
      }
    }

    setState(() {
      _puePoints = generatedPue;
      _powerPoints = generatedPower;
      _bottomTitles = generatedTitles;
      _error = null;
      _isLoading = false;
    });
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
              setState(() {
                _selectedHours = val;
              });
              _fetchData();
            },
            offset: const Offset(0, 32),
            itemBuilder: (context) => [
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
                  Text(_selectedHours, style: TextStyle(color: ConsoleTheme.textPrimary(context), fontSize: 12)),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down, color: ConsoleTheme.textPrimary(context), size: 16),
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
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _error != null 
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : PueTrendLineChart(
                  puePoints: _selectedMetric == 'PUE' ? _puePoints : const [FlSpot(0, 0)],
                  itEnergyPoints: const [FlSpot(0, 0)],
                  totalEnergyPoints: _selectedMetric == 'Power Consumption' ? _powerPoints : const [FlSpot(0, 0)],
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
  State<AnnualOperationQuadrant> createState() => _AnnualOperationQuadrantState();
}

class _AnnualOperationQuadrantState extends State<AnnualOperationQuadrant> {
  String _selectedMetric = 'PUE';
  bool _isLoading = true;
  String? _error;

  List<FlSpot> _puePoints2026 = [];
  List<FlSpot> _itEnergyPoints2026 = [];
  List<FlSpot> _totalEnergyPoints2026 = [];
  List<FlSpot> _points2025 = [];
  List<String> _bottomTitles = [];

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
      final site = CpanelApiService.instance.currentSite;
      final siteIdStr = site?['id']?.toString() ?? '';
      final siteId = int.tryParse(siteIdStr) ?? 1;
      
      final data = await AdapterApiService.instance.fetchPue(siteId: siteId); 
      
      if (data == null || data['result'] == false) {
        _useMockData();
        return;
      }
      
      _useMockData(); 
    } catch (e) {
      _useMockData();
    }
  }

  void _useMockData() {
    setState(() {
      _puePoints2026 = const [
        FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), 
        FlSpot(4, 2.55), FlSpot(5, 2.48), FlSpot(6, 0), FlSpot(7, 0),
        FlSpot(8, 0), FlSpot(9, 0), FlSpot(10, 0), FlSpot(11, 0),
      ];
      _itEnergyPoints2026 = const [
        FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), 
        FlSpot(4, 1.2), FlSpot(5, 1.3), FlSpot(6, 0), FlSpot(7, 0),
        FlSpot(8, 0), FlSpot(9, 0), FlSpot(10, 0), FlSpot(11, 0),
      ];
      _totalEnergyPoints2026 = const [
        FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), 
        FlSpot(4, 3.1), FlSpot(5, 3.2), FlSpot(6, 0), FlSpot(7, 0),
        FlSpot(8, 0), FlSpot(9, 0), FlSpot(10, 0), FlSpot(11, 0),
      ];
      _points2025 = const [
        FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), 
        FlSpot(4, 0), FlSpot(5, 0), FlSpot(6, 0), FlSpot(7, 0),
        FlSpot(8, 0), FlSpot(9, 0), FlSpot(10, 0), FlSpot(11, 0),
      ];
      _bottomTitles = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      _error = null;
      _isLoading = false;
    });
  }
  
  Widget _buildNiceDataTable(BuildContext context, List<String> columns, List<String> rowLabels, List<List<String>> rowsData) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F2648).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ConsoleTheme.divider(context)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 36,
          columnSpacing: 24,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
          headingTextStyle: TextStyle(color: ConsoleTheme.textSecondary(context), fontSize: 11, fontWeight: FontWeight.bold),
          dataTextStyle: TextStyle(color: ConsoleTheme.textPrimary(context), fontSize: 11),
          dividerThickness: 0.5,
          columns: [
            const DataColumn(label: Text('Date')),
            ...columns.map((c) => DataColumn(label: Text(c))),
          ],
          rows: List.generate(rowLabels.length, (index) {
            return DataRow(
              cells: [
                DataCell(Text(rowLabels[index], style: const TextStyle(fontWeight: FontWeight.bold))),
                ...rowsData[index].map((val) => DataCell(Text(val))),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLegendItemLocal(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: ConsoleTheme.textSecondary(context), fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<FlSpot> active2026 = [];
    if (_selectedMetric == 'PUE') active2026 = _puePoints2026;
    if (_selectedMetric == 'IT Energy') active2026 = _itEnergyPoints2026;
    if (_selectedMetric == 'Total Energy') active2026 = _totalEnergyPoints2026;

    return ConsoleSectionCard(
      title: 'Annual Operation Trend',
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
        height: 420,
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildLegendItemLocal(context, '2025', const Color(0xFFF97316)),
                      const SizedBox(width: 16),
                      _buildLegendItemLocal(context, '2026', ConsoleTheme.cyan(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: PueTrendLineChart(
                      puePoints: active2026.isNotEmpty ? active2026 : const [FlSpot(0,0)],
                      itEnergyPoints: const [FlSpot(0, 0)],
                      totalEnergyPoints: _points2025.isNotEmpty ? _points2025 : const [FlSpot(0,0)],
                      bottomTitles: _bottomTitles,
                    ),
                  ),
                  _buildNiceDataTable(
                    context, 
                    _bottomTitles, 
                    ['2025', '2026'], 
                    [
                      _points2025.map((e) => e.y.toStringAsFixed(1)).toList(),
                      active2026.map((e) => e.y.toStringAsFixed(2)).toList(),
                    ],
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
  State<AnnualPueTrendQuadrant> createState() => _AnnualPueTrendQuadrantState();
}

class _AnnualPueTrendQuadrantState extends State<AnnualPueTrendQuadrant> {
  Widget _buildNiceDataTable(BuildContext context, List<String> columns, List<String> rowLabels, List<List<String>> rowsData) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F2648).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ConsoleTheme.divider(context)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 36,
          columnSpacing: 24,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
          headingTextStyle: TextStyle(color: ConsoleTheme.textSecondary(context), fontSize: 11, fontWeight: FontWeight.bold),
          dataTextStyle: TextStyle(color: ConsoleTheme.textPrimary(context), fontSize: 11),
          dividerThickness: 0.5,
          columns: [
            const DataColumn(label: Text('Date')),
            ...columns.map((c) => DataColumn(label: Text(c))),
          ],
          rows: List.generate(rowLabels.length, (index) {
            return DataRow(
              cells: [
                DataCell(Text(rowLabels[index], style: const TextStyle(fontWeight: FontWeight.bold))),
                ...rowsData[index].map((val) => DataCell(Text(val))),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLegendItemLocal(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: ConsoleTheme.textSecondary(context), fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Annual PUE Trend',
      trailing: Row(
        children: [
          _buildLegendItemLocal(context, 'Lower Baseline', ConsoleTheme.cyan(context)),
          const SizedBox(width: 8),
          _buildLegendItemLocal(context, 'Run Baseline', ConsoleTheme.primaryBlue(context)),
          const SizedBox(width: 8),
          _buildLegendItemLocal(context, 'Best Baseline', const Color(0xFFF59E0B)),
        ],
      ),
      child: SizedBox(
        height: 420,
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: Column(
            children: [
              Expanded(
                child: PueTrendLineChart(
                  puePoints: const [FlSpot(0,0)],
                  itEnergyPoints: const [FlSpot(0,0)],
                  totalEnergyPoints: const [FlSpot(0,0)],
                  baselines: [
                    HorizontalLine(y: 1.0, color: ConsoleTheme.cyan(context), strokeWidth: 2),
                    HorizontalLine(y: 1.5, color: ConsoleTheme.primaryBlue(context), strokeWidth: 2),
                    HorizontalLine(y: 1.2, color: const Color(0xFFF59E0B), strokeWidth: 2),
                  ],
                  bottomTitles: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
                ),
              ),
              _buildNiceDataTable(
                context, 
                const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'], 
                ['Lower Baseline', 'Run Baseline', 'Best Baseline'], 
                const [
                  ['1', '1', '1', '1', '1', '1', '1', '1', '1', '1', '1', '1'],
                  ['1.5', '1.5', '1.5', '1.5', '1.5', '1.5', '1.5', '1.5', '1.5', '1.5', '1.5', '1.5'],
                  ['1.2', '1.2', '1.2', '1.2', '1.2', '1.2', '1.2', '1.2', '1.2', '1.2', '1.2', '1.2'],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
