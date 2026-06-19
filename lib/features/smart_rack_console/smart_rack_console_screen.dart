import 'package:flutter/material.dart';

import '../../core/controllers/global_status_poller.dart';
import '../../core/theme/app_theme.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'models/smart_rack_device_profile.dart';
import 'services/smart_rack_console_repository.dart';
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF07111F), Color(0xFF0B1A2B), Color(0xFF06101A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopStrip(snapshot: snapshot, profile: profile),
                const SizedBox(height: 18),
                _MetricGrid(snapshot: snapshot, compact: compact),
                const SizedBox(height: 18),
                _MainGrid(snapshot: snapshot, compact: compact),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopStrip extends StatelessWidget {
  const _TopStrip({
    required this.snapshot,
    required this.profile,
  });

  final SmartRackConsoleSnapshot snapshot;
  final SmartRackDeviceProfile profile;

  @override
  Widget build(BuildContext context) {
    final updated = snapshot.lastUpdatedUtc;
    final timeText = updated == null
        ? 'Waiting for live data'
        : 'Updated ${TimeOfDay.fromDateTime(updated.toLocal()).format(context)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.siteName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(
                      label: snapshot.healthLabel,
                      color: snapshot.healthColor,
                    ),
                    _StatusPill(
                      label: profile.label,
                      color: AppTheme.accentBlue,
                    ),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!profile.isDisplayOnly)
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Control'),
            ),
        ],
      ),
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
    final cardWidth = (MediaQuery.of(context).size.width - (columns + 1) * 12) /
        columns;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: cardWidth,
          child: ConsoleMetricCard(
            label: 'Total Devices',
            value: '${snapshot.totalDevices}',
            icon: Icons.developer_board_rounded,
            accentColor: AppTheme.accentBlue,
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: ConsoleMetricCard(
            label: 'Active Issues',
            value: '${snapshot.issueCount}',
            icon: Icons.notifications_active_rounded,
            accentColor: snapshot.issueCount > 0
                ? AppTheme.accentRed
                : AppTheme.accentGreen,
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: ConsoleMetricCard(
            label: 'Temp / RH',
            value:
                '${snapshot.temperatureC?.toStringAsFixed(1) ?? '--'}°C',
            subtext: '${snapshot.humidityPct?.toStringAsFixed(1) ?? '--'} %',
            icon: Icons.thermostat_rounded,
            accentColor: AppTheme.accentBlue,
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: ConsoleMetricCard(
            label: 'Maintenance',
            value: snapshot.maintenanceDaysLeft?.toString() ?? '--',
            subtext: 'Days left',
            icon: Icons.handyman_rounded,
            accentColor: AppTheme.accentGreen,
          ),
        ),
      ],
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
    final isNarrow = compact || MediaQuery.of(context).size.width < 1100;

    final left = _buildRackOverview(snapshot);
    final middle = _buildEnvironmentPanel(snapshot);
    final right = _buildSensorPanel(snapshot);
    final bottomLeft = _buildMonitoringStats(snapshot);
    final bottomMiddle = _buildCapacityPanel(snapshot);
    final bottomRight = _buildResourcePanel(snapshot);

    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          middle,
          const SizedBox(height: 12),
          right,
          const SizedBox(height: 12),
          bottomLeft,
          const SizedBox(height: 12),
          bottomMiddle,
          const SizedBox(height: 12),
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
            const SizedBox(width: 12),
            Expanded(flex: 5, child: middle),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: right),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: bottomLeft),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: bottomMiddle),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: bottomRight),
          ],
        ),
      ],
    );
  }

  Widget _buildRackOverview(SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Rack Overview',
      subtitle: 'Cabinet health and uptime',
      child: Column(
        children: [
          Container(
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF12263E), Color(0xFF0A1424)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Center(
              child: Icon(
                Icons.precision_manufacturing_rounded,
                size: 82,
                color: AppTheme.accentBlue,
              ),
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
                  label: 'Leak',
                  value: snapshot.waterLeakLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentPanel(SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Temperature & Humidity',
      subtitle: 'Live environmental readings',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GaugePlaceholder(
                  label: 'Temp',
                  value: snapshot.temperatureC?.toStringAsFixed(1) ?? '--',
                  unit: '°C',
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GaugePlaceholder(
                  label: 'RH',
                  value: snapshot.humidityPct?.toStringAsFixed(1) ?? '--',
                  unit: '%',
                  color: const Color(0xFF39C9FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _StatusLine(label: 'System Status', value: 'Normal'),
        ],
      ),
    );
  }

  Widget _buildSensorPanel(SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Smoke & Water Leak Sensors',
      subtitle: 'Cabinet safety monitors',
      child: Column(
        children: [
          _SensorRow(
            icon: Icons.cloud_rounded,
            label: 'Smoke Sensor',
            value: snapshot.smokeLabel,
            color: snapshot.smokeLabel == 'Normal'
                ? AppTheme.accentGreen
                : AppTheme.accentRed,
          ),
          const SizedBox(height: 12),
          _SensorRow(
            icon: Icons.water_drop_rounded,
            label: 'Water Leak',
            value: snapshot.waterLeakLabel,
            color: snapshot.waterLeakLabel == 'Normal'
                ? AppTheme.accentGreen
                : AppTheme.accentRed,
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringStats(SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Monitoring Statistics',
      subtitle: 'Device and alarm snapshot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: _TabChip(label: 'PE Monitoring', selected: true)),
              SizedBox(width: 8),
              Expanded(child: _TabChip(label: 'IT Monitoring')),
            ],
          ),
          const SizedBox(height: 16),
          _MiniStat(label: 'Total Devices', value: '${snapshot.totalDevices}'),
          const SizedBox(height: 12),
          _MiniStat(label: 'Active Issues', value: '${snapshot.issueCount}'),
        ],
      ),
    );
  }

  Widget _buildCapacityPanel(SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Space Capacity',
      subtitle: 'Used cabinet capacity',
      child: Column(
        children: [
          _GaugePlaceholder(
            label: 'Used Rate',
            value: snapshot.capacityUsedPct?.toStringAsFixed(2) ?? '29.76',
            unit: '%',
            color: AppTheme.accentBlue,
            height: 150,
          ),
          const SizedBox(height: 12),
          const _StatusLine(label: 'Cabinet Item 1', value: '45.24%'),
          const SizedBox(height: 8),
          const _StatusLine(label: 'Cabinet Item 2', value: '14.29%'),
        ],
      ),
    );
  }

  Widget _buildResourcePanel(SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Resource',
      subtitle: 'Memory, CPU and disk',
      trailing: const _TabChip(label: 'Memory', selected: true),
      child: Column(
        children: [
          _SensorRow(
            icon: Icons.memory_rounded,
            label: 'Memory Usage',
            value: '${snapshot.memoryUsedPct?.toStringAsFixed(1) ?? '63.2'}%',
            color: AppTheme.accentBlue,
          ),
          const SizedBox(height: 12),
          const _StatusLine(label: 'Total', value: '32 GB'),
          const SizedBox(height: 6),
          const _StatusLine(label: 'Used', value: '20.2 GB'),
          const SizedBox(height: 6),
          const _StatusLine(label: 'Free', value: '11.8 GB'),
        ],
      ),
    );
  }
}

class _GaugePlaceholder extends StatelessWidget {
  const _GaugePlaceholder({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.height = 170,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unit,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.accentBlue.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? AppTheme.accentBlue.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
