import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/smart_rack_console_snapshot.dart';
import '../theme/console_theme.dart';

Future<void> showItDevicesDialog(
  BuildContext context, {
  required SmartRackConsoleSnapshot snapshot,
}) async {
  final isWide = MediaQuery.of(context).size.width >= 700;

  if (isWide) {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'IT Devices & Telemetry',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 680,
            maxHeight: 680,
          ),
          child: _ItDevicesDialogView(
            snapshot: snapshot,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 12 * anim1.value,
            sigmaY: 12 * anim1.value,
          ),
          child: Transform.scale(
            scale: 0.90 + (0.10 * curve.value),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        );
      },
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: ConsoleTheme.panelBg(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _ItDevicesDialogView(
          snapshot: snapshot,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}

class _ItDevicesDialogView extends StatelessWidget {
  const _ItDevicesDialogView({
    required this.snapshot,
    required this.onClose,
  });

  final SmartRackConsoleSnapshot snapshot;
  final VoidCallback onClose;

  String _formatSpeed(dynamic rawBytes) {
    final bytes = double.tryParse(rawBytes?.toString() ?? '0') ?? 0.0;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytes.toStringAsFixed(0)} B/s';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final panelBg = ConsoleTheme.panelBg(context);
    final innerBg = ConsoleTheme.innerSurface(context);
    final borderColor = ConsoleTheme.cardBorder(context);
    final textPrimary = ConsoleTheme.textPrimary(context);
    final textSecondary = ConsoleTheme.textSecondary(context);
    final cyan = ConsoleTheme.cyan(context);
    final primaryBlue = ConsoleTheme.primaryBlue(context);

    final metrics = [
      (
        icon: Icons.bolt_rounded,
        label: 'Active IT Load',
        value: snapshot.itPowerKw != null
            ? '${snapshot.itPowerKw!.toStringAsFixed(1)} kW'
            : '--',
        color: cyan,
      ),
      (
        icon: Icons.memory_rounded,
        label: 'CPU Utilization',
        value: snapshot.cpuUsedPct != null
            ? '${snapshot.cpuUsedPct!.toStringAsFixed(1)}%'
            : '--',
        color: const Color(0xFF10B981),
      ),
      (
        icon: Icons.sd_storage_rounded,
        label: 'Memory (RAM)',
        value: snapshot.memoryUsedPct != null
            ? '${snapshot.memoryUsedPct!.toStringAsFixed(1)}%'
            : '--',
        color: const Color(0xFF8B5CF6),
      ),
      (
        icon: Icons.storage_rounded,
        label: 'Storage Used',
        value: snapshot.diskUsedPct != null
            ? '${snapshot.diskUsedPct!.toStringAsFixed(1)}%'
            : '--',
        color: const Color(0xFFF59E0B),
      ),
      (
        icon: Icons.speed_rounded,
        label: 'Network Latency',
        value: snapshot.responseTimeMs != null
            ? '${snapshot.responseTimeMs!.toStringAsFixed(0)} ms'
            : '--',
        color: primaryBlue,
      ),
      (
        icon: Icons.wifi_tethering_rounded,
        label: 'Packet Loss',
        value: snapshot.packetLossPct != null
            ? '${snapshot.packetLossPct!.toStringAsFixed(1)}%'
            : '--',
        color: const Color(0xFF06B6D4),
      ),
    ];

    final interfaces = snapshot.networkInterfaces;
    final devices = snapshot.devices;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.14 : 0.45),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryBlue.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(Icons.dns_rounded, color: cyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IT Devices & Telemetry',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${snapshot.siteName} • Live Hardware & Network',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: snapshot.healthColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: snapshot.healthColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: snapshot.healthColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        snapshot.healthLabel,
                        style: TextStyle(
                          color: snapshot.healthColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: textSecondary, size: 20),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 6-metric telemetry grid
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 460 ? 3 : 2;
                const spacing = 10.0;
                final itemWidth = (constraints.maxWidth - (spacing * (cols - 1))) / cols;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: metrics.map((m) {
                    return Container(
                      width: itemWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: innerBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: m.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(m.icon, size: 16, color: m.color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.value,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Network Interfaces & Monitored Devices',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${interfaces.length} Interfaces • ${devices.length} Devices',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Scrollable list of real interfaces / devices
            Expanded(
              child: (interfaces.isEmpty && devices.isEmpty)
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: innerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        'No individual IT devices or network interfaces reported.',
                        style: TextStyle(color: textSecondary, fontSize: 12.5),
                      ),
                    )
                  : ListView(
                      children: [
                        ...interfaces.map((iface) {
                          final name = iface['name']?.toString() ?? 'Interface';
                          final isUp = iface['interface_status']?.toString() == '1.0' ||
                              iface['interface_status']?.toString() == '1';
                          final ip = (iface['ip'] ??
                                  iface['interface_ip'] ??
                                  iface['ipv4'] ??
                                  '')
                              .toString()
                              .trim();
                          final inSpeed = _formatSpeed(iface['interface_in_octets_speed']);
                          final outSpeed = _formatSpeed(iface['interface_out_octets_speed']);
                          final statusColor =
                              isUp ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: innerBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.settings_ethernet_rounded,
                                  size: 18,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ip.isNotEmpty ? '$name ($ip)' : name,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'RX: $inSpeed  •  TX: $outSpeed',
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isUp ? 'ONLINE' : 'DOWN',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        ...devices.whereType<Map>().map((dev) {
                          final name = (dev['deviceName'] ??
                                  dev['name'] ??
                                  dev['device_name'] ??
                                  'Device')
                              .toString();
                          final type = (dev['deviceType'] ??
                                  dev['type'] ??
                                  dev['device_type'] ??
                                  'Hardware')
                              .toString();
                          final rawStatus = (dev['status'] ?? dev['state'] ?? '').toString();
                          final isNormal = rawStatus.isEmpty ||
                              rawStatus == '1' ||
                              rawStatus.toLowerCase() == 'normal' ||
                              rawStatus.toLowerCase() == 'online';
                          final statusColor = isNormal
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: innerBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.developer_board_rounded, size: 18, color: cyan),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        type,
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isNormal ? 'NORMAL' : rawStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
            const SizedBox(height: 14),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
