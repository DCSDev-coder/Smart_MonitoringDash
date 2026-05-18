import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ScrollableTimeSeriesChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> xLabels;
  final Color lineColor;
  final double height;
  final double? minY;
  final double? maxY;
  final int targetXTicks;
  final int targetYTicks;
  final double minHeightPerYTick;
  final double pxPerPoint;
  final double xEdgePadding;
  final EdgeInsetsGeometry padding;
  final String? emptyText;
  final bool enableTouch;
  final String Function(String raw)? xLabelFormatter;
  final bool showXLabelOnChange;

  const ScrollableTimeSeriesChart({
    super.key,
    required this.spots,
    required this.xLabels,
    required this.lineColor,
    required this.height,
    this.minY,
    this.maxY,
    this.targetXTicks = 6,
    this.targetYTicks = 4,
    this.minHeightPerYTick = 26,
    this.pxPerPoint = 10,
    this.xEdgePadding = 18,
    this.padding = const EdgeInsets.fromLTRB(8, 16, 12, 8),
    this.emptyText,
    this.enableTouch = false,
    this.xLabelFormatter,
    this.showXLabelOnChange = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final axisTextColor =
        isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary;
    final gridColor = isLight
        ? AppTheme.lightTextSecondary.withValues(alpha: 0.14)
        : AppTheme.textSecondary.withValues(alpha: 0.10);
    final tooltipBgColor =
        isLight ? theme.colorScheme.surface : AppTheme.cardColor;

    if (spots.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyText ?? 'No data',
            style: TextStyle(fontSize: 12, color: axisTextColor),
          ),
        ),
      );
    }

    final computedMinY = minY ?? _minY(spots);
    final computedMaxY = maxY ?? _maxY(spots);
    final yBounds =
        _niceYBounds(computedMinY, computedMaxY, targetTicks: targetYTicks);
    final yTicks = _buildTicks(yBounds.min, yBounds.max, yBounds.step);
    final effectiveHeight =
        math.max(height, (yTicks.length * minHeightPerYTick) + 92);

    return LayoutBuilder(
      builder: (context, constraints) {
        const yAxisWidth = 44.0;
        final visibleChartWidth =
            (constraints.maxWidth - yAxisWidth).clamp(120.0, double.infinity);
        final contentWidth =
            (spots.length <= 1) ? 0.0 : ((spots.length - 1) * pxPerPoint);
        final chartWidth =
            math.max(visibleChartWidth, contentWidth + (xEdgePadding * 2));
        final labelStep = _computeLabelStep(
          visibleWidth: visibleChartWidth,
          pxPerPoint: pxPerPoint,
          targetTicks: targetXTicks,
        );
        final lastTick = ((spots.length - 1) ~/ labelStep) * labelStep;
        final format = xLabelFormatter ?? _formatXLabel;
        final formattedLabels = xLabels.map(format).toList(growable: false);
        final showDots = isLight && spots.length <= 48;
        final useCurvedLine = spots.length <= 72;

        return SizedBox(
          height: effectiveHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: yAxisWidth,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 26, right: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: yTicks
                        .map(
                          (v) => Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatCompactNumber(v),
                              style: TextStyle(
                                fontSize: 10,
                                color: axisTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: chartWidth,
                    child: Padding(
                      padding: padding.add(
                        EdgeInsets.symmetric(horizontal: xEdgePadding),
                      ),
                      child: LineChart(
                        LineChartData(
                          minY: yBounds.min,
                          maxY: yBounds.max,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: yBounds.step,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: gridColor,
                              strokeWidth: 1,
                              dashArray: const [6, 6],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final i = value.round();
                                  if (i < 0 || i >= xLabels.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final isLast = i == spots.length - 1;
                                  final closeToLastTick = (!isLast &&
                                      i == lastTick &&
                                      (spots.length - 1 - lastTick) <
                                          (labelStep * 0.65));
                                  final isBoundary = i == 0 ||
                                      formattedLabels[i] !=
                                          formattedLabels[i - 1];
                                  final shouldShow =
                                      (showXLabelOnChange && isBoundary) ||
                                          isLast ||
                                          (!closeToLastTick &&
                                              (i % labelStep == 0));
                                  if (!shouldShow) {
                                    return const SizedBox.shrink();
                                  }

                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 6,
                                    child: Text(
                                      formattedLabels[i],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: axisTextColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: useCurvedLine,
                              curveSmoothness: 0.18,
                              color: lineColor,
                              barWidth: 2.4,
                              dotData: FlDotData(
                                show: showDots,
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 2.8,
                                    color: lineColor,
                                    strokeWidth: 1.4,
                                    strokeColor: theme.colorScheme.surface,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    lineColor.withValues(alpha: 0.16),
                                    lineColor.withValues(alpha: 0.00),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Touch gestures fight with horizontal scrolling. Default off.
                          lineTouchData: enableTouch
                              ? LineTouchData(
                                  enabled: true,
                                  handleBuiltInTouches: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (_) => tooltipBgColor,
                                    tooltipPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((s) {
                                        final idx = s.x
                                            .round()
                                            .clamp(0, xLabels.length - 1);
                                        return LineTooltipItem(
                                          '${formattedLabels[idx]}\n${_formatCompactNumber(s.y)}',
                                          TextStyle(
                                            color: lineColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                )
                              : const LineTouchData(enabled: false),
                        ),
                        duration: Duration.zero,
                        curve: Curves.linear,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static int _computeLabelStep({
    required double visibleWidth,
    required double pxPerPoint,
    required int targetTicks,
  }) {
    final visiblePoints =
        math.max(2, (visibleWidth / math.max(1, pxPerPoint)).floor());
    final raw = (visiblePoints / math.max(1, targetTicks)).floor();
    // Ensure a minimum visual spacing between labels (prevents overlap on narrow screens).
    final minSpacingStep = (56 / math.max(1, pxPerPoint)).ceil();
    return math.max(1, math.max(raw, minSpacingStep));
  }

  static String _formatXLabel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    // Prefer HH:mm when present.
    final time = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (time != null) {
      final hh = time.group(1)!.padLeft(2, '0');
      final mm = time.group(2)!;
      return '$hh:$mm';
    }

    // Format yyyy-mm-dd to dd/mm.
    final date = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (date != null) {
      final dd = date.group(3)!;
      final mm = date.group(2)!;
      return '$dd/$mm';
    }

    // Otherwise keep it compact.
    if (s.length <= 7) return s;
    return s.substring(0, 7);
  }

  static double _minY(List<FlSpot> s) => s.map((e) => e.y).reduce(math.min);
  static double _maxY(List<FlSpot> s) => s.map((e) => e.y).reduce(math.max);

  static _NiceBounds _niceYBounds(double min, double max,
      {required int targetTicks}) {
    var lo = min.isFinite ? min : 0.0;
    var hi = max.isFinite ? max : 0.0;
    if (lo == hi) {
      final bump = lo == 0 ? 1.0 : (lo.abs() * 0.1);
      lo -= bump;
      hi += bump;
    }

    // For power charts we typically want baseline at 0 if data is positive.
    if (lo >= 0) lo = 0;

    final range = (hi - lo).abs();
    final step = _niceStep(range / math.max(1, targetTicks));
    final niceLo = (lo / step).floor() * step;
    final niceHi = (hi / step).ceil() * step;
    return _NiceBounds(min: niceLo, max: niceHi, step: step);
  }

  static double _niceStep(double rawStep) {
    if (rawStep <= 0) return 1;
    final exp =
        math.pow(10.0, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final f = rawStep / exp;
    final niceF = (f <= 1)
        ? 1
        : (f <= 2)
            ? 2
            : (f <= 5)
                ? 5
                : 10;
    return niceF * exp;
  }

  static List<double> _buildTicks(double min, double max, double step) {
    final ticks = <double>[];
    final count = ((max - min) / step).round();
    for (int i = 0; i <= count; i++) {
      ticks.add(min + step * i);
    }
    return ticks.reversed.toList(); // top -> bottom
  }

  static String _formatCompactNumber(double v) {
    final abs = v.abs();
    if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (abs >= 10) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _NiceBounds {
  final double min;
  final double max;
  final double step;

  const _NiceBounds({required this.min, required this.max, required this.step});
}
