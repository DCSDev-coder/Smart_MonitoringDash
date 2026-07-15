import 'package:flutter/material.dart';

import '../../core/config/site_runtime_config.dart';
import '../../core/network/cpanel_api_service.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/console_section_card.dart';
import '../../shared/widgets/secure_action_guard.dart';

class ItDeviceConsoleScreen extends StatefulWidget {
  const ItDeviceConsoleScreen({
    super.key,
    required this.snapshot,
  });

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<ItDeviceConsoleScreen> createState() => _ItDeviceConsoleScreenState();
}

class _ItDeviceConsoleScreenState extends State<ItDeviceConsoleScreen> {
  bool _isIpHidden = true;

  Map<String, dynamic>? get _site => CpanelApiService.instance.currentSite;

  String _firstNonEmpty(List<String?> values, {String fallback = '--'}) {
    for (final value in values) {
      final next = value?.trim();
      if (next != null && next.isNotEmpty) return next;
    }
    return fallback;
  }

  String? _siteValue(List<String> keys) {
    final site = _site;
    if (site == null) return null;
    for (final key in keys) {
      final value = site[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _deviceName() {
    return _firstNonEmpty([
      _siteValue(const ['device_name', 'deviceName']),
      'Monitor',
    ]);
  }

  String _deviceType() {
    return _firstNonEmpty([
      _siteValue(const ['device_type', 'deviceType']),
      'Monitor',
    ]);
  }

  String _ipAddress() {
    final firstInterface =
        widget.snapshot.networkInterfaces.isNotEmpty ? widget.snapshot.networkInterfaces.first : null;
    return _firstNonEmpty([
      firstInterface?['ip']?.toString(),
      firstInterface?['interface_ip']?.toString(),
      firstInterface?['ipv4']?.toString(),
      _siteValue(const ['open_ip', 'ip', 'ip_address']),
    ]);
  }

  String _deviceStatus() {
    final interfaces = widget.snapshot.networkInterfaces;
    final anyOnline = interfaces.any(
      (iface) =>
          iface['interface_status']?.toString() == '1' ||
          iface['interface_status']?.toString() == '1.0',
    );
    if (anyOnline || widget.snapshot.cpuUsedPct != null) return 'Normal';
    return '--';
  }

  String _locationLabel() {
    return _firstNonEmpty([
      _siteValue(const ['location_name', 'deviceLocationName', 'location']),
      'Default location',
    ]);
  }

  String _cabinetLabel() {
    final cabinetId = SiteRuntimeConfig.cabinetId(_site);
    final derivedCabinetLabel = cabinetId == null ? null : 'DCS-Cabinet Item $cabinetId';
    return _firstNonEmpty([
      _siteValue(const [
        'cabinet_item_name',
        'cabinetItemName',
        'deviceCabinetItemName',
        'cabinet_name',
        'cabinetName',
      ]),
      derivedCabinetLabel,
      cabinetId,
    ]);
  }

  int get _activeInterfaceCount => widget.snapshot.networkInterfaces
      .where(
        (iface) =>
            iface['interface_status']?.toString() == '1' ||
            iface['interface_status']?.toString() == '1.0',
      )
      .length;

  int get _totalInterfaceCount => widget.snapshot.networkInterfaces.length;

  String _formatResponseTime() {
    final value = widget.snapshot.responseTimeMs;
    if (value == null) return '--';
    if (value >= 100) return value.toStringAsFixed(0);
    if (value >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  String _formatPacketLoss() {
    final value = widget.snapshot.packetLossPct;
    if (value == null) return '--';
    if (value >= 10) return value.toStringAsFixed(0);
    if (value >= 1) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  Widget _buildInfoGrid(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05);

    Widget buildItem(String title, String value, {bool isHidden = false, VoidCallback? onToggleHide}) {
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
                child: Text(
                  title,
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isHidden ? '*.*.*.*' : value,
                        style: TextStyle(
                          color: title == 'Status' ? const Color(0xFF00C896) : (isLight ? AppTheme.lightTextPrimary : Colors.white),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (onToggleHide != null)
                      InkWell(
                        onTap: onToggleHide,
                        child: Icon(
                          isHidden ? Icons.visibility_off : Icons.visibility,
                          size: 16,
                          color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 450;
        
        if (isSmall) {
          return Column(
            children: [
              buildItem('Name', _deviceName()),
              const SizedBox(height: 8),
              buildItem('Device Type', _deviceType()),
              const SizedBox(height: 8),
              buildItem('IP Addr.', _ipAddress(), isHidden: _isIpHidden, onToggleHide: () async {
                if (_isIpHidden) {
                  final ok = await SecureActionGuard.ensureAuthorized(context, reason: 'View IP Address');
                  if (ok == true) {
                    setState(() => _isIpHidden = false);
                  }
                } else {
                  setState(() => _isIpHidden = true);
                }
              }),
              const SizedBox(height: 8),
              buildItem('Status', _deviceStatus()),
              const SizedBox(height: 8),
              buildItem('Location', _locationLabel()),
              const SizedBox(height: 8),
              buildItem('Cabinet', _cabinetLabel()),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: buildItem('Name', _deviceName())),
                const SizedBox(width: 8),
                Expanded(child: buildItem('Device Type', _deviceType())),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: buildItem('IP Addr.', _ipAddress(), isHidden: _isIpHidden, onToggleHide: () async {
                    if (_isIpHidden) {
                      final ok = await SecureActionGuard.ensureAuthorized(context, reason: 'View IP Address');
                      if (ok == true) {
                        setState(() => _isIpHidden = false);
                      }
                    } else {
                      setState(() => _isIpHidden = true);
                    }
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(child: buildItem('Status', _deviceStatus())),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildItem('Location', _locationLabel())),
                const SizedBox(width: 8),
                Expanded(child: buildItem('Cabinet', _cabinetLabel())),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGauge(BuildContext context, String title, double percentage, Color color) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 90,
          width: 90,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 8,
                color: color.withValues(alpha: 0.2),
              ),
              CircularProgressIndicator(
                value: percentage / 100,
                strokeWidth: 8,
                color: color,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '${percentage.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: isLight ? AppTheme.lightTextPrimary : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallMetric(BuildContext context, String title, String value) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1),
              width: 4,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: isLight ? AppTheme.lightTextPrimary : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildEthernetTable(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    TableRow buildHeader() {
      return TableRow(
        decoration: BoxDecoration(
          color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
        ),
        children: ['Name', 'Status', 'Inbound', 'Outbound'].map((title) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      );
    }

    TableRow buildRow(String name, bool status, String inbound, String outbound) {
      return TableRow(
        decoration: BoxDecoration(
          color: isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.02),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Icon(
              Icons.link,
              color: status ? const Color(0xFF00C896) : Colors.redAccent,
              size: 20,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_downward, color: Colors.redAccent, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    inbound,
                    style: TextStyle(
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_upward, color: Color(0xFF00C896), size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    outbound,
                    style: TextStyle(
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final interfaces = widget.snapshot.networkInterfaces;
    final rows = <TableRow>[buildHeader()];

    if (interfaces.isEmpty) {
      rows.add(buildRow('No Data', false, '-', '-'));
    } else {
      for (final iface in interfaces) {
        final name = iface['name']?.toString() ?? 'Unknown';
        final status = (iface['interface_status']?.toString() == '1.0' || iface['interface_status']?.toString() == '1');
        final inBytes = double.tryParse(iface['interface_in_octets_speed']?.toString() ?? '0') ?? 0.0;
        final outBytes = double.tryParse(iface['interface_out_octets_speed']?.toString() ?? '0') ?? 0.0;
        
        String formatSpeed(double bytes) {
          if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB/s';
          if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(2)}KB/s';
          return '${bytes.toStringAsFixed(2)}B/s';
        }
        
        rows.add(buildRow(name, status, formatSpeed(inBytes), formatSpeed(outBytes)));
      }
    }

    return Table(
      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2.5),
        3: FlexColumnWidth(2.5),
      },
      children: rows,
    );
  }

  Widget _buildDiskTable(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    TableRow buildHeader() {
      return TableRow(
        decoration: BoxDecoration(
          color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
        ),
        children: ['Partition Name', 'Total Capacity', 'Usage'].map((title) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      );
    }

    TableRow buildRow(String name, String capacity, String usage) {
      return TableRow(
        decoration: BoxDecoration(
          color: isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.02),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              capacity,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              usage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    final diskUsage = widget.snapshot.diskUsedPct;
    final rows = <TableRow>[buildHeader()];
    
    if (diskUsage != null) {
      rows.add(buildRow('/', '--', '${diskUsage.toStringAsFixed(2)}%'));
    } else {
      rows.add(buildRow('-', '-', '-'));
    }

    return Table(
      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ConsoleTheme.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [

                ConsoleSectionCard(
                  title: 'Metric Information',
                  expand: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 32,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildGauge(context, 'CPU Usage', widget.snapshot.cpuUsedPct ?? 0.0, const Color(0xFF3B82F6)),
                          _buildGauge(context, 'Memory Usage', widget.snapshot.memoryUsedPct ?? 0.0, const Color(0xFF8B5CF6)),
                          _buildGauge(context, 'Disk Usage', widget.snapshot.diskUsedPct ?? 0.0, const Color(0xFF00C896)),
                          _buildSmallMetric(context, 'Response Time', _formatResponseTime()),
                          _buildSmallMetric(context, 'Packet Loss', _formatPacketLoss()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: ConsoleTheme.lg),
          // Right Column
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              child: Column(
                children: [
                ConsoleSectionCard(
                  title: 'Device Info',
                  expand: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildInfoGrid(context),
                  ),
                ),
                const SizedBox(height: ConsoleTheme.lg),
                ConsoleSectionCard(
                  title: 'Ethernet Interface',
                  expand: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildEthernetTable(context),
                        if (_totalInterfaceCount > 0) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Active Ports: $_activeInterfaceCount / $_totalInterfaceCount',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.light
                                    ? AppTheme.lightTextSecondary
                                    : Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ConsoleTheme.lg),
                ConsoleSectionCard(
                  title: 'Disk',
                  expand: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildDiskTable(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}
