import 'package:flutter/material.dart';

import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/console_section_card.dart';
import '../../shared/widgets/secure_action_guard.dart';
import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../shared/utils/app_toast.dart';
import '../../core/utils/app_log.dart';

class DoorConsoleScreen extends StatefulWidget {
  const DoorConsoleScreen({
    super.key,
    required this.snapshot,
  });

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<DoorConsoleScreen> createState() => _DoorConsoleScreenState();
}

class _DoorConsoleScreenState extends State<DoorConsoleScreen> {
  bool _isIpHidden = true;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLog.e('CAPTURED FLUTTER ERROR', error: details.exception, stackTrace: details.stack);
      if (oldHandler != null) {
        oldHandler(details);
      }
    };
  }

  Future<void> _handleUnlockDoor(int accessId, String name) async {
    final authorized = await SecureActionGuard.ensureAuthorized(
      context, 
      reason: 'Unlock $name'
    );
    
    if (authorized != true) return;
    if (!mounted) return;

    setState(() => _isActionInProgress = true);

    try {
      final site = CpanelApiService.instance.currentSite;
      final siteIdStr = site?['site_id']?.toString() ?? '';
      final siteId = int.tryParse(siteIdStr);

      Map<String, dynamic>? res;
      if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.openCloseDoor(
          siteId: siteId,
          accessId: accessId,
          status: 1,
        );
      } else {
        res = await ApiService.instance.openCloseDoor(accessId, 1);
      }

      if (!mounted) return;

      if (res != null && res['success'] == true) {
        AppToast.showSuccess(context, '$name unlocked successfully');
      } else {
        AppToast.showError(context, res?['message']?.toString() ?? 'Failed to unlock $name');
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error unlocking door: $e');
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Widget _buildInfoItem(String title, String value, {bool isHidden = false, VoidCallback? onToggleHide}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05);

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isHidden ? '*.*.*.*' : value,
                      style: TextStyle(
                        color: title == 'Status' ? ConsoleTheme.success(context) : (isLight ? AppTheme.lightTextPrimary : Colors.white),
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

  Widget _buildInfoGrid(BuildContext context) {
    return Column(
      children: [
        _buildInfoItem('Name', 'Access Controller'),
        const SizedBox(height: 8),
        _buildInfoItem('Device Type', 'Security'),
        const SizedBox(height: 8),
        _buildInfoItem('IP Addr.', '127.0.0.1', isHidden: _isIpHidden, onToggleHide: () async {
          if (_isIpHidden) {
            final ok = await SecureActionGuard.ensureAuthorized(context, reason: 'View IP Address');
            if (ok == true) {
              if (mounted) setState(() => _isIpHidden = false);
            }
          } else {
            if (mounted) setState(() => _isIpHidden = true);
          }
        }),
        const SizedBox(height: 8),
        _buildInfoItem('Status', widget.snapshot.doors.isNotEmpty ? 'Online' : 'Offline'),
        const SizedBox(height: 8),
        _buildInfoItem('Location', 'Default location'),
        const SizedBox(height: 8),
        _buildInfoItem('Cabinet', 'DCS-Cabinet Item 1'),
      ],
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final doors = widget.snapshot.doors;

    if (doors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No Doors Configured',
            style: TextStyle(
              color: isLight ? AppTheme.lightTextSecondary : Colors.white54,
            ),
          ),
        ),
      );
    }

    return Column(
      children: doors.map<Widget>((door) {
        final rawId = door['id'] ?? door['accessId'] ?? door['access_id'];
        final id = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
        final name = (door['accessName'] ?? door['name'] ?? 'Unknown Door').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isActionInProgress || id == null ? null : () => _handleUnlockDoor(id, name),
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ConsoleTheme.primaryBlue(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDoorStatusTable(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final doors = widget.snapshot.doors;
    
    if (doors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No Data',
            style: TextStyle(
              color: isLight ? AppTheme.lightTextSecondary : Colors.white54,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
        },
        children: doors.map<TableRow>((door) {
          final name = (door['accessName'] ?? door['name'] ?? 'Unknown').toString();
          final doorStatusRaw = door['doorStatus'] ?? door['door_status'];
          final lockStatusRaw = door['lockStatus'] ?? door['lock_status'];
          
          final doorStatus = doorStatusRaw is num ? doorStatusRaw.toInt() : int.tryParse(doorStatusRaw?.toString() ?? '0') ?? 0;
          final lockStatus = lockStatusRaw is num ? lockStatusRaw.toInt() : int.tryParse(lockStatusRaw?.toString() ?? '0') ?? 0;

          final isDoorOpen = doorStatus == 1; // 1: Open, 0: Closed
          final isLockOpen = lockStatus == 1; // 1: Unlocked, 0: Locked

          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Text(
                  name,
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDoorOpen ? Icons.door_front_door_rounded : Icons.door_front_door_outlined,
                      color: isDoorOpen ? ConsoleTheme.danger(context) : ConsoleTheme.success(context),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isDoorOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: isDoorOpen ? ConsoleTheme.danger(context) : ConsoleTheme.success(context),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLockOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: isLockOpen ? ConsoleTheme.warning(context) : ConsoleTheme.success(context),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isLockOpen ? 'Unlocked' : 'Locked',
                        style: TextStyle(
                          color: isLockOpen ? ConsoleTheme.warning(context) : ConsoleTheme.success(context),
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
        }).toList(),
      ),
    );
  }

  Widget _buildRecentLogsTable(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final logs = widget.snapshot.recentDoorLogs;
    
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No Logs',
            style: TextStyle(
              color: isLight ? AppTheme.lightTextSecondary : Colors.white54,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(1.5),
        },
        children: logs.take(5).map<TableRow>((log) {
          final timeRaw = log['opTime']?.toString() ?? '';
          final timeStr = timeRaw.length > 18 ? timeRaw.substring(5, 19) : timeRaw;
          
          final door = log['accessName']?.toString() ?? 'Door';
          final user = log['username']?.toString() ?? 'System';
          
          final openType = log['openType']?.toString() ?? '';
          String typeStr = 'Remote';
          if (openType == '1') typeStr = 'Password';
          if (openType == '2') typeStr = 'Fingerprint';
          if (openType == '3') typeStr = 'Card';

          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(timeStr, style: TextStyle(color: isLight ? AppTheme.lightTextPrimary : Colors.white, fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(door, style: TextStyle(color: isLight ? AppTheme.lightTextPrimary : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(user, style: TextStyle(color: isLight ? AppTheme.lightTextPrimary : Colors.white, fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(typeStr, textAlign: TextAlign.right, style: TextStyle(color: isLight ? AppTheme.lightTextSecondary : Colors.white70, fontSize: 12)),
              ),
            ],
          );
        }).toList(),
      ),
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
                    title: 'Device Info',
                    expand: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildInfoGrid(context),
                    ),
                  ),
                  const SizedBox(height: ConsoleTheme.lg),
                  ConsoleSectionCard(
                    title: 'Door Controls',
                    expand: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildControlPanel(context),
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
                    title: 'Live Door Status',
                    expand: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildDoorStatusTable(context),
                    ),
                  ),
                  const SizedBox(height: ConsoleTheme.lg),
                  ConsoleSectionCard(
                    title: 'Recent Access Logs',
                    expand: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildRecentLogsTable(context),
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
