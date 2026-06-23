import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/console_theme.dart';

class PueTrendLineChart extends StatelessWidget {
  const PueTrendLineChart({
    super.key,
    required this.puePoints,
    required this.itEnergyPoints,
    required this.totalEnergyPoints,
    required this.bottomTitles,
  });

  final List<FlSpot> puePoints;
  final List<FlSpot> itEnergyPoints;
  final List<FlSpot> totalEnergyPoints;
  final List<String> bottomTitles;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: ConsoleTheme.divider(context).withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: ConsoleTheme.divider(context).withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < bottomTitles.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      bottomTitles[value.toInt()],
                      style: TextStyle(
                        color: ConsoleTheme.textSecondary(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: ConsoleTheme.textSecondary(context),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: ConsoleTheme.divider(context), width: 1),
            left: BorderSide(color: ConsoleTheme.divider(context), width: 1),
          ),
        ),
        minX: 0,
        maxX: bottomTitles.length.toDouble() - 1,
        minY: 0,
        maxY: 50,
        lineBarsData: [
          LineChartBarData(
            spots: puePoints,
            isCurved: true,
            color: ConsoleTheme.cyan(context),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  ConsoleTheme.cyan(context).withValues(alpha: 0.3),
                  ConsoleTheme.cyan(context).withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          LineChartBarData(
            spots: itEnergyPoints,
            isCurved: true,
            color: ConsoleTheme.primaryBlue(context),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: totalEnergyPoints,
            isCurved: true,
            color: ConsoleTheme.purple(context),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class PueConsumptionBarChart extends StatelessWidget {
  const PueConsumptionBarChart({
    super.key,
    required this.values,
    required this.labels,
  });

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 450,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[value.toInt()],
                      style: TextStyle(
                        color: ConsoleTheme.textSecondary(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 100,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: ConsoleTheme.textSecondary(context),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 100,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: ConsoleTheme.divider(context).withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: ConsoleTheme.divider(context), width: 1),
            left: BorderSide(color: ConsoleTheme.divider(context), width: 1),
          ),
        ),
        barGroups: List.generate(
          values.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                width: 14,
                color: index == 0
                    ? ConsoleTheme.cyan(context)
                    : index == 1
                        ? const Color(0xFFFACC15) // Yellow/Gold for IT Device
                        : index == 4
                            ? const Color(0xFFF43F5E) // Red/Pink for Lighting
                            : ConsoleTheme.primaryBlue(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
