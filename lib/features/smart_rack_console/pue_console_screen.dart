import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/pue_charts.dart';

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

    final q1 = _buildCurrentPueQuadrant(context);
    final q2 = _build8HoursQuadrant(context);
    final q3 = _buildCurrentEnergyQuadrant(context);
    final q4 = _buildAnnualOperationQuadrant(context);

    return Container(
      decoration: BoxDecoration(
        gradient: ConsoleTheme.pageBgGradient(context),
      ),
      child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildCurrentPueQuadrant(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Current PUE',
      minHeight: 350,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 1.0,
                  maximum: 3.0,
                  showLabels: false,
                  showTicks: true,
                  tickOffset: 15,
                  minorTicksPerInterval: 5,
                  majorTickStyle: MajorTickStyle(
                    color: ConsoleTheme.cyan(context),
                    length: 10,
                    thickness: 2,
                  ),
                  minorTickStyle: MinorTickStyle(
                    color: ConsoleTheme.cyan(context).withValues(alpha: 0.5),
                    length: 5,
                    thickness: 1,
                  ),
                  axisLineStyle: AxisLineStyle(
                    thickness: 15,
                    cornerStyle: CornerStyle.bothCurve,
                    color: ConsoleTheme.cyan(context).withValues(alpha: 0.2),
                  ),
                  pointers: <GaugePointer>[
                    RangePointer(
                      value: 2.25,
                      width: 15,
                      cornerStyle: CornerStyle.bothCurve,
                      gradient: SweepGradient(
                        colors: <Color>[
                          ConsoleTheme.primaryBlue(context),
                          ConsoleTheme.cyan(context),
                        ],
                        stops: const <double>[0.25, 0.75],
                      ),
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      positionFactor: 0.1,
                      angle: 90,
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Energy Consumption Of The Month',
                  style: TextStyle(
                    color: ConsoleTheme.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                  Text(
                    '850.72',
                    style: TextStyle(
                      color: ConsoleTheme.cyan(context),
                      fontSize: 36,
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
          ),
        ],
      ),
    );
  }

  Widget _build8HoursQuadrant(BuildContext context) {
    return ConsoleSectionCard(
      title: '8 Hours',
      trailing: Row(
        children: [
          _buildPillToggle(context, 'PUE', true),
          const SizedBox(width: 8),
          _buildPillToggle(context, 'IT Energy', false),
          const SizedBox(width: 8),
          _buildPillToggle(context, 'Total Energy', false),
        ],
      ),
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: PueTrendLineChart(
          puePoints: const [
            FlSpot(0, 5), FlSpot(1, 4), FlSpot(2, 6), FlSpot(3, 4), FlSpot(4, 8),
            FlSpot(5, 5), FlSpot(6, 4), FlSpot(7, 3), FlSpot(8, 5), FlSpot(9, 4),
          ],
          itEnergyPoints: const [
            FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), FlSpot(4, 0),
            FlSpot(5, 0), FlSpot(6, 0), FlSpot(7, 0), FlSpot(8, 0), FlSpot(9, 0),
          ],
          totalEnergyPoints: const [
            FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), FlSpot(4, 0),
            FlSpot(5, 0), FlSpot(6, 0), FlSpot(7, 0), FlSpot(8, 0), FlSpot(9, 0),
          ],
          bottomTitles: const ['04:30', '05:30', '06:30', '07:30', '08:30', '09:30', '10:30', '11:30', '', ''],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentEnergyQuadrant(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Current Energy Consumption Statistics',
      trailing: Row(
        children: [
          _buildPillToggle(context, 'Current', true),
          const SizedBox(width: 8),
          _buildPillToggle(context, 'Current Month', false),
        ],
      ),
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
                'Unit: (W·h)',
                style: TextStyle(
                  color: ConsoleTheme.textPrimary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: PueConsumptionBarChart(
                values: const [220, 100, 220, 220, 160, 0],
                labels: const ['Total', 'IT Device', 'Aircon', 'Power', 'Lighting', 'Other'],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAnnualOperationQuadrant(BuildContext context) {
    return ConsoleSectionCard(
      title: 'Annual Operation Trend',
      trailing: Row(
        children: [
          _buildPillToggle(context, 'PUE', true),
          const SizedBox(width: 8),
          _buildPillToggle(context, 'IT Energy', false),
          const SizedBox(width: 8),
          _buildPillToggle(context, 'Total Energy', false),
        ],
      ),
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, right: 16.0),
          child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildLegendItem(context, '2025', const Color(0xFFF97316)),
                const SizedBox(width: 16),
                _buildLegendItem(context, '2026', ConsoleTheme.cyan(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PueTrendLineChart(
                puePoints: const [
                  FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), 
                  FlSpot(4, 2.55), FlSpot(5, 2.48), FlSpot(6, 0), FlSpot(7, 0),
                  FlSpot(8, 0), FlSpot(9, 0), FlSpot(10, 0), FlSpot(11, 0),
                ],
                itEnergyPoints: const [],
                totalEnergyPoints: const [],
                bottomTitles: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDataRow(context, 'Date', const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDataRow(context, '2025', const ['0.0', '0.0', '0.0', '0.0', '0.0', '0.0', '0.0', '0.0', '0.0', '0.0', '0.0', '0.0']),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDataRow(context, '2026', const ['0.0', '0.0', '0.0', '0.0', '2.55', '2.48', '0.0', '0.0', '0.0', '0.0', '0.0', '0.0']),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String label, List<String> values) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 30,
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

  Widget _buildPillToggle(BuildContext context, String label, bool isActive) {
    return Container(
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
    );
  }
}
