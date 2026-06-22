import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../core/controllers/global_status_poller.dart';
import '../dashboard/widgets/device_health_section.dart';
import '../dashboard/widgets/environment_gauges.dart';
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
            padding: const EdgeInsets.all(ConsoleTheme.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
    final isNarrow = compact || width < 400;

    final left = _buildRackOverview(context, snapshot);
    final middle = _buildEnvironmentPanel(context, snapshot);
    final right = _buildSensorPanel(context, snapshot);

    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: ConsoleTheme.lg),
          middle,
          const SizedBox(height: ConsoleTheme.lg),
          right,
          const SizedBox(height: ConsoleTheme.lg),
          _buildPlaceholderCard('Card 4'),
          const SizedBox(height: ConsoleTheme.lg),
          _buildPlaceholderCard('Card 5'),
          const SizedBox(height: ConsoleTheme.lg),
          _buildPlaceholderCard('Card 6'),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(child: middle),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(child: right),
          ],
        ),
        const SizedBox(height: ConsoleTheme.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildMonitoringStatisticsPanel(context, snapshot)),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(child: _buildCapacityPanel(context, snapshot)),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(child: _buildResourcePanel(context, snapshot)),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard(String title) {
    return ConsoleSectionCard(
      title: title,
      minHeight: 200,
      child: const Center(
        child: Text(
          'Coming Soon',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );
  }


  Widget _buildRackOverview(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final textSecondary = ConsoleTheme.textSecondary(context);
    final statusColor = snapshot.issueCount > 0
        ? ConsoleTheme.danger(context)
        : ConsoleTheme.success(context);
    final statusText = snapshot.issueCount > 0 ? 'Attention Needed' : 'Normal';

    final isSuperWide = MediaQuery.of(context).size.width >= 1100;

    return ConsoleSectionCard(
      title: 'Rack Overview',
      minHeight: 200,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: isSuperWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/smart_rack_containment_logo.png',
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VerticalStatItem(
                          label: 'Maintenance\nDays Left',
                          value: '${snapshot.maintenanceDaysLeft ?? '--'}',
                          subValue: 'Days Left',
                          valueColor: ConsoleTheme.primaryBlue(context),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/smart_rack_containment_logo.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    _VerticalStatItem(
                      label: 'Maintenance\nDays Left',
                      value: '${snapshot.maintenanceDaysLeft ?? '--'}',
                      subValue: 'Days Left',
                      valueColor: ConsoleTheme.primaryBlue(context),
                      centered: true,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEnvironmentPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final isSuperWide = MediaQuery.of(context).size.width >= 1100;

    return ConsoleSectionCard(
      title: 'Temperature & Humidity',
      minHeight: 200,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: EnvironmentRow(
          temperatures: snapshot.temperatures,
          humidities: snapshot.humidities,
          alarms: snapshot.alarms,
          initialStyle: EnvironmentGaugeStyle.meter,
          minimalist: true,
          isVertical: !isSuperWide,
          gaugeHeight: isSuperWide ? 160 : 240,
        ),
      ),
    );
  }

  Widget _buildSensorPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Smoke & Water Sensors',
      minHeight: 200,
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

  Widget _buildMonitoringStatisticsPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Monitoring Statistics',
      minHeight: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PE Monitoring',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: DeviceHealthSection(
              devices: snapshot.devices,
              alarms: snapshot.alarms,
              temperatures: snapshot.temperatures,
              humidities: snapshot.humidities,
              smokeStatus: snapshot.smokeStatus,
              floodStatus: snapshot.floodStatus,
              minimalist: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final usedRate = snapshot.capacityUsedPct ?? 29.76;

    return ConsoleSectionCard(
      title: 'Space Capacity',
      minHeight: 200,
      child: Builder(
        builder: (context) {
          final isWide = MediaQuery.of(context).size.width > 1200;
          final chartSize = isWide ? 160.0 : 120.0;
          
          final chart = SizedBox(
            height: chartSize,
            width: chartSize,
            child: _buildRadialGauge(
              context: context,
              min: 0,
              max: 100,
              value: usedRate,
              unit: '%',
              label: 'Used Rate',
              accentColor: ConsoleTheme.primaryBlue(context),
            ),
          );

          final legend = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SensorRow(
                icon: Icons.dns_rounded,
                label: 'Cabinet Item 1',
                value: '45%',
                color: ConsoleTheme.primaryBlue(context),
              ),
              const SizedBox(height: 8),
              _buildResourceProgressBar(context, 45.0),
              const SizedBox(height: 16),
              _SensorRow(
                icon: Icons.dns_rounded,
                label: 'Cabinet Item 2',
                value: '14%',
                color: ConsoleTheme.primaryBlue(context),
              ),
              const SizedBox(height: 8),
              _buildResourceProgressBar(context, 14.0),
            ],
          );

          return Column(
            children: [
              chart,
              const SizedBox(height: 16),
              legend,
            ],
          );
        },
      ),
    );
  }

  Widget _buildResourcePanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final memoryPct = snapshot.memoryUsedPct ?? 63.2;
    final cpuPct = snapshot.cpuUsedPct ?? 18.5;
    final diskPct = snapshot.diskUsedPct ?? 45.0;

    return ConsoleSectionCard(
      title: 'Resource',
      minHeight: 200,
      child: Column(
        children: [
          _SensorRow(
            icon: Icons.memory_rounded,
            label: 'Memory Usage',
            value: '${memoryPct.toInt()}%',
            color: ConsoleTheme.primaryBlue(context),
          ),
          const SizedBox(height: 8),
          _buildResourceProgressBar(context, memoryPct),
          const SizedBox(height: 16),
          _SensorRow(
            icon: Icons.developer_board_rounded,
            label: 'CPU Usage',
            value: '${cpuPct.toInt()}%',
            color: ConsoleTheme.cyan(context),
          ),
          const SizedBox(height: 8),
          _buildResourceProgressBar(context, cpuPct, color: ConsoleTheme.cyan(context)),
          const SizedBox(height: 16),
          _SensorRow(
            icon: Icons.storage_rounded,
            label: 'Disk Usage',
            value: '${diskPct.toInt()}%',
            color: ConsoleTheme.purple(context),
          ),
          const SizedBox(height: 8),
          _buildResourceProgressBar(context, diskPct, color: ConsoleTheme.purple(context)),
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
        ? const Color(0xFF3A3A3A) // Darker grey track to make it more distinct but subtle
        : const Color(0xFFC0D3EB); // Darker gray-blue track for light mode

    final isSuperWide = MediaQuery.of(context).size.width >= 1100;
    final strokeWidth = isSuperWide ? 16.0 : 12.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        ArcGauge(
          progress: (value - min) / (max - min),
          glowColor: accentColor,
          baseColor: trackColor,
          strokeWidth: strokeWidth,
          sweepDegrees: 210,
          startDegrees: 195,
          glowIntensity: 1.0,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16), // Push text slightly down to center inside the arc
            Text(
              '${value.toInt()}$unit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueTextColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: labelTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Custom linear progress bar for resource usage
  Widget _buildResourceProgressBar(BuildContext context, double percentage, {Color? color}) {
    final isDark = ConsoleTheme.isDark(context);
    final trackColor = isDark
        ? const Color(0xFF091A35)
        : const Color(0xFFEAF3FF);
        
    final accent = color ?? ConsoleTheme.primaryBlue(context);

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
              color: accent,
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: ConsoleTheme.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
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

class _VerticalStatItem extends StatelessWidget {
  const _VerticalStatItem({
    required this.label,
    required this.value,
    required this.subValue,
    required this.valueColor,
    this.centered = false,
  });

  final String label;
  final String value;
  final String subValue;
  final Color valueColor;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: ConsoleTheme.textPrimary(context),
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 42,
              height: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            subValue,
            style: TextStyle(
              color: ConsoleTheme.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
