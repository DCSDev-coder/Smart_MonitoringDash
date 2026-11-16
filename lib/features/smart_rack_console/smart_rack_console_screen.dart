import 'package:flutter/material.dart';

import '../../core/config/site_runtime_config.dart';
import '../../core/network/cpanel_api_service.dart';
import '../dashboard/widgets/device_health_section.dart';
import '../dashboard/widgets/door_control_section.dart';
import '../dashboard/widgets/environment_gauges.dart';
import '../dashboard/widgets/pue_history_dialog.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'models/smart_rack_device_profile.dart';
import 'services/rack_console_preferences.dart';
import 'services/smart_rack_console_repository.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/it_devices_dialog.dart';

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
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-02.png',
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-04.png',
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-03.png',
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-05.png',
  ];

  static const Map<String, String> _rackImageLabels = {
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-02.png':
        'Smart Rack',
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-04.png':
        'Smart Modular',
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-03.png':
        'Smart Modular R2',
    'assets/DCS_Logo/SMART-RACK-CONTAINMENT-NEW-LOGO-DCS-05.png':
        'Smart Modular R3',
  };

  late String _selectedRackImage;

  @override
  void initState() {
    super.initState();
    _selectedRackImage = RackConsolePreferences.instance.selectedRackImage;
    RackConsolePreferences.instance.addListener(_onPrefsChanged);
  }

  @override
  void dispose() {
    RackConsolePreferences.instance.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (!mounted) return;
    final current = RackConsolePreferences.instance.selectedRackImage;
    if (current != _selectedRackImage) {
      setState(() => _selectedRackImage = current);
    }
  }

  Future<void> _showRackImagePicker(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: ConsoleTheme.panelBg(context),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Smart Rack Model',
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
                      final label = _rackImageLabels[assetPath] ??
                          assetPath.split('/').last.replaceAll('.png', '');
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
                                child:
                                    Image.asset(assetPath, fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? ConsoleTheme.primaryBlue(context)
                                      : ConsoleTheme.textPrimary(context),
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
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
    await RackConsolePreferences.instance.setSelectedRackImage(selected);
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

    return Column(
      children: [
        Expanded(
          flex: 52,
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
        Expanded(
          flex: 48,
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
    final uptimeDays = (snapshot.systemUptimeDays != null && snapshot.systemUptimeDays! > 0)
        ? snapshot.systemUptimeDays!
        : 142;
    final maintDays = snapshot.maintenanceDaysLeft ?? 79;

    // Extract discrete doors for individual Front / Back display
    final List<Map<String, dynamic>> displayDoors;
    if (snapshot.doors.isNotEmpty) {
      if (snapshot.doors.length <= 2) {
        displayDoors = snapshot.doors;
      } else {
        Map<String, dynamic>? front;
        Map<String, dynamic>? back;
        for (final d in snapshot.doors) {
          final n = (d['accessName'] ?? d['name'] ?? '').toString().toLowerCase();
          if (front == null && (n.contains('front') || n.contains('1'))) {
            front = d;
          } else if (back == null && (n.contains('back') || n.contains('rear') || n.contains('2'))) {
            back = d;
          }
        }
        displayDoors = [
          front ?? snapshot.doors[0],
          back ?? (snapshot.doors.length > 1 ? snapshot.doors[1] : snapshot.doors[0]),
        ];
      }
    } else {
      displayDoors = const [
        {'id': 1, 'name': 'Front 1', 'isOpen': false},
        {'id': 2, 'name': 'Back 1', 'isOpen': false},
      ];
    }

    int parseDoorId(dynamic raw, int fallback) {
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    return ConsoleSectionCard(
      title: 'Rack Overview',
      minHeight: 170,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      trailing: _buildHeaderActionPill(
        context: context,
        icon: Icons.dns_rounded,
        label: 'IT Devices',
        tooltip: 'View IT Devices & Live Telemetry',
        onTap: () => showItDevicesDialog(context, snapshot: snapshot),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 260.0;
          final rackImageHeight = (cardHeight * 0.70).clamp(110.0, 320.0);
          final double statValueFontSize = (cardHeight * 0.12).clamp(20.0, 36.0);
          final double labelFontSize = (cardHeight * 0.045).clamp(10.0, 14.0);

          return Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: isSuperWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left Column: Tall, handsome Rack Image with docked Edit Pen Icon
                              Expanded(
                                flex: 42,
                                child: Center(
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2, right: 2),
                                        child: Image.asset(
                                          rackImageAssetPath,
                                          height: (cardHeight * 0.76).clamp(130.0, 260.0),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 4,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: onChangeRackImage,
                                            borderRadius: BorderRadius.circular(14),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: ConsoleTheme.primaryBlue(context),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.25),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1.5),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Right Column: Stats (Top) and Square Door Cards (Bottom) in harmonious 2x2 grid
                              Expanded(
                                flex: 58,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Continuous Run & Maintenance side by side
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _VerticalStatItem(
                                            label: 'Continuous Run',
                                            value: '$uptimeDays',
                                            subValue: 'Days Uptime',
                                            valueColor: ConsoleTheme.cyan(context),
                                            valueFontSize: (statValueFontSize * 0.90).clamp(18.0, 32.0),
                                            labelFontSize: labelFontSize,
                                            spacing: 3,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _VerticalStatItem(
                                            label: 'Maintenance',
                                            value: '$maintDays',
                                            subValue: 'Days Left',
                                            valueColor: ConsoleTheme.primaryBlue(context),
                                            valueFontSize: (statValueFontSize * 0.90).clamp(18.0, 32.0),
                                            labelFontSize: labelFontSize,
                                            spacing: 3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Row 2: Front & Back Door square cards side by side
                                    Row(
                                      children: [
                                        ...displayDoors.asMap().entries.map((entry) {
                                          final i = entry.key;
                                          final door = entry.value;
                                          final rawId = door['id'] ?? door['accessId'] ?? door['access_id'];
                                          final doorId = parseDoorId(rawId, i + 1);
                                          final rawName = (door['accessName'] ?? door['name'] ?? '').toString();
                                          final shortName = _formatDoorShortName(rawName, i);
                                          final isOpen = door['isOpen'] == true;
                                          return Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: i > 0 ? 4 : 0,
                                                right: i < displayDoors.length - 1 ? 4 : 0,
                                              ),
                                              child: _buildSquareDoorCard(
                                                context: context,
                                                shortName: shortName,
                                                rawName: rawName.isNotEmpty ? rawName : shortName,
                                                doorId: doorId,
                                                isOpen: isOpen,
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
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
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2, right: 2),
                                      child: Image.asset(
                                        rackImageAssetPath,
                                        height: (rackImageHeight * 0.65).clamp(100.0, 180.0),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: onChangeRackImage,
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: ConsoleTheme.primaryBlue(context),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1.5),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _VerticalStatItem(
                                      label: 'Continuous Run',
                                      value: '$uptimeDays',
                                      subValue: 'Days Uptime',
                                      valueColor: ConsoleTheme.cyan(context),
                                      centered: true,
                                      valueFontSize: statValueFontSize * 0.85,
                                      labelFontSize: labelFontSize,
                                      spacing: 3,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 32,
                                      color: ConsoleTheme.textSecondary(context).withValues(alpha: 0.2),
                                    ),
                                    _VerticalStatItem(
                                      label: 'Maintenance',
                                      value: '$maintDays',
                                      subValue: 'Days Left',
                                      valueColor: ConsoleTheme.primaryBlue(context),
                                      centered: true,
                                      valueFontSize: statValueFontSize * 0.85,
                                      labelFontSize: labelFontSize,
                                      spacing: 3,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 280),
                                  child: Row(
                                    children: [
                                      ...displayDoors.asMap().entries.map((entry) {
                                        final i = entry.key;
                                        final door = entry.value;
                                        final rawId = door['id'] ?? door['accessId'] ?? door['access_id'];
                                        final doorId = parseDoorId(rawId, i + 1);
                                        final rawName = (door['accessName'] ?? door['name'] ?? '').toString();
                                        final shortName = _formatDoorShortName(rawName, i);
                                        final isOpen = door['isOpen'] == true;
                                        return Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: i > 0 ? 4 : 0,
                                              right: i < displayDoors.length - 1 ? 4 : 0,
                                            ),
                                            child: _buildSquareDoorCard(
                                              context: context,
                                              shortName: shortName,
                                              rawName: rawName.isNotEmpty ? rawName : shortName,
                                              doorId: doorId,
                                              isOpen: isOpen,
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                );
        },
      ),
    );
  }

  String _formatDoorShortName(String rawName, int fallbackIndex) {
    final lower = rawName.toLowerCase();
    if (lower.contains('front')) {
      final idx = lower.indexOf('front');
      final after = rawName.substring(idx + 5);
      final match = RegExp(r'\d+').firstMatch(after);
      return match != null ? 'Front ${match.group(0)}' : 'Front';
    }
    if (lower.contains('rear') || lower.contains('back')) {
      int idx = lower.indexOf('back');
      int len = 4;
      if (idx == -1) {
        idx = lower.indexOf('rear');
        len = 4;
      }
      final after = rawName.substring(idx + len);
      final match = RegExp(r'\d+').firstMatch(after);
      return match != null ? 'Back ${match.group(0)}' : 'Back';
    }
    if (rawName.trim().isNotEmpty) {
      return rawName.trim();
    }
    return fallbackIndex == 0 ? 'Front 1' : 'Back 1';
  }

  Future<void> _openUnlockDoorSheet(
    BuildContext context,
    int doorId,
    String doorName,
  ) async {
    final siteId = SiteRuntimeConfig.siteId(CpanelApiService.instance.currentSite);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => UnlockDoorSheet(
        doorId: doorId,
        doorName: doorName,
        isRackConsoleStyle: true,
        siteId: siteId,
      ),
    );
  }

  Widget _buildSquareDoorCard({
    required BuildContext context,
    required String shortName,
    required String rawName,
    required int doorId,
    required bool isOpen,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final statusColor = isOpen ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final icon = isOpen ? Icons.sensor_door_outlined : Icons.lock_outline_rounded;
    final statusLabel = isOpen ? 'OPEN' : 'LOCKED';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUnlockDoorSheet(context, doorId, rawName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isLight
                ? (isOpen ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC))
                : (isOpen ? const Color(0xFFF59E0B).withValues(alpha: 0.10) : ConsoleTheme.panelBg(context)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                  : (isLight ? Colors.black.withValues(alpha: 0.08) : ConsoleTheme.cardBorder(context)),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.15),
                blurRadius: 6,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : (isLight ? Colors.white : Colors.white.withValues(alpha: 0.08)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOpen
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                        : (isLight ? Colors.black.withValues(alpha: 0.06) : Colors.transparent),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isOpen
                      ? const Color(0xFFF59E0B)
                      : (isLight ? const Color(0xFF334155) : ConsoleTheme.textPrimary(context)),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                shortName,
                style: TextStyle(
                  color: ConsoleTheme.textPrimary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                decoration: BoxDecoration(
                  color: ConsoleTheme.primaryBlue(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.22),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'UNLOCK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
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
      minHeight: 170,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 260.0;
          // Subtract a safe fixed offset for the pager and spacing to avoid vertical overflows
          final double calculatedGaugeHeight = (cardHeight - 84).clamp(110.0, 360.0);

          return Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: EnvironmentRow(
              temperatures: snapshot.temperatures,
              humidities: snapshot.humidities,
              alarms: snapshot.alarms,
              initialStyle: EnvironmentGaugeStyle.meter,
              minimalist: true,
              isVertical: !isSuperWide,
              gaugeHeight: calculatedGaugeHeight,
            ),
          );
        },
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

  Widget _buildHeaderActionPill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ConsoleTheme.primaryBlue(context),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPuePanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final pueValue = snapshot.pue;
    final pueColor = _getPueColor(pueValue ?? 0);

    return ConsoleSectionCard(
      title: 'Current PUE',
      minHeight: 190,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      trailing: _buildHeaderActionPill(
        context: context,
        icon: Icons.history_rounded,
        label: 'History',
        tooltip: 'View PUE History & Past Trends',
        onTap: () => showPueHistoryDialog(context, currentPue: pueValue),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 260.0;
          final double chartSize = (cardHeight - 118).clamp(65.0, 300.0);
          final double valueFontSize = (chartSize * 0.20).clamp(18.0, 52.0);
          final double labelFontSize = (chartSize * 0.08).clamp(9.0, 16.0);
          final double strokeWidth = (chartSize * 0.09).clamp(7.0, 20.0);
          final double titleFontSize = (cardHeight * 0.042).clamp(10.0, 15.0);
          final double energyValFontSize = (cardHeight * 0.080).clamp(16.0, 34.0);

          return SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => showPueHistoryDialog(context, currentPue: pueValue),
                  child: Tooltip(
                    message: 'Click to view PUE History',
                    child: SizedBox(
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
                            baseColor: ConsoleTheme.isDark(context)
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFC0D3EB),
                            strokeWidth: strokeWidth,
                            sweepDegrees: 255,
                            startDegrees: 145,
                            glowIntensity: 0.0,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                pueValue?.toStringAsFixed(2) ?? '--',
                                style: TextStyle(
                                  fontSize: valueFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: ConsoleTheme.textPrimary(context),
                                ),
                              ),
                              Text(
                                'PUE',
                                style: TextStyle(
                                  fontSize: labelFontSize,
                                  color: pueColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Total Energy Consumption Of The Month',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ConsoleTheme.textPrimary(context),
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      snapshot.totalMonthEnergyKwh?.toStringAsFixed(2) ?? '--',
                      style: TextStyle(
                        color: ConsoleTheme.cyan(context),
                        fontSize: energyValFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: EdgeInsets.only(bottom: energyValFontSize * 0.15),
                      child: Text(
                        'kW·h',
                        style: TextStyle(
                          color: ConsoleTheme.textPrimary(context),
                          fontSize: energyValFontSize * 0.38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _buildMonitoringStatisticsPanel(BuildContext context, SmartRackConsoleSnapshot snapshot, {bool twoColumn = false}) {
    return ConsoleSectionCard(
      title: 'Monitoring Statistics',
      minHeight: 150,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
    );
  }

  Widget _buildCapacityPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return ConsoleSectionCard(
      title: 'Space Capacity',
      minHeight: 140,
      expand: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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

    final List<Widget> scrollableItems = [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SensorRow(
            icon: Icons.storage_rounded,
            label: 'Overall Capacity',
            value: '${(snapshot.capacityUsedPct ?? 0.0).toStringAsFixed(1)}%',
            color: ConsoleTheme.purple(context),
          ),
          const SizedBox(height: 6),
          _buildCapacityProgressBar(
            context,
            snapshot.capacityUsedPct ?? 0.0,
            color: ConsoleTheme.purple(context),
          ),
        ],
      ),
      if (breakdown.isNotEmpty) ...[
        const SizedBox(height: 12),
        Divider(
          color: ConsoleTheme.cardBorder(context).withValues(alpha: 0.3),
          height: 1,
        ),
        const SizedBox(height: 10),
      ],
      for (var i = 0; i < breakdown.length; i++) ...[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SensorRow(
              icon: Icons.dns_rounded,
              label: breakdown[i].label,
              value: '${breakdown[i].percentage.toStringAsFixed(0)}%',
              color: ConsoleTheme.primaryBlue(context),
            ),
            const SizedBox(height: 6),
            _buildCapacityProgressBar(
              context,
              breakdown[i].percentage,
            ),
          ],
        ),
        if (i < breakdown.length - 1) const SizedBox(height: 10),
      ],
      if (breakdown.isEmpty) ...[
        const SizedBox(height: 32),
        Center(
          child: Text(
            'No capacity breakdown available.',
            style: TextStyle(
              color: ConsoleTheme.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ),
      ]
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isBounded = constraints.hasBoundedHeight;
          final list = ListView(
            shrinkWrap: !isBounded,
            physics: !isBounded ? const NeverScrollableScrollPhysics() : null,
            padding: EdgeInsets.zero,
            children: scrollableItems,
          );
          if (!isBounded) {
            return list;
          }
          return Scrollbar(child: list);
        },
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
    this.valueFontSize = 42.0,
    this.labelFontSize = 13.0,
    this.spacing = 6.0,
  });

  final String label;
  final String value;
  final String subValue;
  final Color valueColor;
  final bool centered;
  final double valueFontSize;
  final double labelFontSize;
  final double spacing;

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
              fontSize: labelFontSize,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: spacing),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: valueFontSize,
              height: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: spacing * 0.5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            subValue,
            style: TextStyle(
              color: ConsoleTheme.textSecondary(context),
              fontSize: labelFontSize * 0.9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

