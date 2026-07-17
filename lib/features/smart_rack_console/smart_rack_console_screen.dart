import 'package:flutter/material.dart';

import '../dashboard/widgets/device_health_section.dart';
import '../dashboard/widgets/environment_gauges.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'models/smart_rack_device_profile.dart';
import 'services/smart_rack_console_repository.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';

class SmartRackConsoleScreen extends StatefulWidget {
  const SmartRackConsoleScreen({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final SmartRackDeviceProfile profile;
  final bool compact;

  @override
  State<SmartRackConsoleScreen> createState() => _SmartRackConsoleScreenState();
}

class _SmartRackConsoleScreenState extends State<SmartRackConsoleScreen> {
  static const List<String> _rackImageOptions = [
    'assets/images/SMART RACK CONTAINMENT NEW LOGO DCS-02.png',
    'assets/images/SMART RACK CONTAINMENT NEW LOGO DCS-03.png',
    'assets/images/SMART RACK CONTAINMENT NEW LOGO DCS-04.png',
    'assets/images/SMART RACK CONTAINMENT NEW LOGO DCS-05.png',
  ];

  String _selectedRackImage = 'assets/images/smart_rack_containment_logo.png';

  Future<void> _showRackImagePicker(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: ConsoleTheme.panelBg(context),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Smart Rack Image',
                    style: TextStyle(
                      color: ConsoleTheme.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: _rackImageOptions.map((assetPath) {
                      final isSelected = assetPath == _selectedRackImage;
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(assetPath),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ConsoleTheme.innerSurface(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? ConsoleTheme.primaryBlue(context)
                                  : ConsoleTheme.cardBorder(context),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 132,
                                child: Image.asset(assetPath, fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                assetPath.split('/').last.replaceAll('.png', ''),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? ConsoleTheme.textPrimary(context)
                                      : ConsoleTheme.textSecondary(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == _selectedRackImage) return;
    setState(() {
      _selectedRackImage = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SmartRackConsoleRepository.instance,
      builder: (context, _) {
        final snapshot =
            SmartRackConsoleRepository.instance.currentSnapshot();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = widget.compact || constraints.maxWidth < 400;

            return Container(
              decoration: BoxDecoration(
                gradient: ConsoleTheme.pageBgGradient(context),
              ),
              child: isNarrow
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(ConsoleTheme.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MainGrid(
                            snapshot: snapshot,
                            compact: widget.compact,
                            rackImageAssetPath: _selectedRackImage,
                            onChangeRackImage: () => _showRackImagePicker(context),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: SizedBox(
                        height: constraints.maxHeight - 12,
                        child: _MainGrid(
                          snapshot: snapshot,
                          compact: widget.compact,
                          viewportHeight: constraints.maxHeight - 12,
                          rackImageAssetPath: _selectedRackImage,
                          onChangeRackImage: () => _showRackImagePicker(context),
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

class _MainGrid extends StatelessWidget {
  const _MainGrid({
    required this.snapshot,
    required this.compact,
    required this.rackImageAssetPath,
    required this.onChangeRackImage,
    this.viewportHeight,
  });

  final SmartRackConsoleSnapshot snapshot;
  final bool compact;
  final double? viewportHeight;
  final String rackImageAssetPath;
  final VoidCallback onChangeRackImage;

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
          const SizedBox(height: ConsoleTheme.md),
          middle,
          const SizedBox(height: ConsoleTheme.md),
          right,
          const SizedBox(height: ConsoleTheme.md),
          _buildMonitoringStatisticsPanel(context, snapshot, twoColumn: false),
          const SizedBox(height: ConsoleTheme.md),
          _buildCapacityPanel(context, snapshot),
        ],
      );
    }

    const rowGap = ConsoleTheme.sm;
    const columnGap = ConsoleTheme.sm;
    final usableHeight = (viewportHeight ?? 620).clamp(520.0, 1200.0);
    final topRowHeight = (usableHeight * 0.56).clamp(272.0, 320.0);
    final bottomRowHeight = usableHeight - topRowHeight - rowGap;

    return Column(
      children: [
        SizedBox(
          height: topRowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: columnGap),
              Expanded(child: middle),
              const SizedBox(width: columnGap),
              Expanded(child: right),
            ],
          ),
        ),
        const SizedBox(height: rowGap),
        SizedBox(
          height: bottomRowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _buildMonitoringStatisticsPanel(context, snapshot, twoColumn: true),
              ),
              const SizedBox(width: columnGap),
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
      minHeight: 170,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: isSuperWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  rackImageAssetPath,
                                  height: 168,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              rackImageAssetPath,
                              height: 160,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 8),
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
            ),
          ),
          Positioned(
            right: 4,
            bottom: 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onChangeRackImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: ConsoleTheme.primaryBlue(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final isSuperWide = MediaQuery.of(context).size.width >= 1100;

    return ConsoleSectionCard(
      title: 'Temperature & Humidity',
      minHeight: 170,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: EnvironmentRow(
          temperatures: snapshot.temperatures,
          humidities: snapshot.humidities,
          alarms: snapshot.alarms,
          initialStyle: EnvironmentGaugeStyle.meter,
          minimalist: true,
          isVertical: !isSuperWide,
          gaugeHeight: isSuperWide ? 150 : 200,
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
    final chartSize = isWide ? 150.0 : 132.0;
    final pueValue = snapshot.pue;
    final pueColor = _getPueColor(pueValue ?? 0);

    return ConsoleSectionCard(
      title: 'Current PUE',
      minHeight: 190,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
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
                  progress: pueValue == null
                      ? 0
                      : ((pueValue - 1.0) / (3.0 - 1.0)).clamp(0.0, 1.0),
                  glowColor: pueColor,
                  baseColor: ConsoleTheme.isDark(context) ? const Color(0xFF3A3A3A) : const Color(0xFFC0D3EB),
                  strokeWidth: isWide ? 14.0 : 12.0,
                  sweepDegrees: 255,
                  startDegrees: 145,
                  glowIntensity: 1.0,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      pueValue?.toStringAsFixed(2) ?? '--',
                      style: TextStyle(
                        fontSize: isWide ? 30 : 24,
                        fontWeight: FontWeight.bold,
                        color: ConsoleTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      'PUE',
                      style: TextStyle(
                        fontSize: isWide ? 13 : 11,
                        color: pueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total Energy Consumption Of The Month',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ConsoleTheme.textPrimary(context),
              fontSize: isWide ? 12 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                snapshot.totalMonthEnergyKwh?.toStringAsFixed(2) ?? '--',
                style: TextStyle(
                  color: ConsoleTheme.cyan(context),
                  fontSize: isWide ? 26 : 22,
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
                    fontSize: isWide ? 10 : 9,
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
      minHeight: 150,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    return ConsoleSectionCard(
      title: '',
      minHeight: 140,
      expand: true,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: _CapacityItems(snapshot: snapshot),
    );
  }

}

class _CapacityItems extends StatelessWidget {
  const _CapacityItems({
    required this.snapshot,
  });

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final breakdown = snapshot.capacityBreakdown;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
             child: breakdown.isEmpty
                 ? Center(
                     child: Text(
                      'No capacity breakdown available.',
                      style: TextStyle(
                        color: ConsoleTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  )
                 : ListView.separated(
                     padding: EdgeInsets.zero,
                     itemCount: breakdown.length,
                     separatorBuilder: (_, __) => const SizedBox(height: 4),
                     itemBuilder: (context, index) {
                      final item = breakdown[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SensorRow(
                            icon: Icons.dns_rounded,
                            label: item.label,
                            value: '${item.percentage.toStringAsFixed(0)}%',
                            color: ConsoleTheme.primaryBlue(context),
                          ),
                          const SizedBox(height: 6),
                          _buildCapacityProgressBar(
                             context,
                             item.percentage,
                           ),
                         ],
                       );
                     },
                   ),
           ),
        ],
      ),
    );
  }
}

Widget _buildCapacityProgressBar(BuildContext context, double percentage, {Color? color}) {
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
                fontWeight: FontWeight.w700,
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

