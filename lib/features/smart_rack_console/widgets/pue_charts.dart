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
    this.baselines,
  });

  final List<FlSpot> puePoints;
  final List<FlSpot> itEnergyPoints;
  final List<FlSpot> totalEnergyPoints;
  final List<String> bottomTitles;
  final List<HorizontalLine>? baselines;

  String _seriesLabel(int index) {
    switch (index) {
      case 0:
        return 'PUE';
      case 1:
        return 'IT Energy';
      default:
        return 'Total Energy';
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxDataVal = 0;
    final allPoints = [...puePoints, ...itEnergyPoints, ...totalEnergyPoints];
    for (final spot in allPoints) {
      if (spot.y > maxDataVal) maxDataVal = spot.y;
    }

    // Add 20% headroom, default to 50 if all 0
    double rawMaxY = maxDataVal > 0 ? (maxDataVal * 1.2) : 50;
    
    // Calculate interval for ~5 horizontal grid lines
    double calculatedInterval = (rawMaxY / 5).ceilToDouble();
    // Snap to a clean nice number
    if (calculatedInterval <= 1) {
      calculatedInterval = 1;
    } else if (calculatedInterval <= 2) {
      calculatedInterval = 2;
    } else if (calculatedInterval <= 5) {
      calculatedInterval = 5;
    } else if (calculatedInterval <= 10) {
      calculatedInterval = 10;
    } else if (calculatedInterval <= 50) {
      calculatedInterval = 50;
    } else if (calculatedInterval <= 100) {
      calculatedInterval = 100;
    } else {
      calculatedInterval = (calculatedInterval / 100).ceilToDouble() * 100;
    }

    // Force the max Y to be a clean multiple of the interval so the top label always renders!
    double calculatedMaxY = (rawMaxY / calculatedInterval).ceilToDouble() * calculatedInterval;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLite = ConsoleTheme.isRackConsoleLite;
        final bottomLabelStep =
            bottomTitles.length > 24 ? (bottomTitles.length / 8).ceil() : 1;

        // Keep the chart readable, but reduce the canvas footprint on rack-console builds.
        final double minWidthPerPoint = isLite ? 28.0 : 45.0;
        final double calculatedWidth = bottomTitles.length * minWidthPerPoint;
        
        // Use a minimum of the available width so it doesn't shrink when data is small
        // We reserve 40 pixels for the sticky Y-axis on the left
        final double availableChartWidth = constraints.maxWidth - 40; 
        final double chartWidth = calculatedWidth > availableChartWidth ? calculatedWidth : availableChartWidth;

        final leftTitlesWidget = AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: calculatedInterval,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              // Don't show labels that exceed our max
              if (value > calculatedMaxY) return const SizedBox.shrink();
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
        );

        final emptyBottomTitlesWidget = AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30, // Must match the real bottom titles to keep Y alignment
            getTitlesWidget: (value, meta) => const Text(''),
          ),
        );

        final realBottomTitlesWidget = AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              final showLabel = index >= 0 &&
                  index < bottomTitles.length &&
                  (index % bottomLabelStep == 0 ||
                      index == bottomTitles.length - 1 ||
                      index == 0);
              if (showLabel) {
                double shiftX = 0;
                // Shift the first label to the right so it doesn't clip
                if (index == 0) shiftX = 14.0;
                // Shift the last label to the left so it doesn't clip
                if (index == bottomTitles.length - 1) shiftX = -14.0;

                return Transform.translate(
                  offset: Offset(shiftX, 8.0),
                  child: Text(
                    bottomTitles[index],
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
        );

        final gridData = FlGridData(
          show: true,
          drawVerticalLine: !isLite,
          horizontalInterval: calculatedInterval,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: ConsoleTheme.divider(context).withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: isLite ? null : [4, 4],
            );
          },
          getDrawingVerticalLine: (value) {
            if (isLite) {
              return const FlLine(
                color: Colors.transparent,
                strokeWidth: 0,
              );
            }
            return FlLine(
              color: ConsoleTheme.divider(context).withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        );

        return Row(
          children: [
            // Sticky Y-Axis Chart
            SizedBox(
              width: 40,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: emptyBottomTitlesWidget,
                    leftTitles: leftTitlesWidget,
                  ),
                  minX: 0,
                  maxX: 1,
                  minY: 0,
                  maxY: calculatedMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [FlSpot(0, 0)],
                      color: Colors.transparent, // Invisible line just to size the chart
                      dotData: const FlDotData(show: false),
                    )
                  ],
                ),
                duration: isLite
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
              ),
            ),
            // Scrollable Data Chart
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  child: LineChart(
                    LineChartData(
                      extraLinesData: ExtraLinesData(
                        horizontalLines: baselines ?? [],
                      ),
                      gridData: gridData,
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide Y-axis here
                        bottomTitles: realBottomTitlesWidget,
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: ConsoleTheme.divider(context), width: 1),
                          left: BorderSide(color: ConsoleTheme.divider(context), width: 1),
                        ),
                      ),
                      minX: 0,
                      maxX: bottomTitles.isNotEmpty
                          ? bottomTitles.length.toDouble() - 1
                          : 0,
                      minY: 0,
                      maxY: calculatedMaxY,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipRoundedRadius: 8,
                          getTooltipColor: (_) => ConsoleTheme.cardBg(context),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final label = _seriesLabel(spot.barIndex);
                              return LineTooltipItem(
                                '$label\n${spot.y.toStringAsFixed(2)}',
                                TextStyle(
                                  color: ConsoleTheme.textPrimary(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: puePoints,
                          isCurved: true,
                          curveSmoothness: isLite ? 0.35 : 0.45,
                          color: ConsoleTheme.cyan(context),
                          barWidth: isLite ? 2 : 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: !isLite,
                            gradient: isLite
                                ? null
                                : LinearGradient(
                                    colors: [
                                      ConsoleTheme.cyan(context)
                                          .withValues(alpha: 0.3),
                                      ConsoleTheme.cyan(context)
                                          .withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                          ),
                        ),
                        LineChartBarData(
                          spots: itEnergyPoints,
                          isCurved: true,
                          curveSmoothness: isLite ? 0.35 : 0.45,
                          color: ConsoleTheme.primaryBlue(context),
                          barWidth: isLite ? 1.5 : 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: totalEnergyPoints,
                          isCurved: true,
                          curveSmoothness: isLite ? 0.35 : 0.45,
                          color: ConsoleTheme.purple(context),
                          barWidth: isLite ? 1.5 : 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                    duration: isLite
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    double maxDataVal = 0;
    for (final val in values) {
      if (val > maxDataVal) maxDataVal = val;
    }

    // Add 20% headroom, default to 450 if all 0
    double calculatedMaxY = maxDataVal > 0 ? (maxDataVal * 1.2) : 450;

    // Calculate interval for ~5 horizontal grid lines
    double calculatedInterval = (calculatedMaxY / 5).ceilToDouble();
    // Snap to a clean nice number
    if (calculatedInterval <= 10) {
      calculatedInterval = 10;
    } else if (calculatedInterval <= 50) {
      calculatedInterval = 50;
    } else if (calculatedInterval <= 100) {
      calculatedInterval = 100;
    } else {
      calculatedInterval = (calculatedInterval / 100).ceilToDouble() * 100;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: calculatedMaxY,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipColor: (_) => ConsoleTheme.cardBg(context),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = group.x.toInt() >= 0 && group.x.toInt() < labels.length
                  ? labels[group.x.toInt()]
                  : 'Value';
              return BarTooltipItem(
                '$label\n${rod.toY.toStringAsFixed(2)}',
                TextStyle(
                  color: ConsoleTheme.textPrimary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
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
              interval: calculatedInterval,
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
          horizontalInterval: calculatedInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: ConsoleTheme.divider(context).withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: ConsoleTheme.isRackConsoleLite ? null : [4, 4],
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
                width: ConsoleTheme.isRackConsoleLite ? 10 : 14,
                color: index == 0
                    ? ConsoleTheme.cyan(context)
                    : index == 1
                        ? const Color(0xFFFACC15)
                        : index == 4
                            ? const Color(0xFFF43F5E)
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
      swapAnimationDuration: ConsoleTheme.isRackConsoleLite
          ? Duration.zero
          : const Duration(milliseconds: 150),
    );
  }
}
