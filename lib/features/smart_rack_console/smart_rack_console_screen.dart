import 'package:flutter/material.dart';

import '../../core/controllers/global_status_poller.dart';
import '../dashboard/widgets/device_health_section.dart';
import '../dashboard/widgets/environment_gauges.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'models/smart_rack_device_profile.dart';
import 'services/smart_rack_console_repository.dart';
import 'theme/console_theme.dart';
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
    final right = _buildCurrentPuePanel(context, snapshot);

    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: ConsoleTheme.lg),
          middle,
          const SizedBox(height: ConsoleTheme.lg),
          right,
          const SizedBox(height: ConsoleTheme.lg),
          _buildMonitoringStatisticsPanel(context, snapshot, twoColumn: false),
          const SizedBox(height: ConsoleTheme.lg),
          _buildCapacityPanel(context, snapshot),
        ],
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: ConsoleTheme.lg),
              Expanded(child: middle),
              const SizedBox(width: ConsoleTheme.lg),
              Expanded(child: right),
            ],
          ),
        ),
        const SizedBox(height: ConsoleTheme.lg),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _buildMonitoringStatisticsPanel(context, snapshot, twoColumn: true),
              ),
              const SizedBox(width: ConsoleTheme.lg),
              Expanded(
                flex: 1,
                child: _buildCapacityPanel(context, snapshot),
              ),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildRackOverview(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final isSuperWide = MediaQuery.of(context).size.width >= 1100;

    return ConsoleSectionCard(
      title: 'Rack Overview',
      minHeight: 200,
      expand: true,
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
      expand: true,
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

  Color _getPueColor(double pue) {
    if (pue <= 0) {
      return const Color(0xFF8A94A6);
    }
    if (pue <= 1.2) {
      return const Color(0xFF00A174);
    }
    if (pue < 2.0) {
      return const Color(0xFFFF8A00);
    }
    return const Color(0xFFFF3B30);
  }

  Widget _buildCurrentPuePanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final isWide = MediaQuery.of(context).size.width > 1200;
    final chartSize = isWide ? 160.0 : 120.0;
    final pueColor = _getPueColor(snapshot.pue);

    return ConsoleSectionCard(
      title: 'Current PUE',
      minHeight: 200,
      expand: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: chartSize,
            height: chartSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ArcGauge(
                  progress: ((snapshot.pue - 1.0) / (3.0 - 1.0)).clamp(0.0, 1.0),
                  glowColor: pueColor,
                  baseColor: ConsoleTheme.isDark(context) ? const Color(0xFF3A3A3A) : const Color(0xFFC0D3EB),
                  strokeWidth: isWide ? 16.0 : 12.0,
                  sweepDegrees: 255,
                  startDegrees: 145,
                  glowIntensity: 1.0,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      snapshot.pue.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: isWide ? 32 : 24,
                        fontWeight: FontWeight.bold,
                        color: ConsoleTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      'PUE',
                      style: TextStyle(
                        fontSize: isWide ? 14 : 11,
                        color: pueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Total Energy Consumption Of The Month',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ConsoleTheme.textPrimary(context),
              fontSize: isWide ? 13 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '850.72',
                style: TextStyle(
                  color: ConsoleTheme.cyan(context),
                  fontSize: isWide ? 32 : 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: ConsoleTheme.cyan(context).withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: isWide ? 4.0 : 2.0),
                child: Text(
                  'kW·h',
                  style: TextStyle(
                    color: ConsoleTheme.textPrimary(context),
                    fontSize: isWide ? 14 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringStatisticsPanel(BuildContext context, SmartRackConsoleSnapshot snapshot, {bool twoColumn = false}) {
    return ConsoleSectionCard(
      title: 'Monitoring Statistics',
      minHeight: 200,
      expand: true,
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
          Expanded(
            child: SizedBox(
              width: double.infinity,
            child: DeviceHealthSection(
              devices: snapshot.devices,
              alarms: snapshot.alarms,
              temperatures: snapshot.temperatures,
              humidities: snapshot.humidities,
              smokeStatus: snapshot.smokeStatus,
              floodStatus: snapshot.floodStatus,
              minimalist: true,
              twoColumn: twoColumn,
            ),
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
      expand: true,
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              chart,
              legend,
            ],
          );
        },
      ),
    );
  }

  // Removed unused _buildResourcePanel

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
          sweepDegrees: 255,
          startDegrees: 145,
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

