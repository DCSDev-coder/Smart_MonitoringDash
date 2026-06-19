import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../core/controllers/global_status_poller.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'models/smart_rack_device_profile.dart';
import 'services/smart_rack_console_repository.dart';
import 'theme/console_theme.dart';
import 'widgets/console_metric_card.dart';
import 'widgets/console_section_card.dart';

class SmartRackConsoleScreen extends StatelessWidget {
  const SmartRackConsoleScreen({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final SmartRackDeviceProfile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GlobalStatusPoller.instance,
      builder: (context, _) {
        final snapshot =
            SmartRackConsoleRepository.instance.currentSnapshot();

        return Container(
          decoration: BoxDecoration(
            gradient: ConsoleTheme.pageBgGradient(context),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? ConsoleTheme.lg : ConsoleTheme.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricGrid(snapshot: snapshot, compact: compact),
                const SizedBox(height: ConsoleTheme.lg),
                _MainGrid(snapshot: snapshot, compact: compact),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.snapshot,
    required this.compact,
  });

  final SmartRackConsoleSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final columns = compact ? 2 : 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = ConsoleTheme.lg;
        final cardWidth = (constraints.maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: cardWidth,
              child: ConsoleMetricCard(
                label: 'Total Devices',
                value: '${snapshot.totalDevices}',
                icon: Icons.developer_board_rounded,
                accentColor: ConsoleTheme.primaryBlue(context),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: ConsoleMetricCard(
                label: 'Active Issues',
                value: '${snapshot.issueCount}',
                icon: Icons.notifications_active_rounded,
                accentColor: snapshot.issueCount > 0
                    ? ConsoleTheme.danger(context)
                    : ConsoleTheme.success(context),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: ConsoleMetricCard(
                label: 'Temp / RH',
                value: '${snapshot.temperatureC?.toStringAsFixed(1) ?? '--'}°C',
                subtext: '${snapshot.humidityPct?.toStringAsFixed(1) ?? '--'} %',
                icon: Icons.thermostat_rounded,
                accentColor: ConsoleTheme.cyan(context),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: ConsoleMetricCard(
                label: 'Maintenance',
                value: snapshot.maintenanceDaysLeft?.toString() ?? '--',
                subtext: 'Days left',
                icon: Icons.handyman_rounded,
                accentColor: ConsoleTheme.success(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MainGrid extends StatelessWidget {
  const _MainGrid({
    required this.snapshot,
    required this.compact,
  });

  final SmartRackConsoleSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final isNarrow = compact || width < 1100;

    final left = _buildRackOverview(context, snapshot);
    final middle = _buildEnvironmentPanel(context, snapshot);
    final right = _buildSensorPanel(context, snapshot);
    final bottomLeft = _buildMonitoringStats(context, snapshot);
    final bottomMiddle = _buildCapacityPanel(context, snapshot);
    final bottomRight = _buildResourcePanel(context, snapshot);

    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: ConsoleTheme.lg),
          middle,
          const SizedBox(height: ConsoleTheme.lg),
          right,
          const SizedBox(height: ConsoleTheme.lg),
          bottomLeft,
          const SizedBox(height: ConsoleTheme.lg),
          bottomMiddle,
          const SizedBox(height: ConsoleTheme.lg),
          bottomRight,
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: left),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(flex: 5, child: middle),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(flex: 4, child: right),
          ],
        ),
        const SizedBox(height: ConsoleTheme.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: bottomLeft),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(flex: 4, child: bottomMiddle),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(flex: 4, child: bottomRight),
          ],
        ),
      ],
    );
  }

  Widget _buildRackOverview(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Rack Overview',
      subtitle: 'Cabinet health & servers',
      child: Column(
        children: [
          // Custom vertical rack cabinet rendering
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ConsoleTheme.innerRadius),
              color: ConsoleTheme.innerSurface(context),
              border: Border.all(color: ConsoleTheme.cardBorder(context)),
            ),
            padding: const EdgeInsets.all(ConsoleTheme.sm),
            child: Row(
              children: [
                // Cabinet frame left rail
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: ConsoleTheme.textMuted(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: ConsoleTheme.sm),
                // Server slots U1 to U6
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      final uNumber = 6 - index;
                      final isOccupied = index % 2 == 0;
                      final hasAlert = index == 2 && snapshot.issueCount > 0;
                      final serverColor = hasAlert
                          ? ConsoleTheme.danger(context)
                          : isOccupied
                              ? ConsoleTheme.primaryBlue(context)
                              : ConsoleTheme.textMuted(context).withValues(alpha: 0.1);

                      return Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: isOccupied
                              ? serverColor.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isOccupied
                                ? serverColor.withValues(alpha: 0.4)
                                : serverColor.withValues(alpha: 0.2),
                            width: 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'U$uNumber',
                              style: TextStyle(
                                color: isOccupied
                                    ? ConsoleTheme.textPrimary(context)
                                    : ConsoleTheme.textMuted(context),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isOccupied)
                              Row(
                                children: [
                                  // glowing light indicator
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: serverColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: serverColor.withValues(alpha: 0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasAlert ? 'ALERT' : 'ACTIVE',
                                    style: TextStyle(
                                      color: serverColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'EMPTY',
                                style: TextStyle(
                                  color: ConsoleTheme.textMuted(context),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: ConsoleTheme.sm),
                // Cabinet frame right rail
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: ConsoleTheme.textMuted(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Uptime',
                  value: '${snapshot.systemUptimeDays ?? '--'} days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Water Leak',
                  value: snapshot.waterLeakLabel,
                  valueColor: snapshot.waterLeakLabel == 'Normal'
                      ? ConsoleTheme.success(context)
                      : ConsoleTheme.danger(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Temperature & Humidity',
      subtitle: 'Live environmental readings',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 130,
                  child: _buildRadialGauge(
                    context: context,
                    min: 0,
                    max: 60,
                    value: snapshot.temperatureC ?? 0,
                    unit: '°C',
                    label: 'Temp',
                    accentColor: ConsoleTheme.primaryBlue(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 130,
                  child: _buildRadialGauge(
                    context: context,
                    min: 0,
                    max: 100,
                    value: snapshot.humidityPct ?? 0,
                    unit: '%',
                    label: 'Humidity',
                    accentColor: ConsoleTheme.cyan(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatusLine(
            label: 'System Status',
            value: snapshot.issueCount > 0 ? 'Attention Needed' : 'Normal',
            valueColor: snapshot.issueCount > 0
                ? ConsoleTheme.danger(context)
                : ConsoleTheme.success(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Smoke & Water Sensors',
      subtitle: 'Cabinet safety monitors',
      child: Column(
        children: [
          _SensorRow(
            icon: Icons.cloud_rounded,
            label: 'Smoke Sensor',
            value: snapshot.smokeLabel,
            color: snapshot.smokeLabel == 'Normal'
                ? ConsoleTheme.success(context)
                : ConsoleTheme.danger(context),
          ),
          const SizedBox(height: 12),
          _SensorRow(
            icon: Icons.water_drop_rounded,
            label: 'Water Leak Sensor',
            value: snapshot.waterLeakLabel,
            color: snapshot.waterLeakLabel == 'Normal'
                ? ConsoleTheme.success(context)
                : ConsoleTheme.danger(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringStats(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Monitoring Statistics',
      subtitle: 'Device and alarm snapshot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: _TabChip(label: 'PE Monitoring', selected: true)),
              SizedBox(width: 8),
              Expanded(child: _TabChip(label: 'IT Monitoring')),
            ],
          ),
          const SizedBox(height: 16),
          _MiniStat(label: 'Total Devices', value: '${snapshot.totalDevices}'),
          const SizedBox(height: 12),
          _MiniStat(
            label: 'Active Issues',
            value: '${snapshot.issueCount}',
            valueColor: snapshot.issueCount > 0
                ? ConsoleTheme.danger(context)
                : ConsoleTheme.success(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final usedRate = snapshot.capacityUsedPct ?? 29.76;

    return ConsoleSectionCard(
      title: 'Space Capacity',
      subtitle: 'Used cabinet capacity',
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: _buildRadialGauge(
              context: context,
              min: 0,
              max: 100,
              value: usedRate,
              unit: '%',
              label: 'Used Rate',
              accentColor: ConsoleTheme.primaryBlue(context),
            ),
          ),
          const SizedBox(height: 12),
          const _StatusLine(label: 'Cabinet Item 1', value: '45.24%'),
          const SizedBox(height: 8),
          const _StatusLine(label: 'Cabinet Item 2', value: '14.29%'),
        ],
      ),
    );
  }

  Widget _buildResourcePanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final memoryPct = snapshot.memoryUsedPct ?? 63.2;

    return ConsoleSectionCard(
      title: 'Resource',
      subtitle: 'Memory, CPU and disk',
      trailing: const _TabChip(label: 'Memory', selected: true),
      child: Column(
        children: [
          _SensorRow(
            icon: Icons.memory_rounded,
            label: 'Memory Usage',
            value: '${memoryPct.toStringAsFixed(1)}%',
            color: ConsoleTheme.primaryBlue(context),
          ),
          const SizedBox(height: 10),
          _buildResourceProgressBar(context, memoryPct),
          const SizedBox(height: 14),
          const _StatusLine(label: 'Total Memory', value: '32 GB'),
          const SizedBox(height: 6),
          const _StatusLine(label: 'Used Memory', value: '20.2 GB'),
          const SizedBox(height: 6),
          const _StatusLine(label: 'Free Memory', value: '11.8 GB'),
        ],
      ),
    );
  }

  // Helper widget to build premium radial gauges using Syncfusion Gauge library
  Widget _buildRadialGauge({
    required BuildContext context,
    required double min,
    required double max,
    required double value,
    required String unit,
    required String label,
    required Color accentColor,
  }) {
    final isDark = ConsoleTheme.isDark(context);
    final valueTextColor = ConsoleTheme.textPrimary(context);
    final labelTextColor = ConsoleTheme.textSecondary(context);
    final trackColor = isDark
        ? const Color(0xFF0E284D) // Dark blue-navy track
        : const Color(0xFFEAF1FA); // Soft gray-blue track

    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: min,
          maximum: max,
          showLabels: false,
          showTicks: false,
          axisLineStyle: AxisLineStyle(
            thickness: 10,
            color: trackColor,
            thicknessUnit: GaugeSizeUnit.logicalPixel,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: value.clamp(min, max),
              width: 10,
              pointerOffset: 0,
              sizeUnit: GaugeSizeUnit.logicalPixel,
              gradient: SweepGradient(
                colors: isDark
                    ? [accentColor, ConsoleTheme.cyan(context)]
                    : [accentColor, ConsoleTheme.cyan(context)],
                stops: const <double>[0.0, 1.0],
              ),
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.1,
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.toStringAsFixed(1)}$unit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: valueTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: labelTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Custom linear progress bar for resource usage
  Widget _buildResourceProgressBar(BuildContext context, double percentage) {
    final isDark = ConsoleTheme.isDark(context);
    final trackColor = isDark
        ? const Color(0xFF091A35)
        : const Color(0xFFEAF3FF);

    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: ConsoleTheme.cardBorder(context).withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (percentage / 100).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: ConsoleTheme.activeAccentGradient(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? ConsoleTheme.textPrimary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ConsoleTheme.innerSurface(context),
        borderRadius: BorderRadius.circular(ConsoleTheme.innerRadius),
        border: Border.all(color: ConsoleTheme.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ConsoleTheme.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ConsoleTheme.innerSurface(context),
        borderRadius: BorderRadius.circular(ConsoleTheme.innerRadius),
        border: Border.all(color: ConsoleTheme.divider(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: ConsoleTheme.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? ConsoleTheme.textPrimary(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ConsoleTheme.textSecondary(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    this.selected = false,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final activeColor = ConsoleTheme.primaryBlue(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? activeColor.withValues(alpha: 0.15)
            : ConsoleTheme.innerSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? activeColor.withValues(alpha: 0.3)
              : ConsoleTheme.divider(context),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected
              ? ConsoleTheme.textPrimary(context)
              : ConsoleTheme.textSecondary(context),
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
